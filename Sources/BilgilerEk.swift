import Foundation
import SwiftUI
import AppKit
import EventKit

// MARK: - Modeller

struct Etkinlik: Identifiable {
    let id: String
    let baslik: String
    let baslangic: Date
    let bitis: Date
    let tumGun: Bool
    let renk: Color
    let yer: String?
}

struct Hatirlatici: Identifiable {
    let id: String
    let baslik: String
    let tarih: Date?
    let renk: Color
}

struct Vakit: Identifiable {
    let id: String
    let ad: String
    let simge: String
    let tarih: Date
}

struct Deprem: Identifiable {
    let id: String
    let yer: String
    let buyukluk: Double
    let derinlik: Double
    let tarih: Date
}

struct Haber: Identifiable {
    let id: String
    let baslik: String
    let link: URL
    let tarih: Date?
}

let HABER_KAYNAKLARI: [(ad: String, adres: String)] = [
    ("BBC Türkçe", "https://feeds.bbci.co.uk/turkce/rss.xml"),
    ("NTV", "https://www.ntv.com.tr/son-dakika.rss"),
    ("TRT Haber", "https://www.trthaber.com/manset_articles.rss"),
    ("AA", "https://www.aa.com.tr/tr/rss/default?cat=guncel"),
]

// Aladhan anahtarı -> (Türkçe ad, simge)
let VAKIT_ADLARI: [(anahtar: String, ad: String, simge: String)] = [
    ("Fajr", "İmsak", "moon.stars.fill"), ("Sunrise", "Güneş", "sunrise.fill"), ("Dhuhr", "Öğle", "sun.max.fill"),
    ("Asr", "İkindi", "sun.min.fill"), ("Maghrib", "Akşam", "sunset.fill"), ("Isha", "Yatsı", "moon.fill"),
]

func onceYazi(_ tarih: Date, _ simdi: Date = Date()) -> String {
    let dk = Int(simdi.timeIntervalSince(tarih) / 60)
    if dk < 1 { return "az önce" }
    if dk < 60 { return "\(dk) dk önce" }
    if dk < 1440 { return "\(dk / 60) sa önce" }
    return "\(dk / 1440) gün önce"
}

func kalanYazi(_ saniye: Double) -> String {
    let s = max(0, Int(saniye))
    if s >= 3600 { return "\(s / 3600) sa \((s % 3600) / 60) dk" }
    if s >= 60 { return "\(s / 60) dk \(s % 60) sn" }
    return "\(s) sn"
}

// MARK: - RSS okuyucu

final class RSSOkuyucu: NSObject, XMLParserDelegate {
    var ogeler: [(baslik: String, link: String, tarih: String)] = []
    private var icinde = false
    private var alan = ""
    private var baslik = "", link = "", tarih = ""

    static func oku(_ veri: Data) -> [(baslik: String, link: String, tarih: String)] {
        let o = RSSOkuyucu()
        let p = XMLParser(data: veri)
        p.delegate = o
        p.parse()
        return o.ogeler
    }

    func parser(_ parser: XMLParser, didStartElement ad: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if ad == "item" { icinde = true; baslik = ""; link = ""; tarih = "" }
        alan = ad
    }

    func parser(_ parser: XMLParser, foundCharacters s: String) { ekle(s) }

    func parser(_ parser: XMLParser, foundCDATA blok: Data) {
        if let s = String(data: blok, encoding: .utf8) { ekle(s) }
    }

    private func ekle(_ s: String) {
        guard icinde else { return }
        switch alan {
        case "title": baslik += s
        case "link": link += s
        case "pubDate": tarih += s
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement ad: String, namespaceURI: String?, qualifiedName: String?) {
        if ad == "item" {
            icinde = false
            ogeler.append((baslik.trimmingCharacters(in: .whitespacesAndNewlines),
                           link.trimmingCharacters(in: .whitespacesAndNewlines),
                           tarih.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        alan = ""
    }
}

private struct AFADDeprem: Decodable {
    let eventID: String
    let location: String
    let magnitude: String
    let depth: String
    let date: String
}

private struct VakitCevap: Decodable {
    struct Veri: Decodable { let timings: [String: String] }
    let data: Veri
}

// MARK: - Yükleyiciler

extension Bilgiler {

    // MARK: Takvim

    func takvimYukle() async -> Bool {
        let depo = Bilgiler.takvimDeposu
        let durum = EKEventStore.authorizationStatus(for: .event)
        if durum == .notDetermined {
            takvimIzniGerekli = true
            takvimHata = nil
            return false
        }
        takvimIzniGerekli = false
        var izin = false
        if #available(macOS 14, *) { izin = durum == .fullAccess } else { izin = durum == .authorized }
        guard izin else {
            takvimHata = "Takvim izni yok: Sistem Ayarları → Gizlilik ve Güvenlik → Takvimler"
            return false
        }
        let bugun = Calendar.current.startOfDay(for: Date())
        guard let son = Calendar.current.date(byAdding: .day, value: 2, to: bugun) else { return false }
        let sorgu = depo.predicateForEvents(withStart: bugun, end: son, calendars: nil)
        let simdi = Date()
        etkinlikler = depo.events(matching: sorgu)
            .filter { $0.endDate > simdi }
            .sorted { $0.startDate < $1.startDate }
            .map { e in
                Etkinlik(id: (e.eventIdentifier ?? UUID().uuidString) + "\(e.startDate.timeIntervalSince1970)",
                         baslik: e.title ?? "(Başlıksız)", baslangic: e.startDate, bitis: e.endDate,
                         tumGun: e.isAllDay, renk: Color(nsColor: e.calendar?.color ?? .systemBlue),
                         yer: (e.location?.isEmpty ?? true) ? nil : e.location)
            }
        takvimHata = nil
        return true
    }

    static let takvimDeposu = EKEventStore()

    func takvimIzniIste() async {
        let depo = Bilgiler.takvimDeposu
        if #available(macOS 14, *) { _ = try? await depo.requestFullAccessToEvents() }
        else { _ = try? await depo.requestAccess(to: .event) }
        yenile(6, zorla: true)
    }

    func hatirlaticiIzniIste() async {
        let depo = Bilgiler.takvimDeposu
        if #available(macOS 14, *) { _ = try? await depo.requestFullAccessToReminders() }
        else { _ = try? await depo.requestAccess(to: .reminder) }
        yenile(15, zorla: true)
    }

    // MARK: Hatırlatıcılar

    func hatirlaticiYukle() async -> Bool {
        let durum = EKEventStore.authorizationStatus(for: .reminder)
        if durum == .notDetermined {
            hatirlaticiIzniGerekli = true
            hatirlaticiHata = nil
            return false
        }
        hatirlaticiIzniGerekli = false
        var izin = false
        if #available(macOS 14, *) { izin = durum == .fullAccess } else { izin = durum == .authorized }
        guard izin else {
            hatirlaticiHata = "Anımsatıcılar izni yok: Sistem Ayarları → Gizlilik ve Güvenlik → Anımsatıcılar"
            return false
        }
        let depo = Bilgiler.takvimDeposu
        let sorgu = depo.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let liste: [EKReminder] = await withCheckedContinuation { devam in
            depo.fetchReminders(matching: sorgu) { devam.resume(returning: $0 ?? []) }
        }
        hatirlaticilar = liste
            .map { r in
                Hatirlatici(id: r.calendarItemIdentifier, baslik: r.title ?? "(Başlıksız)",
                            tarih: r.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                            renk: Color(nsColor: r.calendar?.color ?? .systemOrange))
            }
            .sorted { ($0.tarih ?? .distantFuture) < ($1.tarih ?? .distantFuture) }
            .prefix(20)
            .map { $0 }
        hatirlaticiHata = nil
        return true
    }

    func hatirlaticiTamamla(_ h: Hatirlatici) {
        let depo = Bilgiler.takvimDeposu
        guard let r = depo.calendarItem(withIdentifier: h.id) as? EKReminder else { return }
        r.isCompleted = true
        do {
            try depo.save(r, commit: true)
            withAnimation { hatirlaticilar.removeAll { $0.id == h.id } }
        } catch {
            hatirlaticiHata = "Kaydedilemedi"
        }
    }

    func hatirlaticiEkle(_ baslik: String) {
        let metin = baslik.trimmingCharacters(in: .whitespaces)
        guard !metin.isEmpty else { return }
        let depo = Bilgiler.takvimDeposu
        let r = EKReminder(eventStore: depo)
        r.title = metin
        r.calendar = depo.defaultCalendarForNewReminders()
        do {
            try depo.save(r, commit: true)
            yenile(15, zorla: true)
        } catch {
            hatirlaticiHata = "Eklenemedi"
        }
    }

    // MARK: Namaz vakitleri (Diyanet yöntemi)

    func namazYukle() async -> Bool {
        do {
            guard let yer = try await konumBul() else { namazHata = "\"\(sehir)\" bulunamadı"; return false }
            var liste: [Vakit] = []
            let gunYaz = DateFormatter()
            gunYaz.dateFormat = "dd-MM-yyyy"
            // Bugün ve yarın (Yatsı'dan sonra sıradaki vakit yarının İmsak'ı)
            for ekGun in 0...1 {
                guard let gun = Calendar.current.date(byAdding: .day, value: ekGun, to: Date()) else { continue }
                let adres = "https://api.aladhan.com/v1/timings/\(gunYaz.string(from: gun))"
                    + "?latitude=\(yer.latitude)&longitude=\(yer.longitude)&method=13"
                let (v, _) = try await URLSession.shared.data(from: URL(string: adres)!)
                let t = try JSONDecoder().decode(VakitCevap.self, from: v).data.timings
                for va in VAKIT_ADLARI {
                    // "05:22" ya da "05:22 (+03)"
                    guard let s = t[va.anahtar]?.components(separatedBy: " ").first else { continue }
                    let p = s.components(separatedBy: ":").compactMap { Int($0) }
                    guard p.count == 2,
                          let tarih = Calendar.current.date(bySettingHour: p[0], minute: p[1], second: 0, of: gun) else { continue }
                    liste.append(Vakit(id: "\(ekGun)-\(va.anahtar)", ad: va.ad, simge: va.simge, tarih: tarih))
                }
            }
            vakitler = liste
            namazHata = nil
            return true
        } catch {
            namazHata = "Vakitler alınamadı"
            return false
        }
    }

    // MARK: Deprem (AFAD)

    func depremYukle() async -> Bool {
        let bicim = DateFormatter()
        bicim.locale = Locale(identifier: "en_US_POSIX")
        bicim.timeZone = TimeZone(identifier: "UTC")
        bicim.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let son = Date().addingTimeInterval(3600)
        let bas = Date().addingTimeInterval(-2 * 86400)
        var b = URLComponents(string: "https://servisnet.afad.gov.tr/apigateway/deprem/apiv2/event/filter")!
        b.queryItems = [
            .init(name: "start", value: bicim.string(from: bas)), .init(name: "end", value: bicim.string(from: son)),
            .init(name: "minmag", value: "1.5"), .init(name: "orderby", value: "timedesc"), .init(name: "limit", value: "100"),
        ]
        do {
            let (v, _) = try await URLSession.shared.data(from: b.url!)
            let okur = DateFormatter()
            okur.locale = Locale(identifier: "en_US_POSIX")
            okur.timeZone = TimeZone(identifier: "UTC")
            okur.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            depremler = try JSONDecoder().decode([AFADDeprem].self, from: v).compactMap { d in
                guard let t = okur.date(from: String(d.date.prefix(19))) else { return nil }
                return Deprem(id: d.eventID, yer: d.location, buyukluk: Double(d.magnitude) ?? 0,
                              derinlik: Double(d.depth) ?? 0, tarih: t)
            }
            depremHata = nil
            return true
        } catch {
            depremHata = "Deprem bilgisi alınamadı"
            return false
        }
    }

    // Yeni ve büyük depremleri döndürür (ilk yüklemede eskiler için uyarı vermez)
    func yeniBuyukDepremler(esik: Double) -> [Deprem] {
        defer {
            for d in depremler { gorulenDepremler.insert(d.id) }
            ilkDepremYuklemesi = false
        }
        guard !ilkDepremYuklemesi else { return [] }
        return depremler.filter {
            !gorulenDepremler.contains($0.id) && $0.buyukluk >= esik && Date().timeIntervalSince($0.tarih) < 1800
        }
    }

    // MARK: Haberler (RSS)

    func haberYukle() async -> Bool {
        let kaynak = HABER_KAYNAKLARI[haberKaynak]
        do {
            let (v, _) = try await URLSession.shared.data(from: URL(string: kaynak.adres)!)
            let ogeler = await Task.detached { RSSOkuyucu.oku(v) }.value
            let okur = DateFormatter()
            okur.locale = Locale(identifier: "en_US_POSIX")
            let bicimler = ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, d MMM yyyy HH:mm:ss Z"]
            haberler = ogeler.prefix(12).compactMap { o in
                guard !o.baslik.isEmpty, let url = URL(string: o.link) else { return nil }
                var tarih: Date? = nil
                for b in bicimler where tarih == nil {
                    okur.dateFormat = b
                    tarih = okur.date(from: o.tarih)
                }
                return Haber(id: o.link, baslik: o.baslik, link: url, tarih: tarih)
            }
            haberHata = haberler.isEmpty ? "Haber bulunamadı" : nil
            return !haberler.isEmpty
        } catch {
            haberHata = "Haberler alınamadı"
            return false
        }
    }

    func haberKaynakSec(_ no: Int) {
        haberKaynak = no
        ayar.set(no, forKey: "haber_kaynak")
        haberler = []
        yenile(9, zorla: true)
    }
}
