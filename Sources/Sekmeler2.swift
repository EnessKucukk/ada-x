import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Ortak

// Açma/kapama anahtarı (sistem anahtarından daha uyumlu görünür)
struct Anahtar: View {
    @Binding var acik: Bool

    var body: some View {
        Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { acik.toggle() } } label: {
            ZStack(alignment: acik ? .trailing : .leading) {
                Capsule().fill(acik ? VURGU : Color.white.opacity(0.14))
                Circle().fill(Color.white).padding(2.5).shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
            .frame(width: 38, height: 22)
        }
        .buttonStyle(.plain)
    }
}

struct AyarSatiri<Sag: View>: View {
    let simge: String
    let yazi: String
    var aciklama: String? = nil
    @ViewBuilder let sag: Sag

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: simge)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(yazi).font(.yuvarlak(13))
                if let a = aciklama {
                    Text(a).font(.yuvarlak(11)).foregroundColor(.white.opacity(0.45))
                }
            }
            Spacer(minLength: 8)
            sag
        }
    }
}

// İzin isteyen sekmelerde: basınca panel kapanır, Mac'in izin penceresi açılır, sonra panel geri gelir
struct IzinKarti: View {
    let simge: String
    let baslik: String
    let aciklama: String
    let istek: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: simge)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VURGU)
                .frame(width: 34, height: 34)
                .background(Circle().fill(VURGU.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(.yuvarlak(13, .semibold))
                Text(aciklama).font(.yuvarlak(11)).foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            HapDugme(yazi: "İzin ver", vurgulu: true) { Ortak.uygulama.izinIcinKapat(istek) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VURGU.opacity(0.08)))
    }
}

struct SecimCipi: View {
    let yazi: String
    let secili: Bool
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            Text(yazi)
                .font(.yuvarlak(11, .semibold))
                .foregroundColor(secili ? .white : .white.opacity(0.5))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(secili ? 0.16 : 0.045)))
                .overlay(Capsule().stroke(Color.white.opacity(secili ? 0.1 : 0), lineWidth: 0.5))
                .contentShape(Capsule())
        }
        .buttonStyle(BasmaStili())
    }
}

// MARK: - Takvim

struct TakvimSekmesi: View {
    @ObservedObject var b: Bilgiler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "tr_TR"))),
                      systemImage: "calendar")
                    .font(.yuvarlak(13, .semibold))
                Spacer()
                HapDugme(yazi: "Takvim", simge: "arrow.up.forward.app") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
                }
                YenileDugmesi(b: b, sekme: SekmeNo.takvim)
            }

            if b.takvimIzniGerekli {
                IzinKarti(simge: "calendar", baslik: "Takvim izni", aciklama: "Bugünkü etkinlikleri göstermek için",
                          istek: { await b.takvimIzniIste() })
            } else if b.etkinlikler.isEmpty {
                if b.takvimHata == nil && !b.yukleniyor.contains(SekmeNo.takvim) {
                    Kart {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(VURGU)
                            Text("Bugün ve yarın için etkinlik yok").font(.yuvarlak(13))
                        }
                    }
                } else {
                    DurumYazisi(yukleniyor: b.yukleniyor.contains(SekmeNo.takvim), hata: b.takvimHata)
                }
            } else {
                if let ilk = b.etkinlikler.first(where: { !$0.tumGun }) { siradaki(ilk) }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(b.etkinlikler) { e in satir(e) }
                    }
                }
                .frame(maxHeight: 230)
            }
        }
    }

    func siradaki(_ e: Etkinlik) -> some View {
        TimelineView(.periodic(from: Date(), by: 30)) { baglam in
            let kalan = e.baslangic.timeIntervalSince(baglam.date)
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 2).fill(e.renk).frame(width: 4, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kalan <= 0 ? "ŞU AN" : "SIRADAKİ").font(.yuvarlak(10, .bold)).foregroundColor(e.renk)
                    Text(e.baslik).font(.yuvarlak(16, .semibold)).lineLimit(1)
                    if let y = e.yer { Text(y).font(.yuvarlak(11)).foregroundColor(.white.opacity(0.5)).lineLimit(1) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(kalan <= 0 ? "Devam ediyor" : kalanYazi(kalan).components(separatedBy: " ").prefix(2).joined(separator: " "))
                        .font(.yuvarlak(15, .semibold))
                    Text(saat(e.baslangic) + " – " + saat(e.bitis)).font(.yuvarlak(11)).foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(e.renk.opacity(0.14)))
        }
    }

    func satir(_ e: Etkinlik) -> some View {
        let yarin = !Calendar.current.isDateInToday(e.baslangic) && !e.tumGun
        return HStack(spacing: 10) {
            Circle().fill(e.renk).frame(width: 8, height: 8)
            Text(e.baslik).font(.yuvarlak(12, .semibold)).lineLimit(1)
            Spacer()
            Text(e.tumGun ? "Tüm gün" : (yarin ? "Yarın " : "") + saat(e.baslangic))
                .font(.yuvarlak(11, .semibold)).monospacedDigit()
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
    }
}

// MARK: - Namaz vakitleri

struct NamazSekmesi: View {
    @ObservedObject var b: Bilgiler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DuzenlenebilirEtiket(simge: "location.fill", yazi: b.sehir, ipucu: "Şehir yaz") { b.sehirDegistir($0) }
                Spacer()
                YenileDugmesi(b: b, sekme: SekmeNo.namaz)
            }

            if b.vakitler.isEmpty {
                DurumYazisi(yukleniyor: b.yukleniyor.contains(SekmeNo.namaz), hata: b.namazHata)
            } else {
                TimelineView(.periodic(from: Date(), by: 1)) { baglam in
                    let simdi = baglam.date
                    let siradaki = b.vakitler.first { $0.tarih > simdi }
                    let bugun = b.vakitler.filter { Calendar.current.isDate($0.tarih, inSameDayAs: simdi) }
                    VStack(spacing: 12) {
                        if let s = siradaki {
                            HStack {
                                Image(systemName: s.simge).font(.system(size: 26)).symbolRenderingMode(.multicolor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(s.ad) vaktine").font(.yuvarlak(12)).foregroundColor(.white.opacity(0.8))
                                    Text(kalanYazi(s.tarih.timeIntervalSince(simdi)))
                                        .font(.yuvarlak(26, .semibold)).monospacedDigit()
                                }
                                Spacer()
                                Text(saat(s.tarih)).font(.yuvarlak(22, .semibold)).monospacedDigit()
                            }
                            .padding(.horizontal, 18).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(
                                LinearGradient(colors: [Color(red: 0.1, green: 0.35, blue: 0.3), Color(red: 0.2, green: 0.55, blue: 0.45)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)))
                        }
                        HStack(spacing: 8) {
                            ForEach(bugun) { v in
                                let gecti = v.tarih <= simdi
                                let sonraki = v.id == siradaki?.id
                                VStack(spacing: 6) {
                                    Image(systemName: v.simge).font(.system(size: 14))
                                        .foregroundColor(sonraki ? VURGU : .white.opacity(gecti ? 0.3 : 0.7))
                                    Text(v.ad).font(.yuvarlak(11, .semibold)).foregroundColor(.white.opacity(gecti ? 0.35 : 0.7))
                                    Text(saat(v.tarih)).font(.yuvarlak(13, .semibold)).monospacedDigit()
                                        .foregroundColor(gecti ? .white.opacity(0.35) : .white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(sonraki ? VURGU.opacity(0.16) : Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(sonraki ? VURGU.opacity(0.5) : Color.clear, lineWidth: 1))
                            }
                        }
                    }
                }
                Text("Diyanet hesaplama yöntemi; resmî takvimden bir iki dakika farklı olabilir.")
                    .font(.yuvarlak(10)).foregroundColor(.white.opacity(0.35))
            }
        }
    }
}

// MARK: - Deprem

func depremRengi(_ m: Double) -> Color {
    switch m {
    case ..<3: return Color(white: 0.55)
    case ..<4: return .yellow
    case ..<5: return .orange
    default: return .red
    }
}

struct DepremSekmesi: View {
    @ObservedObject var b: Bilgiler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("AFAD · son 48 saat").font(.yuvarlak(13, .semibold)).padding(.trailing, 6)
                ForEach([2.0, 3.0, 4.0], id: \.self) { m in
                    SecimCipi(yazi: "\(Int(m))+", secili: b.depremEsik == m) { b.depremEsik = m }
                }
                Spacer()
                YenileDugmesi(b: b, sekme: SekmeNo.deprem)
            }

            let liste = b.depremler.filter { $0.buyukluk >= b.depremEsik }
            if liste.isEmpty {
                DurumYazisi(yukleniyor: b.yukleniyor.contains(SekmeNo.deprem),
                            hata: b.depremHata ?? (b.depremler.isEmpty ? nil : "Bu büyüklükte deprem yok"))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(liste.prefix(40)) { d in
                            HStack(spacing: 12) {
                                Text(sayi(d.buyukluk, 1))
                                    .font(.yuvarlak(14, .bold)).monospacedDigit()
                                    .foregroundColor(d.buyukluk >= 4 ? .black : .white)
                                    .frame(width: 44, height: 30)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(depremRengi(d.buyukluk)
                                        .opacity(d.buyukluk >= 4 ? 1 : 0.25)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(d.yer).font(.yuvarlak(12, .semibold)).lineLimit(1)
                                    Text("\(sayi(d.derinlik, 1)) km derinlik").font(.yuvarlak(10)).foregroundColor(.white.opacity(0.45))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(onceYazi(d.tarih)).font(.yuvarlak(11, .semibold)).foregroundColor(.white.opacity(0.7))
                                    Text(saat(d.tarih)).font(.yuvarlak(10)).monospacedDigit().foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
}

// MARK: - Haberler

struct HaberSekmesi: View {
    @ObservedObject var b: Bilgiler
    @ObservedObject var u: Uygulama

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(HABER_KAYNAKLARI.indices, id: \.self) { i in
                    SecimCipi(yazi: HABER_KAYNAKLARI[i].ad, secili: b.haberKaynak == i) { b.haberKaynakSec(i) }
                }
                Spacer()
                YenileDugmesi(b: b, sekme: SekmeNo.haber)
            }

            if b.haberler.isEmpty {
                DurumYazisi(yukleniyor: b.yukleniyor.contains(SekmeNo.haber), hata: b.haberHata)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(b.haberler) { h in
                            Button {
                                NSWorkspace.shared.open(h.link)
                                u.paneliKapat()
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Text(h.baslik).font(.yuvarlak(12, .semibold)).lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 6)
                                    if let t = h.tarih {
                                        Text(onceYazi(t)).font(.yuvarlak(10, .semibold)).foregroundColor(.white.opacity(0.4)).fixedSize()
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BasmaStili())
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }
}

// MARK: - Dosya rafı

struct RafSekmesi: View {
    @ObservedObject var a: Araclar
    @State private var hedefte = false
    let kolonlar = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Dosya rafı", systemImage: "tray.full.fill").font(.yuvarlak(13, .semibold))
                Text("Dosyaları çentiğe sürükle, sonra buradan istediğin yere sürükle")
                    .font(.yuvarlak(11)).foregroundColor(.white.opacity(0.45)).lineLimit(1)
                Spacer()
                if !a.raf.isEmpty { HapDugme(yazi: "Temizle", simge: "trash") { a.rafiTemizle() } }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(hedefte ? VURGU.opacity(0.12) : Color.white.opacity(0.04))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(hedefte ? VURGU : Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                if a.raf.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill").font(.system(size: 26)).foregroundColor(.white.opacity(0.4))
                        Text("Dosyaları buraya bırak").font(.yuvarlak(13, .semibold)).foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 34)
                } else {
                    LazyVGrid(columns: kolonlar, spacing: 8) {
                        ForEach(a.raf, id: \.self) { url in dosya(url) }
                    }
                    .padding(10)
                }
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $hedefte) { saglayicilar in
                for s in saglayicilar {
                    _ = s.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url { DispatchQueue.main.async { a.rafaEkle([url]) } }
                    }
                }
                return true
            }
        }
    }

    func dosya(_ url: URL) -> some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: 40, height: 40)
            Text(url.lastPathComponent).font(.yuvarlak(10, .medium)).lineLimit(1).truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(alignment: .topTrailing) {
            Button { a.raftanSil(url) } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(3)
        }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .help(url.path)
    }
}

// MARK: - Pano geçmişi

struct PanoSekmesi: View {
    @ObservedObject var a: Araclar
    @ObservedObject var u: Uygulama

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Pano geçmişi", systemImage: "doc.on.clipboard.fill").font(.yuvarlak(13, .semibold))
                Text("Tıkla: kopyala ve yapıştır").font(.yuvarlak(11)).foregroundColor(.white.opacity(0.45))
                Spacer()
                if !a.pano.isEmpty { HapDugme(yazi: "Temizle", simge: "trash") { a.pano = [] } }
            }

            if !a.panoAcik {
                Kart {
                    HStack {
                        Image(systemName: "pause.circle.fill").foregroundColor(.orange)
                        Text("Pano geçmişi kapalı").font(.yuvarlak(13))
                        Spacer()
                        HapDugme(yazi: "Aç", vurgulu: true) { a.panoAcik = true }
                    }
                }
            } else if a.pano.isEmpty {
                Kart {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.on.doc").foregroundColor(.white.opacity(0.5))
                        Text("Bir şey kopyaladığında burada görünür. Şifreler kaydedilmez.").font(.yuvarlak(12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(a.pano) { o in
                            Button { u.panodanYapistir(o) } label: {
                                HStack(spacing: 10) {
                                    Text(o.metin.replacingOccurrences(of: "\n", with: " ⏎ "))
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .lineLimit(2).multilineTextAlignment(.leading)
                                    Spacer(minLength: 6)
                                    Text(onceYazi(o.tarih)).font(.yuvarlak(10, .semibold)).foregroundColor(.white.opacity(0.4)).fixedSize()
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BasmaStili())
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }
}

// MARK: - Zamanlayıcı

struct ZamanlayiciSekmesi: View {
    @ObservedObject var a: Araclar
    @ObservedObject var u: Uygulama
    let hazir: [Double] = [1, 5, 10, 15, 25, 45, 60]

    var body: some View {
        VStack(spacing: 16) {
            TimelineView(.periodic(from: Date(), by: 0.5)) { baglam in
                let kalan = a.kalan(baglam.date)
                let oran = a.toplam > 0 ? kalan / a.toplam : 0
                HStack(spacing: 26) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 9)
                        Circle().trim(from: 0, to: CGFloat(oran))
                            .stroke(AngularGradient(colors: [Color(red: 1, green: 0.55, blue: 0.3), .orange, Color(red: 1, green: 0.55, blue: 0.3)],
                                                    center: .center),
                                    style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: oran)
                        Text(sureYazi(kalan.rounded(.up)))
                            .font(.yuvarlak(30, .semibold)).monospacedDigit()
                    }
                    .frame(width: 150, height: 150)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(a.calisiyor ? "Çalışıyor" : (a.duraklatilanKalan != nil ? "Duraklatıldı" : "Hazır"))
                            .font(.yuvarlak(11, .bold)).foregroundColor(.orange)
                        HStack(spacing: 10) {
                            MedyaDugmesi(simge: a.calisiyor ? "pause.fill" : "play.fill", buyuk: true) {
                                a.baslatDuraklat()
                                u.dinlenmeyiGuncelle()
                            }
                            MedyaDugmesi(simge: "arrow.counterclockwise") {
                                a.sifirla()
                                u.dinlenmeyiGuncelle()
                            }
                        }
                        Text("Çalışırken kalan süre çentikte görünür").font(.yuvarlak(11)).foregroundColor(.white.opacity(0.4))
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 6) {
                ForEach(hazir, id: \.self) { dk in
                    SecimCipi(yazi: dk == 25 ? "25 🍅" : "\(Int(dk)) dk", secili: a.toplam == dk * 60) {
                        a.sureSec(dk)
                        u.dinlenmeyiGuncelle()
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Sistem

struct SistemSekmesi: View {
    @ObservedObject var a: Araclar

    var body: some View {
        let s = a.sistem
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                halka("İşlemci", s.islemci, "%\(Int((s.islemci * 100).rounded()))", Color(red: 0.4, green: 0.7, blue: 1))
                halka("Bellek", s.bellek, "\(sayi(s.bellekKullanilan, 1)) GB", Color(red: 0.75, green: 0.5, blue: 1))
                halka("Disk", s.disk, "\(Int(s.diskBos)) GB boş", .orange)
                if let p = s.pil {
                    halka(s.sarjOluyor ? "Pil ⚡︎" : "Pil", p, "%\(Int((p * 100).rounded()))", p < 0.2 ? .red : VURGU)
                }
            }
            HStack(spacing: 18) {
                bilgi("clock", "Açık kalma: \(kalanYazi(s.acikKalma).components(separatedBy: " ").prefix(2).joined(separator: " "))")
                bilgi("memorychip", "Toplam bellek: \(Int(s.bellekToplam.rounded())) GB")
                Spacer()
            }
        }
    }

    func halka(_ ad: String, _ deger: Double, _ yazi: String, _ renk: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                Circle().trim(from: 0, to: CGFloat(max(0.001, min(1, deger))))
                    .stroke(renk, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: deger)
                Text("%\(Int((deger * 100).rounded()))").font(.yuvarlak(15, .semibold)).monospacedDigit()
            }
            .frame(width: 84, height: 84)
            Text(ad).font(.yuvarlak(12, .semibold))
            Text(yazi).font(.yuvarlak(10)).foregroundColor(.white.opacity(0.5)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.045)))
    }

    func bilgi(_ simge: String, _ yazi: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: simge).font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
            Text(yazi).font(.yuvarlak(11)).foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Genel ayarlar

struct GenelAyarlar: View {
    @ObservedObject var u: Uygulama
    @ObservedObject var a: Araclar

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            AyarSatiri(simge: "cursorarrow.rays", yazi: "Fareyle aç", aciklama: "İmleci çentiğe götürünce panel açılır") {
                Anahtar(acik: $u.fareyleAc)
            }
            AyarSatiri(simge: "arrow.up.and.down", yazi: "Kaydırarak ses ve parlaklık", aciklama: "Çentikte kaydır: ses · ⇧ Shift ile parlaklık") {
                Anahtar(acik: $u.kaydirmaSes)
            }
            AyarSatiri(simge: "square.grid.3x3.fill", yazi: "Kullandığım özellikler", aciklama: "\(u.secili.count) özellik açık · seçmediklerin gizli") {
                HapDugme(yazi: "Seç", simge: "slider.horizontal.3", vurgulu: true) { u.kurulumuAc() }
            }
            if u.secili.contains("muzik") {
                AyarSatiri(simge: "music.note", yazi: "Çalan şarkıyı çentikte göster") { Anahtar(acik: $u.kompaktAcik) }
            }
            AyarSatiri(simge: "bolt.fill", yazi: "Şarj göstergesi", aciklama: "Şarja takınca ve pil azalınca") {
                Anahtar(acik: $u.sarjGoster)
            }
            AyarSatiri(simge: "airpodspro", yazi: "Kulaklık göstergesi", aciklama: "AirPods / Bluetooth kulaklık bağlanınca") {
                Anahtar(acik: $u.kulaklikGoster)
            }
            if u.secili.contains("deprem") {
                AyarSatiri(simge: "waveform.path.ecg", yazi: "Deprem uyarısı", aciklama: "Bu büyüklük ve üstünde çentikte uyarı") {
                    HStack(spacing: 8) {
                        if u.depremUyari {
                            SayiSecici(deger: sayi(u.depremUyariEsik, 1),
                                       azalt: { u.depremUyariEsik = max(3, u.depremUyariEsik - 0.5) },
                                       arttir: { u.depremUyariEsik = min(7, u.depremUyariEsik + 0.5) })
                        }
                        Anahtar(acik: $u.depremUyari)
                    }
                }
            }
            if u.secili.contains("pano") {
                AyarSatiri(simge: "doc.on.clipboard", yazi: "Pano geçmişini tut", aciklama: "Sadece bellekte, şifreler hariç") {
                    Anahtar(acik: $a.panoAcik)
                }
            }
            AyarSatiri(simge: "cup.and.saucer.fill", yazi: "Uyutmayı engelle", aciklama: "Açıkken Mac ve ekran uyumaz") {
                Anahtar(acik: Binding(get: { a.uyutmaKapali }, set: { _ in u.uyutmaDegistir() }))
            }
            AyarSatiri(simge: "power", yazi: "Mac açılınca otomatik başlat") {
                Anahtar(acik: Binding(get: { u.girisAcik }, set: { u.girisDegistir($0) }))
            }

            HStack {
                Spacer()
                HapDugme(yazi: "Uygulamadan çık", simge: "power") { NSApp.terminate(nil) }
            }
            .padding(.top, 4)
        }
    }
}
