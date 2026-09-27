import SwiftUI
import AppKit
import AVFoundation
import EventKit
import Combine

// MARK: - Özellikler

struct Ozellik {
    let kimlik: String
    let ad: String
    let simge: String
    let renk: Color
    let sekme: Int
}

let OZELLIKLER: [Ozellik] = [
    Ozellik(kimlik: "muzik", ad: "Müzik", simge: "music.note", renk: Color(red: 1, green: 0.4, blue: 0.6), sekme: SekmeNo.muzik),
    Ozellik(kimlik: "hava", ad: "Hava", simge: "cloud.sun.fill", renk: .yellow, sekme: SekmeNo.hava),
    Ozellik(kimlik: "para", ad: "Döviz, altın", simge: "turkishlirasign", renk: VURGU, sekme: SekmeNo.para),
    Ozellik(kimlik: "mac", ad: "Maç skorları", simge: "soccerball", renk: .white, sekme: SekmeNo.mac),
    Ozellik(kimlik: "takvim", ad: "Takvim", simge: "calendar", renk: .red, sekme: SekmeNo.takvim),
    Ozellik(kimlik: "hatirlatici", ad: "Hatırlatıcı", simge: "checklist", renk: .orange, sekme: SekmeNo.hatirlatici),
    Ozellik(kimlik: "namaz", ad: "Namaz vakti", simge: "moon.stars.fill", renk: Color(red: 0.3, green: 0.8, blue: 0.7), sekme: SekmeNo.namaz),
    Ozellik(kimlik: "deprem", ad: "Deprem", simge: "waveform.path.ecg", renk: .red, sekme: SekmeNo.deprem),
    Ozellik(kimlik: "haber", ad: "Haberler", simge: "newspaper.fill", renk: Color(red: 0.5, green: 0.7, blue: 1), sekme: SekmeNo.haber),
    Ozellik(kimlik: "saatler", ad: "Dünya saati", simge: "globe.europe.africa.fill", renk: .cyan, sekme: SekmeNo.saatler),
    Ozellik(kimlik: "mail", ad: "Mail", simge: "envelope.fill", renk: Color(red: 0.4, green: 0.7, blue: 1), sekme: SekmeNo.mail),
    Ozellik(kimlik: "raf", ad: "Dosya rafı", simge: "tray.full.fill", renk: Color(red: 0.6, green: 0.6, blue: 1), sekme: SekmeNo.raf),
    Ozellik(kimlik: "pano", ad: "Pano geçmişi", simge: "doc.on.clipboard.fill", renk: Color(white: 0.8), sekme: SekmeNo.pano),
    Ozellik(kimlik: "not", ad: "Hızlı not", simge: "note.text", renk: Color(red: 1, green: 0.85, blue: 0.3), sekme: SekmeNo.not),
    Ozellik(kimlik: "hesap", ad: "Hesap, kur", simge: "plus.forwardslash.minus", renk: .orange, sekme: SekmeNo.hesap),
    Ozellik(kimlik: "zamanlayici", ad: "Zamanlayıcı", simge: "timer", renk: .orange, sekme: SekmeNo.zamanlayici),
    Ozellik(kimlik: "ekran", ad: "Ekran görüntüsü", simge: "camera.viewfinder", renk: Color(red: 0.6, green: 0.8, blue: 1), sekme: SekmeNo.ekran),
    Ozellik(kimlik: "ayna", ad: "Ayna", simge: "person.crop.square.fill", renk: Color(white: 0.85), sekme: SekmeNo.ayna),
    Ozellik(kimlik: "sistem", ad: "Sistem", simge: "cpu", renk: Color(red: 0.75, green: 0.5, blue: 1), sekme: SekmeNo.sistem),
]

let VARSAYILAN_OZELLIKLER: Set<String> = ["muzik", "hava", "para", "takvim", "namaz", "zamanlayici", "not", "hesap", "pano"]

func ozellikKimligi(_ sekme: Int) -> String? { OZELLIKLER.first { $0.sekme == sekme }?.kimlik }

func uygulamaKurulu(_ paket: String) -> Bool {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: paket) != nil
}

// MARK: - İzinler

enum IzinDurumu: Equatable {
    case verildi, bekliyor, reddedildi
}

struct IzinBilgisi: Identifiable {
    let id: String
    let simge: String
    let ad: String
    let neden: String
    let durum: IzinDurumu
    let istek: () async -> Void
}

@MainActor
func izinListesi(_ u: Uygulama) -> [IzinBilgisi] {
    let s = u.secili
    var liste: [IzinBilgisi] = []

    liste.append(IzinBilgisi(
        id: "klavye", simge: "keyboard", ad: "Klavye (Erişilebilirlik)",
        neden: "⌘⌘ gibi kısayolları algılamak için gerekli. Bastığın tuşlar kaydedilmez, hiçbir yere gönderilmez.",
        durum: u.izinVar ? .verildi : .bekliyor,
        istek: { u.izinIste(); u.izinAyarlariniAc() }))

    func otomasyon(_ paket: String) -> IzinDurumu {
        switch otomasyonIzni(paket, sor: false) {
        case noErr: return .verildi
        case -1743: return .reddedildi
        default: return .bekliyor
        }
    }
    // Uygulama kapalıysa izin sorulamaz: önce aç, sonra sor
    func otomasyonIste(_ paket: String) async {
        if !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == paket }),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: paket) {
            let ayar = NSWorkspace.OpenConfiguration()
            ayar.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: ayar)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        _ = await Task.detached { otomasyonIzni(paket, sor: true) }.value
    }

    if s.contains("muzik") {
        for (paket, ad) in [("com.spotify.client", "Spotify"), ("com.apple.Music", "Müzik")] where uygulamaKurulu(paket) {
            liste.append(IzinBilgisi(
                id: paket, simge: "music.note", ad: "\(ad) uygulaması",
                neden: "Çalan şarkının adını, sanatçısını ve kapağını göstermek için \(ad)'a sorar. Hiçbir şeyi değiştirmez.",
                durum: otomasyon(paket), istek: { await otomasyonIste(paket); u.bilgiler.calanYenile() }))
        }
    }

    func ekDurum(_ tur: EKEntityType) -> IzinDurumu {
        let d = EKEventStore.authorizationStatus(for: tur)
        if d == .notDetermined { return .bekliyor }
        if #available(macOS 14, *) { return d == .fullAccess ? .verildi : .reddedildi }
        return d == .authorized ? .verildi : .reddedildi
    }
    if s.contains("takvim") {
        liste.append(IzinBilgisi(
            id: "takvim", simge: "calendar", ad: "Takvim",
            neden: "Bugün ve yarınki etkinliklerini göstermek için. Takvimin sadece okunur.",
            durum: ekDurum(.event), istek: { await u.bilgiler.takvimIzniIste() }))
    }
    if s.contains("hatirlatici") {
        liste.append(IzinBilgisi(
            id: "hatirlatici", simge: "checklist", ad: "Anımsatıcılar",
            neden: "Yapılacaklarını göstermek, tamamlandı işaretlemek ve yenisini eklemek için.",
            durum: ekDurum(.reminder), istek: { await u.bilgiler.hatirlaticiIzniIste() }))
    }
    if s.contains("mail") {
        liste.append(IzinBilgisi(
            id: "mail", simge: "envelope.fill", ad: "Mail uygulaması",
            neden: "Okunmamış ileti sayısını, gönderenleri ve konuları göstermek için. İletilerin içeriği okunmaz.",
            durum: otomasyon("com.apple.mail"), istek: { await otomasyonIste("com.apple.mail"); u.bilgiler.yenile(4, zorla: true) }))
    }
    if s.contains("ekran") {
        liste.append(IzinBilgisi(
            id: "ekran", simge: "camera.viewfinder", ad: "Masaüstü klasörü",
            neden: "Son ekran görüntülerini bulmak için. Sadece ekran görüntüsü dosyaları listelenir.",
            durum: u.araclar.ekranTarandi ? .verildi : .bekliyor, istek: { await u.araclar.ekranIlkTarama() }))
    }
    if s.contains("ayna") {
        let d = AVCaptureDevice.authorizationStatus(for: .video)
        liste.append(IzinBilgisi(
            id: "kamera", simge: "camera.fill", ad: "Kamera",
            neden: "Ayna için. Görüntü kaydedilmez, panel kapanınca kamera kapanır.",
            durum: d == .authorized ? .verildi : (d == .notDetermined ? .bekliyor : .reddedildi),
            istek: { _ = await AVCaptureDevice.requestAccess(for: .video) }))
    }
    return liste
}

// MARK: - Kurulum ekranı

struct KurulumGorunumu: View {
    @ObservedObject var u: Uygulama
    @State private var izinler: [IzinBilgisi]

    init(u: Uygulama) {
        self.u = u
        _izinler = State(initialValue: u.kurulumAdim == 1 ? izinListesi(u) : [])
    }
    let kolonlar = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    let saat = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(u.kurulumAdim == 0 ? "Neleri kullanacaksın?" : "İzinler")
                        .font(.yuvarlak(20, .semibold))
                    Text(u.kurulumAdim == 0
                         ? "Seçtiklerin panelde görünür, diğerleri gizlenir. Sonra Ayarlar'dan değiştirebilirsin."
                         : "Sadece seçtiğin özelliklerin gerektirdiği izinler. İstemediğini atlayabilirsin.")
                        .font(.yuvarlak(12)).foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule().fill(i == u.kurulumAdim ? VURGU : Color.white.opacity(0.2))
                            .frame(width: i == u.kurulumAdim ? 18 : 6, height: 6)
                    }
                }
            }

            if u.kurulumAdim == 0 { secim } else { izinSayfasi }

            HStack(spacing: 8) {
                if u.kurulumAdim == 0 {
                    HapDugme(yazi: u.taslakSecili.count == OZELLIKLER.count ? "Hiçbirini seçme" : "Hepsini seç",
                             simge: "checklist") {
                        withAnimation(.spring(response: 0.3)) {
                            u.taslakSecili = u.taslakSecili.count == OZELLIKLER.count ? [] : Set(OZELLIKLER.map { $0.kimlik })
                        }
                    }
                    Spacer()
                    Text("\(u.taslakSecili.count) seçili").font(.yuvarlak(11)).foregroundColor(.white.opacity(0.45))
                    HapDugme(yazi: "Devam", simge: "arrow.right", vurgulu: true) {
                        u.secili = u.taslakSecili
                        izinler = izinListesi(u)
                        withAnimation(.spring(response: 0.35)) { u.kurulumAdim = 1 }
                    }
                } else {
                    HapDugme(yazi: "Geri", simge: "arrow.left") {
                        withAnimation(.spring(response: 0.35)) { u.kurulumAdim = 0 }
                    }
                    Spacer()
                    HapDugme(yazi: "Bitti", simge: "checkmark", vurgulu: true) { u.kurulumuBitir() }
                }
            }
        }
        .onAppear { if u.kurulumAdim == 1 { izinler = izinListesi(u) } }
        .onReceive(saat) { _ in if u.kurulumAdim == 1 { izinler = izinListesi(u) } }
    }

    var secim: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: kolonlar, spacing: 8) {
                ForEach(OZELLIKLER, id: \.kimlik) { o in karo(o) }
            }
            HStack(spacing: 6) {
                Text("Çentik:").font(.yuvarlak(11, .semibold)).foregroundColor(.white.opacity(0.5))
                SecimCipi(yazi: "Fareyle aç", secili: u.fareyleAc) { u.fareyleAc.toggle() }
                SecimCipi(yazi: "Kaydırarak ses", secili: u.kaydirmaSes) { u.kaydirmaSes.toggle() }
                SecimCipi(yazi: "Şarj", secili: u.sarjGoster) { u.sarjGoster.toggle() }
                SecimCipi(yazi: "Kulaklık", secili: u.kulaklikGoster) { u.kulaklikGoster.toggle() }
                Spacer(minLength: 0)
            }
        }
    }

    func karo(_ o: Ozellik) -> some View {
        let secili = u.taslakSecili.contains(o.kimlik)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if secili { u.taslakSecili.remove(o.kimlik) } else { u.taslakSecili.insert(o.kimlik) }
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: o.simge)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(secili ? o.renk : .white.opacity(0.35))
                Text(o.ad).font(.yuvarlak(11, .semibold)).lineLimit(1)
                    .foregroundColor(secili ? .white : .white.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(secili ? o.renk.opacity(0.14) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(secili ? o.renk.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if secili {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(o.renk).padding(5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BasmaStili())
    }

    var izinSayfasi: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(izinler) { i in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: i.simge)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(i.durum == .verildi ? VURGU : .white.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(i.durum == .verildi ? VURGU.opacity(0.15) : Color.white.opacity(0.07)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(i.ad).font(.yuvarlak(13, .semibold))
                        Text(i.neden).font(.yuvarlak(11)).foregroundColor(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    switch i.durum {
                    case .verildi:
                        Label("Verildi", systemImage: "checkmark.circle.fill")
                            .font(.yuvarlak(11, .semibold)).foregroundColor(VURGU).fixedSize()
                    case .bekliyor:
                        HapDugme(yazi: "İzin ver", vurgulu: true) { u.izinIcinKapat(i.istek) }
                    case .reddedildi:
                        HapDugme(yazi: "Ayarlar", simge: "gear") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
            }
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10))
                Text("Kişisel verilerin hiçbir yere gönderilmez. Hava, kur gibi bilgiler için sadece şehir adı gibi gerekli sorgular yapılır.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.yuvarlak(10)).foregroundColor(.white.opacity(0.4))
            .padding(.top, 2)
        }
    }
}
