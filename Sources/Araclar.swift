import Foundation
import AppKit
import IOKit.ps

struct PanoOgesi: Identifiable, Equatable {
    let id = UUID()
    let metin: String
    let tarih: Date
}

struct SistemDurumu {
    var islemci: Double = 0     // 0...1
    var bellek: Double = 0
    var bellekKullanilan: Double = 0   // GB
    var bellekToplam: Double = 0
    var disk: Double = 0
    var diskBos: Double = 0            // GB
    var pil: Double? = nil
    var sarjOluyor = false
    var acikKalma: TimeInterval = 0
}

struct PilBilgisi {
    let yuzde: Double
    let sarjOluyor: Bool
    let prizde: Bool
}

func pilBilgisi() -> PilBilgisi? {
    guard let bilgi = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let liste = IOPSCopyPowerSourcesList(bilgi)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
    for kaynak in liste {
        guard let d = IOPSGetPowerSourceDescription(bilgi, kaynak)?.takeUnretainedValue() as? [String: Any],
              let simdiki = d[kIOPSCurrentCapacityKey] as? Int, let en = d[kIOPSMaxCapacityKey] as? Int, en > 0,
              (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
        return PilBilgisi(yuzde: Double(simdiki) / Double(en),
                          sarjOluyor: d[kIOPSIsChargingKey] as? Bool ?? false,
                          prizde: (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue)
    }
    return nil
}

@MainActor
final class Araclar: ObservableObject {
    // Dosya rafı
    @Published var raf: [URL] = []
    // Pano geçmişi (sadece bellekte tutulur)
    @Published var pano: [PanoOgesi] = []
    @Published var panoAcik: Bool {
        didSet { ayar.set(panoAcik, forKey: "pano_acik"); if !panoAcik { pano = [] } }
    }
    // Zamanlayıcı
    @Published var bitis: Date? = nil          // çalışıyorsa bitiş anı
    @Published var duraklatilanKalan: Double? = nil
    @Published var toplam: Double = 25 * 60
    // Sistem
    @Published var sistem = SistemDurumu()
    // Hızlı not
    @Published var not: String {
        didSet { ayar.set(not, forKey: "not") }
    }
    // Uyutma engeli
    @Published var uyutmaKapali = false
    private let uyutmaEngeli = UyutmaEngeli()
    // Dünya saatleri (saat dilimi kimlikleri)
    @Published var saatler: [String] {
        didSet { ayar.set(saatler, forKey: "saatler") }
    }
    // Son ekran görüntüleri (Masaüstü izni istediği için ilk tarama düğmeyle)
    @Published var ekranGoruntuleri: [URL] = []
    @Published var ekranTarandi: Bool {
        didSet { ayar.set(ekranTarandi, forKey: "ekran_tarandi") }
    }

    var bittiginde: (() -> Void)?
    var panoKullaniliyor = true   // "Pano geçmişi" özelliği seçili mi
    let ayar = UserDefaults.standard
    private var sonPanoSayaci = NSPasteboard.general.changeCount
    private var oncekiIslemci: host_cpu_load_info?

    init() {
        panoAcik = ayar.object(forKey: "pano_acik") as? Bool ?? true
        not = ayar.string(forKey: "not") ?? ""
        ekranTarandi = ayar.bool(forKey: "ekran_tarandi")
        saatler = ayar.stringArray(forKey: "saatler")
            ?? ["Europe/Istanbul", "Europe/London", "America/New_York", "Asia/Tokyo"]
        raf = (ayar.stringArray(forKey: "raf") ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        Timer.scheduledTimer(timeInterval: 0.8, target: self, selector: #selector(panoKontrol), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(zamanKontrol), userInfo: nil, repeats: true)
    }

    // MARK: Uyutma

    func uyutmaDegistir() {
        uyutmaKapali = uyutmaEngeli.degistir()
    }

    // MARK: Dünya saatleri

    func saatEkle(_ kimlik: String) {
        guard !saatler.contains(kimlik) else { return }
        saatler.append(kimlik)
    }

    func saatSil(_ kimlik: String) {
        saatler.removeAll { $0 == kimlik }
    }

    // MARK: Ekran görüntüleri

    func ekranGoruntuleriniYenile() {
        guard ekranTarandi else { return }
        Task {
            ekranGoruntuleri = await Task.detached { sonEkranGoruntuleri() }.value
        }
    }

    func ekranIlkTarama() async {
        ekranGoruntuleri = await Task.detached { sonEkranGoruntuleri() }.value
        ekranTarandi = true
    }

    // MARK: Raf

    func rafaEkle(_ urller: [URL]) {
        for u in urller where !raf.contains(u) { raf.insert(u, at: 0) }
        rafiKaydet()
    }

    func raftanSil(_ u: URL) {
        raf.removeAll { $0 == u }
        rafiKaydet()
    }

    func rafiTemizle() {
        raf = []
        rafiKaydet()
    }

    private func rafiKaydet() { ayar.set(raf.map { $0.path }, forKey: "raf") }

    // MARK: Pano

    @objc func panoKontrol() {
        let pb = NSPasteboard.general
        guard pb.changeCount != sonPanoSayaci else { return }
        sonPanoSayaci = pb.changeCount
        guard panoAcik, panoKullaniliyor else { return }
        // Şifre yöneticilerinin gizli kopyalarını kaydetme
        let tipler = pb.types?.map { $0.rawValue } ?? []
        if tipler.contains("org.nspasteboard.ConcealedType") || tipler.contains("org.nspasteboard.TransientType") { return }
        guard let metin = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !metin.isEmpty else { return }
        pano.removeAll { $0.metin == metin }
        pano.insert(PanoOgesi(metin: metin, tarih: Date()), at: 0)
        if pano.count > 12 { pano.removeLast(pano.count - 12) }
    }

    func panoyaKopyala(_ o: PanoOgesi) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(o.metin, forType: .string)
        sonPanoSayaci = pb.changeCount
        pano.removeAll { $0.id == o.id }
        pano.insert(PanoOgesi(metin: o.metin, tarih: Date()), at: 0)
    }

    // MARK: Zamanlayıcı

    var calisiyor: Bool { bitis != nil }

    func kalan(_ an: Date = Date()) -> Double {
        if let b = bitis { return max(0, b.timeIntervalSince(an)) }
        return duraklatilanKalan ?? toplam
    }

    func sureSec(_ dakika: Double) {
        bitis = nil
        duraklatilanKalan = nil
        toplam = dakika * 60
    }

    func baslatDuraklat() {
        if let b = bitis {
            duraklatilanKalan = max(0, b.timeIntervalSinceNow)
            bitis = nil
        } else {
            bitis = Date().addingTimeInterval(duraklatilanKalan ?? toplam)
            duraklatilanKalan = nil
        }
    }

    func sifirla() {
        bitis = nil
        duraklatilanKalan = nil
    }

    @objc func zamanKontrol() {
        guard let b = bitis, b <= Date() else { return }
        bitis = nil
        duraklatilanKalan = nil
        NSSound(named: "Glass")?.play()
        bittiginde?()
    }

    // MARK: Sistem

    func sistemYenile() {
        var d = SistemDurumu()

        // İşlemci: iki ölçüm arasındaki fark
        var yuk = host_cpu_load_info()
        var sayi = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let sonuc = withUnsafeMutablePointer(to: &yuk) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(sayi)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &sayi)
            }
        }
        if sonuc == KERN_SUCCESS {
            if let o = oncekiIslemci {
                let kul = Double(yuk.cpu_ticks.0 &- o.cpu_ticks.0) + Double(yuk.cpu_ticks.1 &- o.cpu_ticks.1)
                    + Double(yuk.cpu_ticks.3 &- o.cpu_ticks.3)
                let bos = Double(yuk.cpu_ticks.2 &- o.cpu_ticks.2)
                d.islemci = kul + bos > 0 ? kul / (kul + bos) : 0
            } else {
                d.islemci = sistem.islemci
            }
            oncekiIslemci = yuk
        }

        // Bellek: aktif + sabit + sıkıştırılmış
        var vm = vm_statistics64()
        var vmSayi = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let vmSonuc = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmSayi)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmSayi)
            }
        }
        let toplamBellek = Double(ProcessInfo.processInfo.physicalMemory)
        if vmSonuc == KERN_SUCCESS {
            let sayfa = Double(vm_kernel_page_size)
            let kullanilan = (Double(vm.active_count) + Double(vm.wire_count) + Double(vm.compressor_page_count)) * sayfa
            d.bellek = min(1, kullanilan / toplamBellek)
            d.bellekKullanilan = kullanilan / 1_073_741_824
        }
        d.bellekToplam = toplamBellek / 1_073_741_824

        // Disk
        if let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey,
                                                                          .volumeAvailableCapacityForImportantUsageKey]),
           let toplamDisk = v.volumeTotalCapacity, let bos = v.volumeAvailableCapacityForImportantUsage, toplamDisk > 0 {
            d.disk = 1 - Double(bos) / Double(toplamDisk)
            d.diskBos = Double(bos) / 1_000_000_000
        }

        if let p = pilBilgisi() {
            d.pil = p.yuzde
            d.sarjOluyor = p.sarjOluyor
        }
        d.acikKalma = ProcessInfo.processInfo.systemUptime
        sistem = d
    }
}
