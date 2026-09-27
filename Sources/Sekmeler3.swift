import SwiftUI
import AppKit
import AVFoundation
import QuickLookThumbnailing

// MARK: - Hatırlatıcılar

struct HatirlaticiSekmesi: View {
    @ObservedObject var b: Bilgiler
    @State private var yeni = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").foregroundColor(VURGU)
                    TextField("Yeni hatırlatıcı ekle", text: $yeni)
                        .textFieldStyle(.plain)
                        .font(.yuvarlak(13))
                        .onSubmit { b.hatirlaticiEkle(yeni); yeni = "" }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                HapDugme(yazi: "Anımsatıcılar", simge: "arrow.up.forward.app") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
                }
                YenileDugmesi(b: b, sekme: SekmeNo.hatirlatici)
            }

            if b.hatirlaticiIzniGerekli {
                IzinKarti(simge: "checklist", baslik: "Anımsatıcılar izni", aciklama: "Yapılacaklarını göstermek için",
                          istek: { await b.hatirlaticiIzniIste() })
            } else if b.hatirlaticilar.isEmpty {
                if b.hatirlaticiHata == nil && !b.yukleniyor.contains(SekmeNo.hatirlatici) {
                    Kart {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(VURGU)
                            Text("Yapılacak bir şey yok").font(.yuvarlak(13))
                        }
                    }
                } else {
                    DurumYazisi(yukleniyor: b.yukleniyor.contains(SekmeNo.hatirlatici), hata: b.hatirlaticiHata)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(b.hatirlaticilar) { h in satir(h) }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }

    func satir(_ h: Hatirlatici) -> some View {
        let gecikti = (h.tarih ?? .distantFuture) < Date()
        return HStack(spacing: 10) {
            Button { b.hatirlaticiTamamla(h) } label: {
                Circle().stroke(h.renk, lineWidth: 1.8).frame(width: 17, height: 17).contentShape(Circle())
            }
            .buttonStyle(BasmaStili())
            .help("Tamamlandı")
            Text(h.baslik).font(.yuvarlak(13)).lineLimit(1)
            Spacer()
            if let t = h.tarih {
                Text(Calendar.current.isDateInToday(t) ? "Bugün " + saat(t)
                     : t.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "tr_TR"))))
                    .font(.yuvarlak(11, .semibold))
                    .foregroundColor(gecikti ? .red : .white.opacity(0.5))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
    }
}

// MARK: - Dünya saatleri

struct SaatlerSekmesi: View {
    @ObservedObject var a: Araclar
    let kolonlar = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Dünya saatleri", systemImage: "globe.europe.africa.fill").font(.yuvarlak(13, .semibold))
                Spacer()
                Menu {
                    ForEach(SEHIR_SAATLERI.filter { !a.saatler.contains($0.kimlik) }, id: \.kimlik) { s in
                        Button(s.ad) { a.saatEkle(s.kimlik) }
                    }
                } label: {
                    Label("Şehir ekle", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(a.saatler.count >= 8)
            }

            TimelineView(.periodic(from: Date(), by: 1)) { baglam in
                LazyVGrid(columns: kolonlar, spacing: 10) {
                    ForEach(a.saatler, id: \.self) { kimlik in kart(kimlik, baglam.date) }
                }
            }
        }
    }

    func kart(_ kimlik: String, _ an: Date) -> some View {
        let tz = TimeZone(identifier: kimlik) ?? .current
        var takvim = Calendar(identifier: .gregorian)
        takvim.timeZone = tz
        let saatNo = takvim.component(.hour, from: an)
        let gunduz = (6..<19).contains(saatNo)
        let fark = (tz.secondsFromGMT(for: an) - TimeZone.current.secondsFromGMT(for: an)) / 3600
        let bicim = DateFormatter()
        bicim.timeZone = tz
        bicim.dateFormat = "HH:mm"
        let gunFarki = takvim.component(.day, from: an) != Calendar.current.component(.day, from: an)

        return HStack(spacing: 12) {
            Image(systemName: gunduz ? "sun.max.fill" : "moon.stars.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 18))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(sehirAdi(kimlik)).font(.yuvarlak(12, .semibold))
                Text(fark == 0 ? "Aynı saat" : (fark > 0 ? "+\(fark) sa" : "\(fark) sa") + (gunFarki ? " · başka gün" : ""))
                    .font(.yuvarlak(10)).foregroundColor(.white.opacity(0.45))
            }
            Spacer()
            Text(bicim.string(from: an)).font(.yuvarlak(22, .semibold)).monospacedDigit()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(
            gunduz ? Color(red: 0.2, green: 0.4, blue: 0.75).opacity(0.3) : Color.white.opacity(0.05)))
        .contextMenu { Button("Kaldır") { a.saatSil(kimlik) } }
        .overlay(alignment: .topTrailing) {
            Button { a.saatSil(kimlik) } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
}

// MARK: - Hızlı not

// Arka planı saydam, panelle uyumlu metin alanı
struct NotAlani: NSViewRepresentable {
    @Binding var metin: String

    func makeNSView(context: Context) -> NSScrollView {
        let kaydirma = NSTextView.scrollableTextView()
        kaydirma.drawsBackground = false
        kaydirma.hasVerticalScroller = false
        if let tv = kaydirma.documentView as? NSTextView {
            tv.drawsBackground = false
            tv.isRichText = false
            tv.allowsUndo = true
            tv.font = NSFont.systemFont(ofSize: 14, weight: .regular)
            tv.textColor = .white
            tv.insertionPointColor = NSColor(VURGU)
            tv.textContainerInset = NSSize(width: 4, height: 8)
            tv.string = metin
            tv.delegate = context.coordinator
        }
        return kaydirma
    }

    func updateNSView(_ v: NSScrollView, context: Context) {
        if let tv = v.documentView as? NSTextView, tv.string != metin { tv.string = metin }
    }

    func makeCoordinator() -> Koordinator { Koordinator(self) }

    final class Koordinator: NSObject, NSTextViewDelegate {
        let ust: NotAlani
        init(_ ust: NotAlani) { self.ust = ust }
        func textDidChange(_ n: Notification) {
            if let tv = n.object as? NSTextView { ust.metin = tv.string }
        }
    }
}

struct NotSekmesi: View {
    @ObservedObject var a: Araclar

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Hızlı not", systemImage: "note.text").font(.yuvarlak(13, .semibold))
                Text("Yazdıkların otomatik kaydedilir").font(.yuvarlak(11)).foregroundColor(.white.opacity(0.45))
                Spacer()
                if !a.not.isEmpty {
                    HapDugme(yazi: "Kopyala", simge: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(a.not, forType: .string)
                    }
                    HapDugme(yazi: "Temizle", simge: "trash") { a.not = "" }
                }
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(red: 1, green: 0.85, blue: 0.3).opacity(0.08))
                if a.not.isEmpty {
                    Text("Aklına geleni yaz…").font(.system(size: 14)).foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                }
                NotAlani(metin: $a.not).padding(.horizontal, 6).padding(.vertical, 2)
            }
            .frame(height: 230)
        }
    }
}

// MARK: - Hesap makinesi ve kur çevirici

struct HesapSekmesi: View {
    @ObservedObject var b: Bilgiler
    @State private var ifade = ""
    @State private var miktar = "100"
    @State private var kaynak = "USD"
    @State private var hedef = "TRY"
    let birimler: [(kod: String, ad: String)] = [("TRY", "₺ TL"), ("USD", "$ Dolar"), ("EUR", "€ Euro"),
                                                ("GBP", "£ Sterlin"), ("ALTIN", "Gram altın")]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hesap makinesi
            VStack(alignment: .leading, spacing: 8) {
                Label("Hesap", systemImage: "plus.forwardslash.minus").font(.yuvarlak(13, .semibold))
                HStack(spacing: 10) {
                    TextField("Örn: (1250 + 340) × 18%", text: $ifade)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                    let sonuc = hesapla(ifade)
                    Text(sonuc.map { "= " + sayiKisa($0) } ?? (ifade.isEmpty ? "" : "…"))
                        .font(.yuvarlak(20, .semibold)).monospacedDigit()
                        .foregroundColor(VURGU)
                        .lineLimit(1)
                    if let s = sonuc {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(sayiKisa(s), forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc").font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(BasmaStili())
                        .help("Sonucu kopyala")
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
            }

            // Kur çevirici
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Kur çevirici", systemImage: "arrow.left.arrow.right").font(.yuvarlak(13, .semibold))
                    Spacer()
                    YenileDugmesi(b: b, sekme: SekmeNo.hesap)
                }
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("Miktar", text: $miktar)
                            .textFieldStyle(.plain)
                            .font(.yuvarlak(20, .semibold))
                            .frame(width: 110)
                        birimSecici($kaynak)
                        Button {
                            let t = kaynak; kaynak = hedef; hedef = t
                        } label: {
                            Image(systemName: "arrow.left.arrow.right").font(.system(size: 11, weight: .bold))
                                .frame(width: 26, height: 26).background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(BasmaStili())
                        birimSecici($hedef)
                        Spacer()
                    }
                    HStack {
                        if let m = hesapla(miktar), let k = b.birimTL[kaynak], let h = b.birimTL[hedef], h > 0 {
                            let sonuc = m * k / h
                            Text("\(sayiKisa(m)) \(kisaAd(kaynak)) = ")
                                .font(.yuvarlak(14)).foregroundColor(.white.opacity(0.6))
                            Text("\(sayi(sonuc, sonuc >= 1000 ? 0 : 2)) \(kisaAd(hedef))")
                                .font(.yuvarlak(24, .semibold)).monospacedDigit()
                        } else if b.birimTL.isEmpty {
                            DurumYazisi(yukleniyor: b.yukleniyor.contains(SekmeNo.hesap), hata: b.paraHata)
                                .frame(minHeight: 30)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
            }
        }
    }

    func birimSecici(_ secim: Binding<String>) -> some View {
        Menu {
            ForEach(birimler, id: \.kod) { b in Button(b.ad) { secim.wrappedValue = b.kod } }
        } label: {
            Text(birimler.first { $0.kod == secim.wrappedValue }?.ad ?? secim.wrappedValue)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    func kisaAd(_ kod: String) -> String {
        ["TRY": "₺", "USD": "$", "EUR": "€", "GBP": "£", "ALTIN": "gr altın"][kod] ?? kod
    }

    func sayiKisa(_ d: Double) -> String {
        d.rounded() == d && abs(d) < 1e15 ? sayi(d, 0) : sayi(d, abs(d) >= 1000 ? 2 : 4)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #",$"#, with: "", options: .regularExpression)
    }
}

// MARK: - Ekran görüntüleri

struct KucukResim: View {
    let url: URL
    @State private var resim: NSImage?

    var body: some View {
        ZStack {
            Color.white.opacity(0.06)
            if let r = resim {
                Image(nsImage: r).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundColor(.white.opacity(0.3))
            }
        }
        .onAppear {
            let istek = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 200, height: 130),
                                                     scale: 2, representationTypes: .thumbnail)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: istek) { temsil, _ in
                let r = temsil?.nsImage
                DispatchQueue.main.async { resim = r }
            }
        }
    }
}

struct EkranSekmesi: View {
    @ObservedObject var a: Araclar
    let kolonlar = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Son ekran görüntüleri", systemImage: "camera.viewfinder").font(.yuvarlak(13, .semibold))
                Text("Sürükle, çift tıkla aç").font(.yuvarlak(11)).foregroundColor(.white.opacity(0.45))
                Spacer()
                HapDugme(yazi: "Klasör", simge: "folder") { NSWorkspace.shared.open(ekranGoruntusuKlasoru()) }
                Button { a.ekranGoruntuleriniYenile() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24).background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(BasmaStili())
            }

            if !a.ekranTarandi {
                IzinKarti(simge: "camera.viewfinder", baslik: "Ekran görüntülerini göster",
                          aciklama: "Masaüstü klasörüne erişim izni istenecek", istek: { await a.ekranIlkTarama() })
            } else if a.ekranGoruntuleri.isEmpty {
                Kart {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder").foregroundColor(.white.opacity(0.5))
                        Text("Ekran görüntüsü yok. ⌘⇧4 ile al, burada görünsün.").font(.yuvarlak(12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                LazyVGrid(columns: kolonlar, spacing: 8) {
                    ForEach(a.ekranGoruntuleri.prefix(9), id: \.self) { url in
                        KucukResim(url: url)
                            .frame(height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
                            .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                            .contextMenu {
                                Button("Aç") { NSWorkspace.shared.open(url) }
                                Button("Rafa ekle") { a.rafaEkle([url]) }
                                Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                            }
                            .help(url.lastPathComponent)
                    }
                }
            }
        }
        .onAppear { a.ekranGoruntuleriniYenile() }
    }
}

// MARK: - Ayna (kamera)

final class KameraGorunumu: NSView {
    let oturum = AVCaptureSession()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        guard let cihaz = AVCaptureDevice.default(for: .video),
              let giris = try? AVCaptureDeviceInput(device: cihaz), oturum.canAddInput(giris) else { return }
        oturum.addInput(giris)
        let onizleme = AVCaptureVideoPreviewLayer(session: oturum)
        onizleme.videoGravity = .resizeAspectFill
        if let baglanti = onizleme.connection, baglanti.isVideoMirroringSupported {
            baglanti.automaticallyAdjustsVideoMirroring = false
            baglanti.isVideoMirrored = true
        }
        onizleme.frame = bounds
        onizleme.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(onizleme)
        let o = oturum
        DispatchQueue.global(qos: .userInitiated).async { o.startRunning() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func durdur() {
        let o = oturum
        DispatchQueue.global(qos: .userInitiated).async { o.stopRunning() }
    }
}

struct KameraTemsilcisi: NSViewRepresentable {
    func makeNSView(context: Context) -> KameraGorunumu { KameraGorunumu(frame: .zero) }
    func updateNSView(_ v: KameraGorunumu, context: Context) {}
    static func dismantleNSView(_ v: KameraGorunumu, coordinator: ()) { v.durdur() }
}

struct AynaSekmesi: View {
    @State private var izin = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Ayna", systemImage: "person.crop.square.fill").font(.yuvarlak(13, .semibold))
                Text("Panel kapanınca kamera kapanır").font(.yuvarlak(11)).foregroundColor(.white.opacity(0.45))
                Spacer()
            }
            switch izin {
            case .authorized:
                KameraTemsilcisi()
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            case .notDetermined:
                IzinKarti(simge: "camera.fill", baslik: "Kamera izni", aciklama: "Aynayı kullanmak için",
                          istek: { _ = await AVCaptureDevice.requestAccess(for: .video) })
            default:
                Kart {
                    HStack {
                        Image(systemName: "video.slash.fill").foregroundColor(.orange)
                        Text("Kamera izni yok: Sistem Ayarları → Gizlilik ve Güvenlik → Kamera").font(.yuvarlak(12))
                        Spacer()
                        HapDugme(yazi: "Ayarlar", simge: "gear") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                        }
                    }
                }
            }
        }
    }
}
