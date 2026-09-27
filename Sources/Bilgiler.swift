import Foundation
import SwiftUI
import AppKit
import Carbon

// MARK: - Modeller

struct HavaGunu: Identifiable {
    let id: String
    let gun: String
    let kod: Int
    let enYuksek: Double
    let enDusuk: Double
}

struct HavaVerisi {
    let sehir: String
    let sicaklik: Double
    let hissedilen: Double
    let nem: Double
    let ruzgar: Double
    let kod: Int
    let gunduz: Bool
    let gunler: [HavaGunu]
}

struct KurSatiri: Identifiable {
    let id: String
    let ad: String
    let simge: String
    let renk: Color
    let deger: Double
    let degisim: Double?
    let basamak: Int
}

struct Mac: Identifiable {
    let id: String
    let ev: String
    let dep: String
    let evSkor: String
    let depSkor: String
    let durum: String      // pre, in, post
    let detay: String
    let favori: Bool
}

struct MailMesaji: Identifiable {
    let id = UUID()
    let kimden: String
    let konu: String
}

struct MailVerisi {
    let kapali: Bool
    let okunmamis: Int
    let mesajlar: [MailMesaji]
}

struct CalanSarki: Equatable {
    let uygulama: String      // Spotify / Music
    let caliyor: Bool
    let ad: String
    let sanatci: String
    let kapak: String          // adres ya da dosya yolu
    let konum: Double          // saniye
    let sure: Double           // saniye
    let alinma: Date

    // İlerleme çubuğu için tahmini anlık konum
    func simdikiKonum(_ an: Date) -> Double {
        guard caliyor else { return konum }
        return min(sure, konum + an.timeIntervalSince(alinma))
    }
}

func sureYazi(_ s: Double) -> String {
    let t = max(0, Int(s))
    return "\(t / 60):" + String(format: "%02d", t % 60)
}

let LIGLER: [(ad: String, kod: String)] = [
    ("Süper Lig", "tur.1"), ("Premier Lig", "eng.1"), ("La Liga", "esp.1"), ("Şampiyonlar Ligi", "uefa.champions"),
]

// MARK: - Sunucu cevapları

struct GeoCevap: Decodable {
    struct Sonuc: Decodable { let name: String; let latitude: Double; let longitude: Double }
    let results: [Sonuc]?
}

private struct HavaCevap: Decodable {
    struct Anlik: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let relative_humidity_2m: Double
        let wind_speed_10m: Double
        let weather_code: Int
        let is_day: Int?
    }
    struct Gunluk: Decodable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let weather_code: [Int]
    }
    let current: Anlik
    let daily: Gunluk
}

private struct KurCevap: Decodable { let rates: [String: Double] }

private struct ESPNCevap: Decodable {
    struct Olay: Decodable { let id: String; let date: String; let status: Durum; let competitions: [Karsilasma] }
    struct Durum: Decodable { let type: Tip; let displayClock: String? }
    struct Tip: Decodable { let state: String; let shortDetail: String }
    struct Karsilasma: Decodable { let competitors: [Takim] }
    struct Takim: Decodable { let homeAway: String; let score: String?; let team: Bilgi }
    struct Bilgi: Decodable { let shortDisplayName: String }
    let events: [Olay]
}

// MARK: - Yardımcılar

func havaSimgesi(_ kod: Int, gunduz: Bool = true) -> String {
    if !gunduz {
        if kod == 0 { return "moon.stars.fill" }
        if kod == 1 || kod == 2 { return "cloud.moon.fill" }
    }
    switch kod {
    case 0: return "sun.max.fill"
    case 1, 2: return "cloud.sun.fill"
    case 3: return "cloud.fill"
    case 45, 48: return "cloud.fog.fill"
    case 51...57: return "cloud.drizzle.fill"
    case 61, 63, 66: return "cloud.rain.fill"
    case 65, 67, 80...82: return "cloud.heavyrain.fill"
    case 71...77, 85, 86: return "cloud.snow.fill"
    case 95...99: return "cloud.bolt.rain.fill"
    default: return "cloud.fill"
    }
}

// Hava kartının arka plan renkleri
func havaRenkleri(_ kod: Int, gunduz: Bool) -> [Color] {
    if !gunduz { return [Color(red: 0.06, green: 0.09, blue: 0.22), Color(red: 0.17, green: 0.2, blue: 0.4)] }
    switch kod {
    case 0, 1: return [Color(red: 0.13, green: 0.42, blue: 0.93), Color(red: 0.33, green: 0.68, blue: 1.0)]
    case 2, 3, 45, 48: return [Color(red: 0.27, green: 0.34, blue: 0.46), Color(red: 0.47, green: 0.55, blue: 0.67)]
    case 71...77, 85, 86: return [Color(red: 0.4, green: 0.55, blue: 0.75), Color(red: 0.65, green: 0.78, blue: 0.92)]
    case 95...99: return [Color(red: 0.22, green: 0.13, blue: 0.38), Color(red: 0.38, green: 0.28, blue: 0.58)]
    default: return [Color(red: 0.17, green: 0.23, blue: 0.42), Color(red: 0.29, green: 0.39, blue: 0.6)]
    }
}

func havaAdi(_ kod: Int) -> String {
    switch kod {
    case 0: return "Açık"
    case 1: return "Az bulutlu"
    case 2: return "Parçalı bulutlu"
    case 3: return "Kapalı"
    case 45, 48: return "Sisli"
    case 51...57: return "Çisenti"
    case 61, 63, 66: return "Yağmurlu"
    case 65, 67: return "Kuvvetli yağmur"
    case 71...77: return "Karlı"
    case 80...82: return "Sağanak"
    case 85, 86: return "Kar sağanağı"
    case 95...99: return "Gök gürültülü"
    default: return "—"
    }
}

// ESPN takım adlarını Türkçe yazar
let TAKIM_ADLARI: [String: String] = [
    "Fenerbahce": "Fenerbahçe", "Besiktas": "Beşiktaş", "Goztepe": "Göztepe", "Caykur Rizespor": "Çaykur Rizespor",
    "Eyupspor": "Eyüpspor", "Basaksehir": "Başakşehir", "Istanbul Basaksehir": "Başakşehir", "Kasimpasa": "Kasımpaşa",
    "Karagumruk": "Karagümrük", "Fatih Karagumruk": "Karagümrük", "Genclerbirligi": "Gençlerbirliği",
    "Gaziantep FK": "Gaziantep FK", "Kayserispor": "Kayserispor", "Erzurum": "Erzurumspor",
]

func turkceAd(_ ad: String) -> String { TAKIM_ADLARI[ad] ?? ad }

func sade(_ s: String) -> String {
    var t = s.lowercased(with: Locale(identifier: "tr_TR"))
    for (a, b) in [("ı", "i"), ("ğ", "g"), ("ü", "u"), ("ş", "s"), ("ö", "o"), ("ç", "c"), ("i̇", "i")] {
        t = t.replacingOccurrences(of: a, with: b)
    }
    return t.trimmingCharacters(in: .whitespaces)
}

func sayi(_ d: Double, _ basamak: Int) -> String {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "tr_TR")
    f.numberStyle = .decimal
    f.minimumFractionDigits = basamak
    f.maximumFractionDigits = basamak
    return f.string(from: NSNumber(value: d)) ?? String(d)
}

func saat(_ tarih: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "tr_TR")
    f.dateFormat = "HH:mm"
    return f.string(from: tarih)
}

// ESPN, URLSession isteklerini reddediyor (403); sistemdeki curl ile çekiyoruz
func curlIle(_ adres: String) -> Data? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    p.arguments = ["-s", "-f", "-m", "15", "--compressed", adres]
    let cikis = Pipe()
    p.standardOutput = cikis
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    let veri = cikis.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return p.terminationStatus == 0 ? veri : nil
}

// Başka bir uygulamayı (Müzik, Spotify, Mail) kontrol izni.
// sor: false -> pencere açmadan durumu söyler. noErr: izin var, -1744: henüz sorulmadı, -1743: reddedildi, -600: uygulama kapalı
func otomasyonIzni(_ paket: String, sor: Bool) -> OSStatus {
    var hedef = AEAddressDesc()
    let veri = Array(paket.utf8)
    let olustur = veri.withUnsafeBytes { AECreateDesc(DescType(typeApplicationBundleID), $0.baseAddress, veri.count, &hedef) }
    guard olustur == noErr else { return OSStatus(olustur) }
    defer { AEDisposeDesc(&hedef) }
    return AEDeterminePermissionToAutomateTarget(&hedef, AEEventClass(typeWildCard), AEEventID(typeWildCard), sor)
}

// osascript'i ayrı süreçte çalıştırır (arayüzü kilitlemez)
func osascript(_ betik: String) -> (cikti: String?, hata: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", betik]
    let cikis = Pipe(), hata = Pipe()
    p.standardOutput = cikis
    p.standardError = hata
    do { try p.run() } catch { return (nil, error.localizedDescription) }
    let veri = cikis.fileHandleForReading.readDataToEndOfFile()
    let hataVeri = hata.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    let hataYazi = String(data: hataVeri, encoding: .utf8) ?? ""
    if p.terminationStatus != 0 { return (nil, hataYazi) }
    return (String(data: veri, encoding: .utf8), "")
}

let MAIL_BETIGI = """
if application "Mail" is not running then return "KAPALI"
tell application "Mail"
    set sonuc to (unread count of inbox) as text
    set liste to (messages of inbox whose read status is false)
    set k to count of liste
    if k > 6 then set k to 6
    repeat with i from 1 to k
        set m to item i of liste
        set sonuc to sonuc & linefeed & (sender of m) & tab & (subject of m)
    end repeat
    return sonuc
end tell
"""

let KAPAK_KLASORU = NSTemporaryDirectory()

// Çalan şarkıyı soran betikler (her satır: uygulama, durum, ad, sanatçı, kapak, konum ms, süre ms)
let SPOTIFY_BETIGI = """
tell application "Spotify"
    if player state is stopped then return ""
    set t to current track
    return "Spotify" & tab & (player state as text) & tab & (name of t) & tab & (artist of t) & tab & (artwork url of t) & tab & ((player position * 1000) as integer) & tab & (duration of t)
end tell
"""

let MUZIK_BETIGI = """
set veri to missing value
tell application "Music"
    if player state is stopped then return ""
    set t to current track
    set yol to "\(KAPAK_KLASORU)ada-kapak-" & (database ID of t) & ".img"
    set sonuc to "Music" & tab & (player state as text) & tab & (name of t) & tab & (artist of t) & tab & yol & tab & ((player position * 1000) as integer) & tab & ((duration of t * 1000) as integer)
    try
        (POSIX file yol) as alias
    on error
        try
            set veri to raw data of artwork 1 of t
        end try
    end try
end tell
if veri is not missing value then
    try
        set dosya to open for access (POSIX file yol) with write permission
        set eof dosya to 0
        write veri to dosya
        close access dosya
    end try
end if
return sonuc
"""

// MARK: - Veriler

@MainActor
final class Bilgiler: ObservableObject {
    @Published var hava: HavaVerisi?
    @Published var havaHata: String?
    @Published var sehir: String
    @Published var kurlar: [KurSatiri] = []
    @Published var paraHata: String?
    @Published var maclar: [Mac] = []
    @Published var macHata: String?
    @Published var ligNo: Int
    @Published var takim: String
    @Published var mail: MailVerisi?
    @Published var mailHata: String?
    @Published var yukleniyor = Set<Int>()
    @Published var guncelleme: [Int: Date] = [:]
    @Published var calan: CalanSarki?
    var calanSoruluyor = false
    // İzin bekleyenler (panelde "İzin ver" düğmesi gösterilir)
    @Published var muzikIzniBekleyen: [String] = []   // paket kimlikleri
    @Published var mailIzniGerekli = false
    @Published var takvimIzniGerekli = false
    @Published var hatirlaticiIzniGerekli = false

    // Takvim, namaz, deprem, haberler (BilgilerEk.swift)
    @Published var etkinlikler: [Etkinlik] = []
    @Published var takvimHata: String?
    @Published var vakitler: [Vakit] = []
    @Published var namazHata: String?
    @Published var depremler: [Deprem] = []
    @Published var depremHata: String?
    @Published var depremEsik: Double {
        didSet { ayar.set(depremEsik, forKey: "deprem_liste_esik") }
    }
    @Published var haberler: [Haber] = []
    @Published var haberHata: String?
    @Published var haberKaynak: Int
    @Published var hatirlaticilar: [Hatirlatici] = []
    @Published var hatirlaticiHata: String?
    // 1 birimin TL karşılığı (kur çevirici için)
    @Published var birimTL: [String: Double] = [:]
    var gorulenDepremler = Set<String>()
    var ilkDepremYuklemesi = true
    var konumOnbellek: (sehir: String, yer: GeoCevap.Sonuc)?

    let ayar = UserDefaults.standard
    // Sekme no -> kaç saniyede bir yenilensin
    let sureler: [Int: TimeInterval] = [1: 900, 2: 300, 3: 60, 4: 30, 6: 60, 7: 1800, 8: 90, 9: 600, 15: 30, 18: 300]

    init() {
        sehir = ayar.string(forKey: "sehir") ?? "İstanbul"
        ligNo = min(max(ayar.integer(forKey: "lig"), 0), LIGLER.count - 1)
        takim = ayar.string(forKey: "takim") ?? ""
        depremEsik = ayar.object(forKey: "deprem_liste_esik") as? Double ?? 2
        haberKaynak = min(max(ayar.integer(forKey: "haber_kaynak"), 0), HABER_KAYNAKLARI.count - 1)
    }

    // Şehrin koordinatları (hava ve namaz vakitleri için, önbellekli)
    func konumBul() async throws -> GeoCevap.Sonuc? {
        if let o = konumOnbellek, o.sehir == sehir { return o.yer }
        var g = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        g.queryItems = [.init(name: "name", value: sehir), .init(name: "count", value: "1"), .init(name: "language", value: "tr")]
        let (gv, _) = try await URLSession.shared.data(from: g.url!)
        guard let yer = try JSONDecoder().decode(GeoCevap.self, from: gv).results?.first else { return nil }
        konumOnbellek = (sehir, yer)
        return yer
    }

    func yenile(_ sekme: Int, zorla: Bool = false) {
        guard let sure = sureler[sekme], !yukleniyor.contains(sekme) else { return }
        if !zorla, let z = guncelleme[sekme], Date().timeIntervalSince(z) < sure { return }
        yukleniyor.insert(sekme)
        Task {
            let tamam: Bool
            switch sekme {
            case 1: tamam = await havaYukle()
            case 2: tamam = await paraYukle()
            case 3: tamam = await macYukle()
            case 6: tamam = await takvimYukle()
            case 7: tamam = await namazYukle()
            case 8: tamam = await depremYukle()
            case 9: tamam = await haberYukle()
            case 15: tamam = await hatirlaticiYukle()
            case 18: tamam = await paraYukle()
            default: tamam = await mailYukle()
            }
            yukleniyor.remove(sekme)
            if tamam { guncelleme[sekme] = Date() }
        }
    }

    // MARK: Çalan şarkı

    func calanYenile(_ bitince: ((CalanSarki?) -> Void)? = nil) {
        guard !calanSoruluyor else { return }
        calanSoruluyor = true
        Task {
            // Sadece açık olan uygulamalara sor (kapalıysa açılmasın)
            let acik = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
            let spotifyAcik = acik.contains("com.spotify.client"), muzikAcik = acik.contains("com.apple.Music")
            // İzni olmayan uygulamaya sorma (sorulursa izin penceresi kendiliğinden açılır)
            let (s, m, bekleyen) = await Task.detached { () -> (String, String, [String]) in
                var bekleyen: [String] = []
                func izinli(_ paket: String) -> Bool {
                    let d = otomasyonIzni(paket, sor: false)
                    if d == -1744 { bekleyen.append(paket) }
                    return d == noErr
                }
                let s = spotifyAcik && izinli("com.spotify.client") ? (osascript(SPOTIFY_BETIGI).cikti ?? "") : ""
                let m = muzikAcik && izinli("com.apple.Music") ? (osascript(MUZIK_BETIGI).cikti ?? "") : ""
                return (s.trimmingCharacters(in: .whitespacesAndNewlines), m.trimmingCharacters(in: .whitespacesAndNewlines), bekleyen)
            }.value
            if muzikIzniBekleyen != bekleyen { muzikIzniBekleyen = bekleyen }
            calanSoruluyor = false
            // Çalan önce, sonra duraklatılmış olan
            let secilen = [s, m].first { $0.contains("\tplaying\t") } ?? (s.isEmpty ? m : s)
            let p = secilen.components(separatedBy: "\t")
            if p.count >= 7 {
                let yeni = CalanSarki(uygulama: p[0], caliyor: p[1] == "playing", ad: p[2], sanatci: p[3], kapak: p[4],
                                      konum: (Double(p[5]) ?? 0) / 1000, sure: (Double(p[6]) ?? 0) / 1000, alinma: Date())
                // Sadece konum değiştiyse gereksiz yere yeniden çizme
                if let c = calan, c.ad == yeni.ad, c.caliyor == yeni.caliyor, c.sanatci == yeni.sanatci,
                   abs(c.simdikiKonum(yeni.alinma) - yeni.konum) < 2 {
                } else {
                    calan = yeni
                }
            } else {
                calan = nil
            }
            bitince?(calan)
        }
    }

    func sehirDegistir(_ yeni: String) {
        let s = yeni.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        sehir = s
        ayar.set(s, forKey: "sehir")
        yenile(1, zorla: true)
        vakitler = []
        guncelleme[7] = nil
    }

    func ligDegistir(_ no: Int) {
        ligNo = no
        ayar.set(no, forKey: "lig")
        maclar = []
        yenile(3, zorla: true)
    }

    func takimDegistir(_ yeni: String) {
        takim = yeni.trimmingCharacters(in: .whitespaces)
        ayar.set(takim, forKey: "takim")
        yenile(3, zorla: true)
    }

    // MARK: Hava

    func havaYukle() async -> Bool {
        do {
            guard let yer = try await konumBul() else {
                havaHata = "\"\(sehir)\" bulunamadı"
                return false
            }

            var h = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            h.queryItems = [
                .init(name: "latitude", value: String(yer.latitude)),
                .init(name: "longitude", value: String(yer.longitude)),
                .init(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"),
                .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
                .init(name: "timezone", value: "auto"),
                .init(name: "forecast_days", value: "5"),
            ]
            let (hv, _) = try await URLSession.shared.data(from: h.url!)
            let c = try JSONDecoder().decode(HavaCevap.self, from: hv)

            let okur = DateFormatter()
            okur.dateFormat = "yyyy-MM-dd"
            let yazar = DateFormatter()
            yazar.locale = Locale(identifier: "tr_TR")
            yazar.dateFormat = "EEE"
            var gunler: [HavaGunu] = []
            for i in c.daily.time.indices {
                let ad = i == 0 ? "Bugün" : okur.date(from: c.daily.time[i]).map { yazar.string(from: $0) } ?? ""
                gunler.append(HavaGunu(id: c.daily.time[i], gun: ad, kod: c.daily.weather_code[i],
                                       enYuksek: c.daily.temperature_2m_max[i], enDusuk: c.daily.temperature_2m_min[i]))
            }
            hava = HavaVerisi(sehir: yer.name, sicaklik: c.current.temperature_2m, hissedilen: c.current.apparent_temperature,
                              nem: c.current.relative_humidity_2m, ruzgar: c.current.wind_speed_10m,
                              kod: c.current.weather_code, gunduz: (c.current.is_day ?? 1) == 1, gunler: gunler)
            havaHata = nil
            return true
        } catch {
            havaHata = "Hava durumu alınamadı"
            return false
        }
    }

    // MARK: Para

    func paraYukle() async -> Bool {
        do {
            async let kurIstegi = URLSession.shared.data(from: URL(string: "https://open.er-api.com/v6/latest/USD")!)
            async let kriptoIstegi = URLSession.shared.data(from: URL(string:
                "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,pax-gold&vs_currencies=try&include_24hr_change=true")!)
            let (kv, _) = try await kurIstegi
            let (cv, _) = try await kriptoIstegi
            let r = try JSONDecoder().decode(KurCevap.self, from: kv).rates
            let k = try JSONDecoder().decode([String: [String: Double]].self, from: cv)

            guard let tl = r["TRY"], let eur = r["EUR"], let gbp = r["GBP"] else { paraHata = "Kur bulunamadı"; return false }
            var liste = [
                KurSatiri(id: "usd", ad: "Dolar", simge: "dollarsign", renk: .green, deger: tl, degisim: nil, basamak: 2),
                KurSatiri(id: "eur", ad: "Euro", simge: "eurosign", renk: .blue, deger: tl / eur, degisim: nil, basamak: 2),
                KurSatiri(id: "gbp", ad: "Sterlin", simge: "sterlingsign", renk: .purple, deger: tl / gbp, degisim: nil, basamak: 2),
            ]
            if let a = k["pax-gold"], let ons = a["try"] {
                liste.append(KurSatiri(id: "altin", ad: "Gram altın", simge: "circle.hexagongrid.fill", renk: .yellow,
                                       deger: ons / 31.1035, degisim: a["try_24h_change"], basamak: 0))
            }
            if let b = k["bitcoin"], let d = b["try"] {
                liste.append(KurSatiri(id: "btc", ad: "Bitcoin", simge: "bitcoinsign", renk: .orange,
                                       deger: d, degisim: b["try_24h_change"], basamak: 0))
            }
            kurlar = liste
            var birim: [String: Double] = ["TRY": 1, "USD": tl, "EUR": tl / eur, "GBP": tl / gbp]
            if let altin = liste.first(where: { $0.id == "altin" }) { birim["ALTIN"] = altin.deger }
            birimTL = birim
            paraHata = nil
            return true
        } catch {
            paraHata = "Kurlar alınamadı"
            return false
        }
    }

    // MARK: Maç

    func macYukle() async -> Bool {
        let lig = LIGLER[ligNo].kod
        do {
            let adres = "https://site.api.espn.com/apis/site/v2/sports/soccer/\(lig)/scoreboard"
            // Sunucu ara sıra hata dönüyor: bir kez daha dene
            var veri = await Task.detached { curlIle(adres) }.value
            if veri == nil {
                try await Task.sleep(nanoseconds: 800_000_000)
                veri = await Task.detached { curlIle(adres) }.value
            }
            guard let v = veri else { macHata = "Maçlar alınamadı"; return false }
            let c = try JSONDecoder().decode(ESPNCevap.self, from: v)

            let okur = DateFormatter()
            okur.locale = Locale(identifier: "en_US_POSIX")
            okur.dateFormat = "yyyy-MM-dd'T'HH:mmX"
            let gunYazar = DateFormatter()
            gunYazar.locale = Locale(identifier: "tr_TR")
            gunYazar.dateFormat = "EEE HH:mm"
            let fav = sade(takim)

            var liste: [Mac] = []
            for o in c.events {
                guard let k = o.competitions.first,
                      let ev = k.competitors.first(where: { $0.homeAway == "home" }),
                      let dep = k.competitors.first(where: { $0.homeAway == "away" }) else { continue }
                let evAd = turkceAd(ev.team.shortDisplayName), depAd = turkceAd(dep.team.shortDisplayName)
                let detay: String
                switch o.status.type.state {
                case "pre": detay = okur.date(from: o.date).map { gunYazar.string(from: $0) } ?? o.status.type.shortDetail
                case "in": detay = o.status.type.shortDetail == "HT" ? "İY" : (o.status.displayClock ?? "Canlı")
                default: detay = "MS"
                }
                let favori = !fav.isEmpty && (sade(evAd).contains(fav) || sade(depAd).contains(fav))
                liste.append(Mac(id: o.id, ev: evAd, dep: depAd, evSkor: ev.score ?? "", depSkor: dep.score ?? "",
                                 durum: o.status.type.state, detay: detay, favori: favori))
            }
            // Favori takım en üstte, sonra canlı maçlar
            maclar = liste.enumerated().sorted { a, b in
                func sira(_ m: Mac) -> Int { m.favori ? 0 : (m.durum == "in" ? 1 : 2) }
                return sira(a.element) != sira(b.element) ? sira(a.element) < sira(b.element) : a.offset < b.offset
            }.map { $0.element }
            macHata = nil
            return true
        } catch {
            macHata = "Maçlar alınamadı"
            return false
        }
    }

    // MARK: Mail

    // İzin penceresini sadece kullanıcı "İzin ver"e basınca aç
    func muzikIzniIste() async {
        let paketler = muzikIzniBekleyen
        await Task.detached { for p in paketler { _ = otomasyonIzni(p, sor: true) } }.value
        muzikIzniBekleyen = []
        calanYenile()
    }

    func mailIzniIste() async {
        _ = await Task.detached { otomasyonIzni("com.apple.mail", sor: true) }.value
        mailIzniGerekli = false
        yenile(4, zorla: true)
    }

    func mailYukle() async -> Bool {
        let acik = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.mail" }
        if acik {
            let durum = await Task.detached { otomasyonIzni("com.apple.mail", sor: false) }.value
            if durum == -1744 {
                mailIzniGerekli = true
                mail = nil
                mailHata = nil
                return false
            }
        }
        mailIzniGerekli = false
        let (cikti, hata) = await Task.detached { osascript(MAIL_BETIGI) }.value
        guard let c = cikti?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            mailHata = hata.contains("-1743")
                ? "Mail'e erişim izni yok: Sistem Ayarları → Gizlilik ve Güvenlik → Otomasyon"
                : "Mail okunamadı"
            return false
        }
        if c == "KAPALI" {
            mail = MailVerisi(kapali: true, okunmamis: 0, mesajlar: [])
            mailHata = nil
            return true
        }
        var satirlar = c.components(separatedBy: "\n")
        let sayi = Int(satirlar.removeFirst()) ?? 0
        let mesajlar = satirlar.compactMap { s -> MailMesaji? in
            let p = s.components(separatedBy: "\t")
            guard p.count >= 2 else { return nil }
            var kimden = p[0]
            if let i = kimden.firstIndex(of: "<") {   // "Ad Soyad <mail@...>" -> "Ad Soyad"
                let ad = kimden[..<i].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                if !ad.isEmpty { kimden = ad }
            }
            return MailMesaji(kimden: kimden, konu: p[1...].joined(separator: " "))
        }
        mail = MailVerisi(kapali: false, okunmamis: sayi, mesajlar: mesajlar)
        mailHata = nil
        return true
    }
}
