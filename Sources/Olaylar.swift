import Cocoa
import SwiftUI
import IOKit.ps
import CoreAudio

// MARK: - Ses çıkış cihazı (kulaklık bağlanınca)

func sesCihazi() -> (id: AudioDeviceID, ad: String, bluetooth: Bool)? {
    var adres = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal,
                                           mElement: kAudioObjectPropertyElementMain)
    var id = AudioDeviceID(0)
    var boyut = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &adres, 0, nil, &boyut, &id) == noErr,
          id != 0 else { return nil }

    var ad: Unmanaged<CFString>?
    boyut = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    adres.mSelector = kAudioObjectPropertyName
    _ = AudioObjectGetPropertyData(id, &adres, 0, nil, &boyut, &ad)

    var tur: UInt32 = 0
    boyut = UInt32(MemoryLayout<UInt32>.size)
    adres.mSelector = kAudioDevicePropertyTransportType
    _ = AudioObjectGetPropertyData(id, &adres, 0, nil, &boyut, &tur)

    let isim = (ad?.takeRetainedValue() as String?) ?? "Kulaklık"
    return (id, isim, tur == kAudioDeviceTransportTypeBluetooth || tur == kAudioDeviceTransportTypeBluetoothLE)
}

func kulaklikSimgesi(_ ad: String) -> String {
    let k = ad.lowercased()
    if k.contains("airpods max") { return "airpodsmax" }
    if k.contains("airpods pro") { return "airpodspro" }
    if k.contains("airpods") { return "airpods" }
    if k.contains("beats") { return "beats.headphones" }
    return "headphones"
}

// AirPods pil durumu: system_profiler çıktısından (birkaç saniye sürebilir)
func kulaklikPili(_ ad: String) -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    p.arguments = ["SPBluetoothDataType", "-json"]
    let cikis = Pipe()
    p.standardOutput = cikis
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    let veri = cikis.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard let kok = try? JSONSerialization.jsonObject(with: veri) as? [String: Any],
          let bt = (kok["SPBluetoothDataType"] as? [[String: Any]])?.first,
          let bagli = bt["device_connected"] as? [[String: Any]] else { return nil }
    for cihaz in bagli {
        for (isim, deger) in cihaz where isim == ad {
            guard let o = deger as? [String: Any] else { continue }
            var parcalar: [String] = []
            for (anahtar, etiket) in [("device_batteryLevelLeft", "Sol"), ("device_batteryLevelRight", "Sağ"),
                                      ("device_batteryLevelCase", "Kutu"), ("device_batteryLevelMain", "Pil")] {
                if let y = o[anahtar] as? String { parcalar.append("\(etiket) \(y.hasPrefix("%") ? y : "%" + y.replacingOccurrences(of: "%", with: ""))") }
            }
            return parcalar.isEmpty ? nil : parcalar.joined(separator: " · ")
        }
    }
    return nil
}

func pilSimgesi(_ oran: Double) -> String {
    switch oran {
    case ..<0.13: return "battery.0"
    case ..<0.38: return "battery.25"
    case ..<0.63: return "battery.50"
    case ..<0.88: return "battery.75"
    default: return "battery.100"
    }
}

// MARK: - Olay dinleyicileri

extension Uygulama {

    func olaylariBaslat() {
        fareIzle()
        sarjIzle()
        kulaklikIzle()
        Timer.scheduledTimer(timeInterval: 120, target: self, selector: #selector(depremKontrol), userInfo: nil, repeats: true)
        depremKontrol()
    }

    // Çentik bölgesi, ekran koordinatlarında
    func centikAlani(pay: CGFloat = 0) -> NSRect? {
        guard let e = hedefEkran() else { return nil }
        let g = (gorunum == .kompakt ? centikGenislik + 20 + 2 * 46 : centikGenislik) + 2 * pay
        return NSRect(x: e.frame.midX - g / 2, y: e.frame.maxY - centikYukseklik - pay, width: g, height: centikYukseklik + pay + 1)
    }

    // Açık panelin kapladığı alan
    func panelAlani() -> NSRect? {
        guard let e = hedefEkran() else { return nil }
        let g: CGFloat = 560 + 40
        let y = icerikYukseklik + 30
        return NSRect(x: e.frame.midX - g / 2, y: e.frame.maxY - y, width: g, height: y + 1)
    }

    // MARK: Fare: üzerine gelince aç, dosya sürükleyince rafı aç

    func fareIzle() {
        let maske: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        NSEvent.addGlobalMonitorForEvents(matching: maske) { e in
            MainActor.assumeIsolated { Ortak.uygulama.fareHareketi(surukleme: e.type == .leftMouseDragged) }
        }
        NSEvent.addLocalMonitorForEvents(matching: maske) { e in
            MainActor.assumeIsolated { Ortak.uygulama.fareHareketi(surukleme: e.type == .leftMouseDragged) }
            return e
        }
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { e in
            MainActor.assumeIsolated { Ortak.uygulama.kaydirma(e) }
        }
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { e in
            MainActor.assumeIsolated { Ortak.uygulama.kaydirma(e) }
            return e
        }
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            MainActor.assumeIsolated { Ortak.uygulama.dosyaSurukleniyor = false }
        }
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
            MainActor.assumeIsolated { Ortak.uygulama.centikTiklandi() }
        }
    }

    func fareHareketi(surukleme: Bool) {
        let p = NSEvent.mouseLocation
        if surukleme {
            let pb = NSPasteboard(name: .drag)
            if pb.changeCount != suruklemeSayaci {
                suruklemeSayaci = pb.changeCount
                dosyaSurukleniyor = pb.types?.contains(.fileURL) ?? false
            }
        }

        if gorunum != .panel {
            let centikte = centikAlani(pay: 6)?.contains(p) ?? false
            let istek = fareyleAc || (surukleme && dosyaSurukleniyor)
            guard centikte && istek else {
                girisIsi?.cancel()
                girisIsi = nil
                return
            }
            guard girisIsi == nil else { return }
            // Kısa bir bekleme: menü çubuğundan geçerken yanlışlıkla açılmasın
            let gorev = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.girisIsi = nil
                guard self.gorunum != .panel, self.centikAlani(pay: 6)?.contains(NSEvent.mouseLocation) ?? false else { return }
                if self.dosyaSurukleniyor { self.sekmeSec(10) }
                self.paneliAc(fareIle: true)
            }
            girisIsi = gorev
            DispatchQueue.main.asyncAfter(deadline: .now() + (dosyaSurukleniyor ? 0.05 : 0.2), execute: gorev)
        } else if fareIleAcildi {
            // Fareyle açıldıysa, fare panelden çıkınca kapan
            if panelAlani()?.contains(p) ?? true {
                cikisIsi?.cancel()
                cikisIsi = nil
            } else if cikisIsi == nil {
                let gorev = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.cikisIsi = nil
                    guard self.gorunum == .panel, self.fareIleAcildi, self.kaydedilen == nil,
                          !(self.panelAlani()?.contains(NSEvent.mouseLocation) ?? true) else { return }
                    self.paneliKapat()
                }
                cikisIsi = gorev
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: gorev)
            }
        }
    }

    func centikTiklandi() {
        guard gorunum == .kompakt, centikAlani(pay: 4)?.contains(NSEvent.mouseLocation) ?? false else { return }
        if !(kompaktAcik && bilgiler.calan?.caliyor == true) { sekmeSec(SekmeNo.zamanlayici) }
        paneliAc()
    }

    // MARK: Çentik üstünde kaydırınca ses

    func kaydirma(_ e: NSEvent) {
        guard kaydirmaSes, gorunum != .panel, centikAlani(pay: 6)?.contains(NSEvent.mouseLocation) ?? false else {
            kaydirmaBirikim = 0
            return
        }
        // Parmaklar / tekerlek yukarı = artır (doğal kaydırma ayarından bağımsız).
        // Shift basılıyken fare tekerleği yatay kaydırmaya döner, onu da say.
        let ham = abs(e.scrollingDeltaY) >= abs(e.scrollingDeltaX) ? e.scrollingDeltaY : e.scrollingDeltaX
        let yukari = e.isDirectionInvertedFromDevice ? -ham : ham
        kaydirmaBirikim += e.hasPreciseScrollingDeltas ? yukari : yukari * 10
        let esik: CGFloat = 12
        let parlaklik = e.modifierFlags.contains(.shift)
        while abs(kaydirmaBirikim) >= esik {
            let artir = kaydirmaBirikim > 0
            if parlaklik { parlaklikDegistir(artir ? 0.03 : -0.03) } else { sesDegistir(artir ? 2 : -2) }
            kaydirmaBirikim += artir ? -esik : esik
        }
    }

    // MARK: Şarj

    func sarjIzle() {
        sonPrizde = pilBilgisi()?.prizde
        let geri: IOPowerSourceCallbackType = { _ in
            MainActor.assumeIsolated { Ortak.uygulama.gucDegisti() }
        }
        if let kaynak = IOPSNotificationCreateRunLoopSource(geri, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), kaynak, .defaultMode)
        }
    }

    func gucDegisti() {
        guard let p = pilBilgisi() else { return }
        let onceki = sonPrizde
        sonPrizde = p.prizde
        guard sarjGoster else { return }
        let yuzde = Int((p.yuzde * 100).rounded())
        if let o = onceki, o != p.prizde {
            if p.prizde {
                hud(Bildirim(simge: "bolt.fill", yazi: "Şarj oluyor · %\(yuzde)", deger: p.yuzde, renk: VURGU), sure: 2.5)
            } else {
                hud(Bildirim(simge: pilSimgesi(p.yuzde), yazi: "Pil · %\(yuzde)", deger: p.yuzde,
                             renk: p.yuzde < 0.2 ? .orange : .white), sure: 2.5)
            }
        } else if !p.prizde, yuzde == 20 || yuzde == 10, sonPilUyari != yuzde {
            sonPilUyari = yuzde
            hud(Bildirim(simge: "battery.25", yazi: "Pil azaldı · %\(yuzde)", deger: p.yuzde, renk: .orange), sure: 4)
        }
    }

    // MARK: Kulaklık

    func kulaklikIzle() {
        sonCihaz = sesCihazi()?.id
        var adres = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                               mScope: kAudioObjectPropertyScopeGlobal,
                                               mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &adres, DispatchQueue.main) { _, _ in
            MainActor.assumeIsolated { Ortak.uygulama.cikisDegisti() }
        }
    }

    func cikisDegisti() {
        guard let c = sesCihazi() else { return }
        let onceki = sonCihaz
        sonCihaz = c.id
        guard kulaklikGoster, c.id != onceki, c.bluetooth else { return }
        hud(Bildirim(simge: kulaklikSimgesi(c.ad), yazi: c.ad, alt: "Bağlandı"), sure: 4.5)
        let ad = c.ad
        Task {
            let pil = await Task.detached { kulaklikPili(ad) }.value
            if let pil = pil, self.gorunum == .hud, self.bildirim.yazi == ad { self.bildirim.alt = pil }
        }
    }

    // MARK: Deprem uyarısı

    @objc func depremKontrol() {
        guard depremUyari, secili.contains("deprem") else { return }
        Task {
            guard await bilgiler.depremYukle() else { return }
            if let d = bilgiler.yeniBuyukDepremler(esik: depremUyariEsik).max(by: { $0.buyukluk < $1.buyukluk }) {
                hud(Bildirim(simge: "waveform.path.ecg", yazi: "Deprem · \(sayi(d.buyukluk, 1))",
                             alt: "\(d.yer) · \(onceYazi(d.tarih))", renk: .red), sure: 8)
            }
        }
    }
}
