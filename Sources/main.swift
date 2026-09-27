import Cocoa
import SwiftUI
import Carbon.HIToolbox
import CoreAudio

// MARK: - Sabitler

let CTRL = CGEventFlags.maskControl.rawValue
let OPT = CGEventFlags.maskAlternate.rawValue
let SHIFT = CGEventFlags.maskShift.rawValue
let CMD = CGEventFlags.maskCommand.rawValue
let EK_MASKE = CTRL | OPT | SHIFT | CMD

// Değiştirici tuşlar: tuş kodu -> sağ/sol ayrı bayrak biti (NX_DEVICE*KEYMASK)
let MOD_BIT: [Int: UInt64] = [55: 0x08, 54: 0x10, 58: 0x20, 61: 0x40, 59: 0x01, 62: 0x2000, 56: 0x02, 60: 0x04, 63: 0x800000]
// "2 kez bas" için sağ ve sol aynı sayılır
let MOD_AILE: [Int: Int] = [55: 1000, 54: 1000, 58: 1001, 61: 1001, 59: 1002, 62: 1002, 56: 1003, 60: 1003, 63: 1004]

enum Islem { case panel, oynat, sonraki, onceki, sesAc, sesKis, sessiz, parlakArt, parlakAzal, uyutma }

// Medya tuşları (NX_KEYTYPE_*)
let NX_OYNAT: Int32 = 16, NX_SONRAKI: Int32 = 19, NX_ONCEKI: Int32 = 20

let OZEL_ADLAR: [Int: String] = [
    1000: "⌘ Command", 1001: "⌥ Option", 1002: "⌃ Control", 1003: "⇧ Shift", 1004: "fn",
    kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
    kVK_Space: "Boşluk", kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥",
    kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "Esc", kVK_CapsLock: "⇪",
    kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
    kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
    kVK_F19: "F19", kVK_F20: "F20",
]

// MARK: - Model

struct Tetik: Equatable {
    var mod = 0          // 0 kapalı, 1 iki kez bas, 2 kısayol
    var tus = -1         // tuş kodu (değiştiriciler için 1000+)
    var ekler: UInt64 = 0
}

struct Eylem {
    let kimlik: String, ad: String, simge: String, islem: Islem, varsayilan: Tetik
    var tetik: Tetik
    var tekrarlanir: Bool { islem == .sesAc || islem == .sesKis }
}

enum Gorunum { case kapali, kompakt, hud, panel }

struct Bildirim: Equatable {
    var simge: String
    var yazi: String
    var deger: Double? = nil
    var kapak: String? = nil
    var alt: String? = nil
    var renk: Color? = nil
}

// Sekmeler: numaralar kayıtlı ayarlarla uyumlu kalsın diye sabit
enum SekmeNo {
    static let muzik = 0, hava = 1, para = 2, mac = 3, mail = 4, kisayollar = 5
    static let takvim = 6, namaz = 7, deprem = 8, haber = 9
    static let raf = 10, pano = 11, zamanlayici = 12, sistem = 13, genel = 14
    static let hatirlatici = 15, saatler = 16, not = 17, hesap = 18, ekran = 19, ayna = 20
}

// Üst sekmeler ve altındaki sekmeler: (ad, simge, renk, alt sekmeler)
let GRUPLAR: [(ad: String, simge: String, renk: Color, alt: [Int])] = [
    ("Müzik", "music.note", Color(red: 1, green: 0.4, blue: 0.6), [SekmeNo.muzik]),
    ("Bilgi", "square.grid.2x2.fill", .yellow, [SekmeNo.hava, SekmeNo.para, SekmeNo.mac, SekmeNo.takvim,
                                                   SekmeNo.hatirlatici, SekmeNo.namaz, SekmeNo.deprem, SekmeNo.haber,
                                                   SekmeNo.saatler, SekmeNo.mail]),
    ("Araçlar", "wrench.and.screwdriver.fill", Color(red: 0.4, green: 0.7, blue: 1),
     [SekmeNo.raf, SekmeNo.pano, SekmeNo.not, SekmeNo.hesap, SekmeNo.zamanlayici, SekmeNo.ekran, SekmeNo.ayna,
      SekmeNo.sistem]),
    ("Ayarlar", "gearshape.fill", Color(white: 0.85), [SekmeNo.kisayollar, SekmeNo.genel]),
]

let SEKME_ADLARI: [Int: (ad: String, simge: String)] = [
    SekmeNo.hava: ("Hava", "cloud.sun.fill"), SekmeNo.para: ("Para", "turkishlirasign"),
    SekmeNo.mac: ("Maç", "soccerball"), SekmeNo.takvim: ("Takvim", "calendar"),
    SekmeNo.namaz: ("Namaz", "moon.stars.fill"), SekmeNo.deprem: ("Deprem", "waveform.path.ecg"),
    SekmeNo.haber: ("Haber", "newspaper.fill"), SekmeNo.mail: ("Mail", "envelope.fill"),
    SekmeNo.raf: ("Raf", "tray.full.fill"), SekmeNo.pano: ("Pano", "doc.on.clipboard.fill"),
    SekmeNo.zamanlayici: ("Zamanlayıcı", "timer"), SekmeNo.sistem: ("Sistem", "cpu"),
    SekmeNo.kisayollar: ("Kısayollar", "keyboard"), SekmeNo.genel: ("Genel", "slider.horizontal.3"),
    SekmeNo.hatirlatici: ("Hatırlatıcı", "checklist"), SekmeNo.saatler: ("Saatler", "globe.europe.africa.fill"),
    SekmeNo.not: ("Not", "note.text"), SekmeNo.hesap: ("Hesap", "plus.forwardslash.minus"),
    SekmeNo.ekran: ("Ekran", "camera.viewfinder"), SekmeNo.ayna: ("Ayna", "person.crop.square.fill"),
]

func grupNo(_ sekme: Int) -> Int { GRUPLAR.firstIndex { $0.alt.contains(sekme) } ?? 0 }

// MARK: - Tuş adları

func karakter(_ kod: Int) -> String? {
    guard let kaynak = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let ptr = TISGetInputSourceProperty(kaynak, kTISPropertyUnicodeKeyLayoutData) else { return nil }
    let veri = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
    var olu: UInt32 = 0
    var uzunluk = 0
    var harfler = [UniChar](repeating: 0, count: 4)
    let durum = veri.withUnsafeBytes { tampon -> OSStatus in
        guard let duzen = tampon.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
        return UCKeyTranslate(duzen, UInt16(kod), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                              OptionBits(kUCKeyTranslateNoDeadKeysBit), &olu, 4, &uzunluk, &harfler)
    }
    guard durum == noErr, uzunluk > 0 else { return nil }
    let s = String(utf16CodeUnits: harfler, count: uzunluk).trimmingCharacters(in: .whitespacesAndNewlines)
    return s.isEmpty ? nil : s.uppercased(with: Locale(identifier: "tr_TR"))
}

func tusAdi(_ t: Int) -> String {
    if let ad = OZEL_ADLAR[t] { return ad }
    return karakter(t) ?? "Tuş \(t)"
}

func ekAdi(_ f: UInt64) -> String {
    var s = ""
    if f & CTRL != 0 { s += "⌃" }
    if f & OPT != 0 { s += "⌥" }
    if f & SHIFT != 0 { s += "⇧" }
    if f & CMD != 0 { s += "⌘" }
    return s
}

func tetikAdi(_ t: Tetik) -> String {
    switch t.mod {
    case 1: return tusAdi(t.tus) + " ×2"
    case 2: return ekAdi(t.ekler) + " " + tusAdi(t.tus)
    default: return "—"
    }
}

// MARK: - Ses ve medya

enum Ses {
    @discardableResult
    static func betik(_ kod: String) -> NSAppleEventDescriptor? {
        var hata: NSDictionary?
        return NSAppleScript(source: kod)?.executeAndReturnError(&hata)
    }

    static func seviye() -> Int? {
        guard let s = betik("output volume of (get volume settings)")?.stringValue else { return nil }
        return Int(s)
    }

    static func sessizMi() -> Bool {
        betik("output muted of (get volume settings)")?.booleanValue ?? false
    }

    static func ayarla(_ v: Int) {
        betik("set volume output volume \(min(100, max(0, v)))\nset volume without output muted")
    }

    static func sessiz(_ acik: Bool) {
        betik(acik ? "set volume with output muted" : "set volume without output muted")
    }
}

func medyaTusu(_ tus: Int32) {
    for asagi in [true, false] {
        let durum: Int32 = asagi ? 0xA : 0xB
        let olay = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                      modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(durum) << 8),
                                      timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                                      data1: Int((tus << 16) | (durum << 8)), data2: -1)
        olay?.cgEvent?.post(tap: .cghidEventTap)
    }
}

// MARK: - Klavye dinleme

@MainActor enum Ortak {
    static var uygulama: Uygulama!
}

let tapGeriCagir: CGEventTapCallBack = { _, tur, olay, _ in
    let bastir = MainActor.assumeIsolated { Ortak.uygulama.olay(tur, olay) }
    return bastir ? nil : Unmanaged.passUnretained(olay)
}

// MARK: - Çentik paneli penceresi

final class CentikPaneli: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Uygulama

@MainActor
final class Uygulama: NSObject, NSApplicationDelegate, ObservableObject {
    // Arayüzün izlediği durum
    @Published var gorunum: Gorunum = .kapali
    // Açık sekme (SekmeNo)
    @Published var sekme = min(max(UserDefaults.standard.integer(forKey: "sekme"), 0), 20) {
        didSet { UserDefaults.standard.set(sekme, forKey: "sekme") }
    }
    @Published var bildirim = Bildirim(simge: "music.note", yazi: "")
    @Published var izinVar = false
    @Published var ses: Double = 0.5
    @Published var sessiz = false
    @Published var taslak: [Tetik] = []
    @Published var taslakCiftMs = 300
    @Published var taslakAdim = 6
    // Genel ayarlar (değişince hemen kaydedilir)
    @Published var kompaktAcik = UserDefaults.standard.object(forKey: "kompakt") as? Bool ?? true {
        didSet { ayar.set(kompaktAcik, forKey: "kompakt"); dinlenmeyiGuncelle() }
    }
    @Published var fareyleAc = UserDefaults.standard.object(forKey: "fareyle_ac") as? Bool ?? true {
        didSet { ayar.set(fareyleAc, forKey: "fareyle_ac") }
    }
    @Published var kaydirmaSes = UserDefaults.standard.object(forKey: "kaydirma_ses") as? Bool ?? true {
        didSet { ayar.set(kaydirmaSes, forKey: "kaydirma_ses") }
    }
    @Published var sarjGoster = UserDefaults.standard.object(forKey: "sarj_goster") as? Bool ?? true {
        didSet { ayar.set(sarjGoster, forKey: "sarj_goster") }
    }
    @Published var kulaklikGoster = UserDefaults.standard.object(forKey: "kulaklik_goster") as? Bool ?? true {
        didSet { ayar.set(kulaklikGoster, forKey: "kulaklik_goster") }
    }
    @Published var depremUyari = UserDefaults.standard.object(forKey: "deprem_uyari") as? Bool ?? true {
        didSet { ayar.set(depremUyari, forKey: "deprem_uyari") }
    }
    @Published var depremUyariEsik = UserDefaults.standard.object(forKey: "deprem_esik") as? Double ?? 4.5 {
        didSet { ayar.set(depremUyariEsik, forKey: "deprem_esik") }
    }
    @Published var girisAcik = false
    // Kullanılan özellikler (seçilmeyenlerin sekmeleri gizlenir)
    @Published var secili: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "ozellikler") ?? Array(VARSAYILAN_OZELLIKLER)) {
        didSet {
            ayar.set(Array(secili), forKey: "ozellikler")
            araclar.panoKullaniliyor = secili.contains("pano")
            if !secili.contains("pano") { araclar.pano = [] }
            dinlenmeyiGuncelle()
        }
    }
    @Published var taslakSecili: Set<String> = []
    @Published var kurulumAcik = false
    @Published var kurulumAdim = 0
    @Published var icerikYukseklik: CGFloat = 300 {
        didSet { if gorunum == .panel { yukseklikDegisti(eski: oldValue) } }
    }
    var sigdirmaIsi: DispatchWorkItem?
    @Published var kaydedilen: Int? = nil
    @Published var hata: String? = nil
    @Published var centikGenislik: CGFloat = 200
    @Published var centikYukseklik: CGFloat = 32

    var eylemler: [Eylem] = []
    var ciftMs = 300
    var sesAdimi = 6
    var tap: CFMachPort?
    var sonTus = -1
    var sonZaman = 0.0
    var bastirildi = Set<Int>()
    var izinZamanlayici: Timer?
    var hudIsi: DispatchWorkItem?
    var kapanisIsi: DispatchWorkItem?
    var fareDinleyici: Any?
    // Olaylar.swift
    var fareIleAcildi = false
    var girisIsi: DispatchWorkItem?
    var cikisIsi: DispatchWorkItem?
    var dosyaSurukleniyor = false
    var suruklemeSayaci = NSPasteboard(name: .drag).changeCount
    var kaydirmaBirikim: CGFloat = 0
    var sonPrizde: Bool?
    var sonPilUyari = -1
    var sonCihaz: AudioDeviceID?
    // Her üst sekmede en son açılan alt sekme
    var sonAlt: [Int: Int] = [:]

    var panel: CentikPaneli!
    var durum: NSStatusItem!
    let bilgiler = Bilgiler()
    let araclar = Araclar()

    let ayar = UserDefaults.standard
    let ajanEtiketi = "com.enesskucukk.adax"

    // MARK: Başlangıç

    func applicationDidFinishLaunching(_ bildirim: Notification) {
        eylemleriHazirla()
        durumCubugunuKur()
        paneliKur()
        girisAcik = FileManager.default.fileExists(atPath: ajanDosyasi.path)
        araclar.panoKullaniliyor = secili.contains("pano")
        araclar.bittiginde = { [weak self] in
            self?.hud(Bildirim(simge: "timer", yazi: "Süre doldu", renk: .orange), sure: 5)
            self?.dinlenmeyiGuncelle()
        }
        olaylariBaslat()

        NotificationCenter.default.addObserver(self, selector: #selector(ekranDegisti),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)

        izinVar = tapBaslat()
        if !ayar.bool(forKey: "kurulum_tamam") {
            // İlk açılış: özellik seçimi ve izinler (klavye izni de oradan istenir)
            kurulumuAc()
        } else if !izinVar {
            // Sadece Mac'in izin penceresi açılsın; panel onu örtmesin
            izinIste()
        } else if !CommandLine.arguments.contains("--gizli") {
            paneliAc()
        }
    }

    func eylemleriHazirla() {
        eylemler = [
            Eylem(kimlik: "menu", ad: "Bu paneli aç", simge: "rectangle.topthird.inset.filled", islem: .panel,
                  varsayilan: Tetik(mod: 1, tus: 1000), tetik: Tetik()),
            Eylem(kimlik: "oynat", ad: "Oynat / Duraklat", simge: "playpause.fill", islem: .oynat,
                  varsayilan: Tetik(mod: 1, tus: 1001), tetik: Tetik()),
            Eylem(kimlik: "sessiz", ad: "Sesi kapat / aç", simge: "speaker.slash.fill", islem: .sessiz,
                  varsayilan: Tetik(mod: 2, tus: kVK_ANSI_M, ekler: CTRL | OPT), tetik: Tetik()),
            Eylem(kimlik: "sesac", ad: "Ses aç", simge: "speaker.wave.3.fill", islem: .sesAc,
                  varsayilan: Tetik(mod: 2, tus: kVK_UpArrow, ekler: CTRL | OPT), tetik: Tetik()),
            Eylem(kimlik: "seskis", ad: "Ses kıs", simge: "speaker.wave.1.fill", islem: .sesKis,
                  varsayilan: Tetik(mod: 2, tus: kVK_DownArrow, ekler: CTRL | OPT), tetik: Tetik()),
            Eylem(kimlik: "sonraki", ad: "Sonraki şarkı", simge: "forward.fill", islem: .sonraki,
                  varsayilan: Tetik(mod: 2, tus: kVK_RightArrow, ekler: CTRL | OPT), tetik: Tetik()),
            Eylem(kimlik: "onceki", ad: "Önceki şarkı", simge: "backward.fill", islem: .onceki,
                  varsayilan: Tetik(mod: 2, tus: kVK_LeftArrow, ekler: CTRL | OPT), tetik: Tetik()),
            Eylem(kimlik: "parlakart", ad: "Parlaklık artır", simge: "sun.max.fill", islem: .parlakArt,
                  varsayilan: Tetik(), tetik: Tetik()),
            Eylem(kimlik: "parlakazal", ad: "Parlaklık azalt", simge: "sun.min.fill", islem: .parlakAzal,
                  varsayilan: Tetik(), tetik: Tetik()),
            Eylem(kimlik: "uyutma", ad: "Uyutmayı engelle", simge: "cup.and.saucer.fill", islem: .uyutma,
                  varsayilan: Tetik(), tetik: Tetik()),
        ]
        for i in eylemler.indices { eylemler[i].tetik = eylemler[i].varsayilan }
        oku()
        taslakYukle()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        paneliAc()
        return true
    }

    // MARK: Erişilebilirlik izni

    @discardableResult
    func tapBaslat() -> Bool {
        if tap != nil { return true }
        guard AXIsProcessTrusted() else { return false }
        let maske = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
                                | (1 << CGEventType.flagsChanged.rawValue))
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: maske, callback: tapGeriCagir, userInfo: nil) else { return false }
        let kaynak = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), kaynak, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        tap = t
        return true
    }

    func izinIste() {
        let secenek = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(secenek)
        if izinZamanlayici == nil {
            izinZamanlayici = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(izinKontrol),
                                                   userInfo: nil, repeats: true)
        }
    }

    @objc func izinKontrol() {
        if tapBaslat() {
            izinZamanlayici?.invalidate()
            izinZamanlayici = nil
            izinVar = true
        }
    }

    func izinAyarlariniAc() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: Tuş olayları

    // true dönerse tuş diğer programlara gitmez
    func olay(_ tur: CGEventType, _ e: CGEvent) -> Bool {
        if tur == .tapDisabledByTimeout || tur == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return false
        }
        let kod = Int(e.getIntegerValueField(.keyboardEventKeycode))
        let bayrak = e.flags.rawValue
        switch tur {
        case .flagsChanged:
            if let bit = MOD_BIT[kod], let aile = MOD_AILE[kod], bayrak & bit != 0 {
                tusBasildi(aile, degistirici: true, tekrar: false, ekler: 0)
            }
            return false
        case .keyDown:
            let tekrar = e.getIntegerValueField(.keyboardEventAutorepeat) != 0
            return tusBasildi(kod, degistirici: false, tekrar: tekrar, ekler: bayrak & EK_MASKE)
        case .keyUp:
            return bastirildi.remove(kod) != nil
        default:
            return false
        }
    }

    @discardableResult
    func tusBasildi(_ tus: Int, degistirici: Bool, tekrar: Bool, ekler: UInt64) -> Bool {
        // Panelde tuş kaydediliyor
        if let i = kaydedilen {
            if !degistirici && tus == kVK_Escape {
                kaydedilen = nil
                bastirildi.insert(tus)
                return true
            }
            if taslak[i].mod == 2 && degistirici { return false }   // asıl tuşu bekle
            if tekrar { return true }
            taslak[i].tus = tus
            taslak[i].ekler = taslak[i].mod == 2 ? ekler : 0
            kaydedilen = nil
            if degistirici { return false }
            bastirildi.insert(tus)
            return true
        }

        // Panel açıkken Esc kapatır
        if gorunum == .panel && !degistirici && tus == kVK_Escape {
            paneliKapat()
            bastirildi.insert(tus)
            return true
        }

        // Kısayollar
        if !degistirici {
            for e in eylemler where e.tetik.mod == 2 && e.tetik.tus == tus && e.tetik.ekler == ekler {
                if !tekrar || e.tekrarlanir { calistir(e.islem) }
                sonTus = -1
                bastirildi.insert(tus)
                return true
            }
        }

        // İki kez basma
        if !tekrar {
            let simdi = ProcessInfo.processInfo.systemUptime * 1000
            if tus == sonTus && simdi - sonZaman < Double(ciftMs) {
                for e in eylemler where e.tetik.mod == 1 && e.tetik.tus == tus { calistir(e.islem) }
                sonTus = -1
            } else {
                sonTus = tus
                sonZaman = simdi
            }
        }
        return false
    }

    // MARK: İşlemler

    func calistir(_ islem: Islem) {
        DispatchQueue.main.async { self.yap(islem) }
    }

    func yap(_ islem: Islem, hudGoster: Bool = true) {
        switch islem {
        case .panel:
            gorunum == .panel ? paneliKapat() : paneliAc()
            return
        case .oynat, .sonraki, .onceki:
            let (tus, simge, yazi) = islem == .oynat ? (NX_OYNAT, "playpause.fill", "Oynat / Duraklat")
                : islem == .sonraki ? (NX_SONRAKI, "forward.fill", "Sonraki şarkı") : (NX_ONCEKI, "backward.fill", "Önceki şarkı")
            medyaTusu(tus)
            if hudGoster { hud(Bildirim(simge: simge, yazi: yazi)) }
            // Çalan şarkıyı tazele; gösterge hâlâ açıksa şarkı adını yaz
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.bilgiler.calanYenile { c in
                    if hudGoster, let c = c, self.gorunum == .hud {
                        self.bildirim = Bildirim(simge: c.caliyor ? "play.fill" : "pause.fill", yazi: c.ad, kapak: c.kapak)
                    }
                    self.dinlenmeyiGuncelle()
                }
            }
        case .sesAc, .sesKis:
            sesDegistir(islem == .sesAc ? sesAdimi : -sesAdimi, hudGoster: hudGoster)
        case .parlakArt, .parlakAzal:
            parlaklikDegistir(islem == .parlakArt ? 0.0625 : -0.0625)
        case .uyutma:
            uyutmaDegistir()
        case .sessiz:
            sessiz = !Ses.sessizMi()
            Ses.sessiz(sessiz)
            if hudGoster {
                hud(Bildirim(simge: sesSimgesi(), yazi: sessiz ? "Ses kapalı" : "Ses açık", deger: sessiz ? 0 : ses))
            }
        }
    }

    func sesDegistir(_ fark: Int, hudGoster: Bool = true) {
        let simdi = Ses.seviye() ?? Int(ses * 100)
        let yeni = min(100, max(0, simdi + fark))
        Ses.ayarla(yeni)
        ses = Double(yeni) / 100
        sessiz = false
        if hudGoster { hud(Bildirim(simge: sesSimgesi(), yazi: "%\(yeni)", deger: ses)) }
    }

    func parlaklikDegistir(_ fark: Float) {
        guard let p = parlaklikOku() else {
            medyaTusu(fark > 0 ? 2 : 3)   // dış ekran: parlaklık tuşu gönder
            return
        }
        let yeni = min(1, max(0, p + fark))
        parlaklikAyarla(yeni)
        hud(Bildirim(simge: yeni < 0.5 ? "sun.min.fill" : "sun.max.fill", yazi: "%\(Int((yeni * 100).rounded()))",
                     deger: Double(yeni), renk: .yellow))
    }

    func uyutmaDegistir() {
        araclar.uyutmaDegistir()
        hud(araclar.uyutmaKapali
            ? Bildirim(simge: "cup.and.saucer.fill", yazi: "Mac uyanık kalacak", alt: "Kapatmak için tekrar bas", renk: .orange)
            : Bildirim(simge: "moon.zzz.fill", yazi: "Uyku normale döndü"), sure: 2)
    }

    func sesSimgesi() -> String {
        if sessiz || ses == 0 { return "speaker.slash.fill" }
        if ses < 0.34 { return "speaker.wave.1.fill" }
        if ses < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    func sesiYenile() {
        if let s = Ses.seviye() { ses = Double(s) / 100 }
        sessiz = Ses.sessizMi()
    }

    func sesAyarla(_ v: Double) {
        ses = v
        sessiz = false
        Ses.ayarla(Int((v * 100).rounded()))
    }

    // MARK: Ayarlar

    func oku() {
        if let v = ayar.object(forKey: "cift_ms") as? Int { ciftMs = min(800, max(150, v)) }
        if let v = ayar.object(forKey: "ses_adimi_yuzde") as? Int { sesAdimi = min(25, max(1, v)) }
        for i in eylemler.indices {
            if let a = ayar.array(forKey: "eylem." + eylemler[i].kimlik) as? [Int], a.count == 3 {
                eylemler[i].tetik = Tetik(mod: a[0], tus: a[1], ekler: UInt64(a[2]))
            }
        }
    }

    func yaz() {
        ayar.set(ciftMs, forKey: "cift_ms")
        ayar.set(sesAdimi, forKey: "ses_adimi_yuzde")
        for e in eylemler {
            ayar.set([e.tetik.mod, e.tetik.tus, Int(e.tetik.ekler)], forKey: "eylem." + e.kimlik)
        }
    }

    var ajanDosyasi: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(ajanEtiketi).plist")
    }

    func girisDegistir(_ acik: Bool) {
        do {
            try giristeBaslat(acik)
            girisAcik = acik
        } catch {
            girisAcik = FileManager.default.fileExists(atPath: ajanDosyasi.path)
        }
    }

    func giristeBaslat(_ acik: Bool) throws {
        let dosya = ajanDosyasi
        if !acik {
            if FileManager.default.fileExists(atPath: dosya.path) { try FileManager.default.removeItem(at: dosya) }
            return
        }
        try FileManager.default.createDirectory(at: dosya.deletingLastPathComponent(), withIntermediateDirectories: true)
        let icerik: [String: Any] = [
            "Label": ajanEtiketi,
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath, "--args", "--gizli"],
            "RunAtLoad": true,
        ]
        let veri = try PropertyListSerialization.data(fromPropertyList: icerik, format: .xml, options: 0)
        try veri.write(to: dosya)
    }

    func taslakYukle() {
        taslak = eylemler.map { $0.tetik }
        taslakCiftMs = ciftMs
        taslakAdim = sesAdimi
        kaydedilen = nil
        hata = nil
    }

    func varsayilanaDon() {
        taslak = eylemler.map { $0.varsayilan }
        taslakCiftMs = 300
        taslakAdim = 6
        kaydedilen = nil
        hata = nil
    }

    func modSec(_ i: Int, _ mod: Int) {
        kaydedilen = nil
        taslak[i].mod = mod
        if mod == 2 && taslak[i].tus >= 1000 { taslak[i].tus = -1 }   // kısayolun asıl tuşu ⌘/⌥ olamaz
        if mod == 1 { taslak[i].ekler = 0 }
        if mod != 0 && taslak[i].tus < 0 { kaydetmeBaslat(i) }
    }

    func kaydetmeBaslat(_ i: Int) {
        guard taslak[i].mod != 0 else { return }
        guard tap != nil else { izinIcinKapat { self.izinAyarlariniAc() }; return }
        kaydedilen = (kaydedilen == i) ? nil : i
    }

    func kaydet() {
        kaydedilen = nil
        for (i, t) in taslak.enumerated() where t.mod != 0 && t.tus < 0 {
            hata = "\"\(eylemler[i].ad)\" için tuş seçilmedi"
            return
        }
        for i in taslak.indices {
            for j in (i + 1)..<taslak.count where taslak[i].mod != 0 && taslak[i] == taslak[j] {
                hata = "\"\(eylemler[i].ad)\" ile \"\(eylemler[j].ad)\" aynı tuşu kullanıyor"
                return
            }
        }
        for i in eylemler.indices { eylemler[i].tetik = taslak[i] }
        ciftMs = taslakCiftMs
        sesAdimi = taslakAdim
        yaz()
        hata = nil
        hud(Bildirim(simge: "checkmark.circle.fill", yazi: "Kaydedildi"))
    }

    // MARK: Menü çubuğu

    func durumCubugunuKur() {
        durum = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = durum.button {
            b.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Ada-X")
            b.target = self
            b.action = #selector(durumTiklandi)
        }
    }

    @objc func durumTiklandi() {
        gorunum == .panel ? paneliKapat() : paneliAc()
    }

    // MARK: Panel

    func hedefEkran() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    func paneliKur() {
        panel = CentikPaneli(contentRect: NSRect(x: 0, y: 0, width: 720, height: 760),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.contentView = NSHostingView(rootView: CentikGorunumu(u: self, b: bilgiler))
        konumla()
        // Panel açıkken açık sekmedeki bilgileri tazele (canlı skor, mail)
        Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(periyodikYenile), userInfo: nil, repeats: true)
        // Çalan şarkıyı takip et (çentik göstergesi ve Müzik sekmesi için)
        Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(calanKontrol), userInfo: nil, repeats: true)
        calanKontrol()
    }

    @objc func periyodikYenile() {
        if gorunum == .panel { bilgiler.yenile(sekme) }
    }

    @objc func calanKontrol() {
        if gorunum == .panel && sekme == SekmeNo.sistem { araclar.sistemYenile() }
        guard secili.contains("muzik"), kompaktAcik || (gorunum == .panel && sekme == SekmeNo.muzik) else { return }
        bilgiler.calanYenile { _ in self.dinlenmeyiGuncelle() }
    }

    // Panel ve gösterge kapalıyken çentiğin hâli: şarkı çalıyorsa kompakt, yoksa kapalı
    func dinlenme() -> Gorunum {
        (kompaktAcik && secili.contains("muzik") && bilgiler.calan?.caliyor == true) || araclar.calisiyor ? .kompakt : .kapali
    }

    func dinlenmeyiGuncelle() {
        let hedef = dinlenme()
        if gorunum == .kapali && hedef == .kompakt { goster(.kompakt) }
        if gorunum == .kompakt && hedef == .kapali { gizle() }
    }

    func sekmeSec(_ no: Int) {
        kaydedilen = nil
        sekme = no
        sonAlt[grupNo(no)] = no
        bilgiler.yenile(no)
        if no == SekmeNo.sistem { araclar.sistemYenile() }
    }

    func grupSec(_ g: Int) {
        let alt = gorunurAlt(g)
        guard !alt.isEmpty else { return }
        sekmeSec(sonAlt[g].flatMap { alt.contains($0) ? $0 : nil } ?? alt[0])
    }

    // Seçilmiş özelliklere göre bir üst sekmenin görünen alt sekmeleri
    func gorunurAlt(_ g: Int) -> [Int] {
        GRUPLAR[g].alt.filter { no in ozellikKimligi(no).map { secili.contains($0) } ?? true }
    }

    func gorunurGruplar() -> [Int] {
        GRUPLAR.indices.filter { !gorunurAlt($0).isEmpty }
    }

    func kurulumuAc() {
        taslakSecili = secili
        kurulumAdim = 0
        kurulumAcik = true
        paneliAc()
    }

    func kurulumuBitir() {
        ayar.set(true, forKey: "kurulum_tamam")
        withAnimation(.spring(response: 0.35)) { kurulumAcik = false }
        // Açık sekme gizlendiyse ilk görünen sekmeye geç
        if !(ozellikKimligi(sekme).map { secili.contains($0) } ?? true), let g = gorunurGruplar().first {
            grupSec(g)
        } else {
            bilgiler.yenile(sekme)
        }
    }

    @objc func ekranDegisti() { konumla() }

    func konumla() {
        guard let ekran = hedefEkran() else { return }
        let f = ekran.frame
        if ekran.safeAreaInsets.top > 0, let sol = ekran.auxiliaryTopLeftArea, let sag = ekran.auxiliaryTopRightArea {
            centikGenislik = f.width - sol.width - sag.width
            centikYukseklik = ekran.safeAreaInsets.top
        } else {
            centikGenislik = 200
            centikYukseklik = max(24, f.maxY - ekran.visibleFrame.maxY)
        }
        pencereBoyutu(720, 760)
    }

    func pencereBoyutu(_ g: CGFloat, _ y: CGFloat) {
        guard panel != nil, let e = hedefEkran() else { return }
        panel.setFrame(NSRect(x: e.frame.midX - g / 2, y: e.frame.maxY - y, width: g, height: y), display: true)
    }

    // Görünmez kısımlar tıklamaları yutmasın: panel açıkken pencere sadece panel kadar
    func pencereyiSigdir() {
        guard gorunum == .panel else { return }
        pencereBoyutu(620, min(760, icerikYukseklik + 36))
    }

    func yukseklikDegisti(eski: CGFloat) {
        sigdirmaIsi?.cancel()
        if icerikYukseklik > eski {
            pencereyiSigdir()   // büyürken hemen genişlet ki içerik kesilmesin
        } else {
            let gorev = DispatchWorkItem { [weak self] in self?.pencereyiSigdir() }
            sigdirmaIsi = gorev
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: gorev)
        }
    }

    // İzin penceresini panelin altında bırakmamak için: paneli kapat, izni iste, sonra paneli geri aç
    func izinIcinKapat(_ istek: @escaping () async -> Void) {
        let donulecek = sekme
        paneliKapat()
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            await istek()
            try? await Task.sleep(nanoseconds: 300_000_000)
            self.sekmeSec(donulecek)
            self.paneliAc()
        }
    }

    func goster(_ yeni: Gorunum) {
        guard panel != nil else { return }
        kapanisIsi?.cancel()
        if !panel.isVisible {
            konumla()
            gorunum = .kapali
            panel.orderFrontRegardless()
        } else {
            pencereBoyutu(720, 760)   // açılış animasyonu kesilmesin
        }
        // Sadece panel tıklanabilir; çentik göstergesine tıklama global dinleyiciyle yakalanır
        panel.ignoresMouseEvents = (yeni != .panel)
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { self.gorunum = yeni }
        }
        if yeni == .panel {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.pencereyiSigdir() }
        }
    }

    func gizle() {
        guard panel != nil else { return }
        kaydedilen = nil
        let hedef = dinlenme()
        panel.ignoresMouseEvents = true
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { gorunum = hedef }
        guard hedef == .kapali else { return }
        let gorev = DispatchWorkItem { [weak self] in
            guard let self = self, self.gorunum == .kapali else { return }
            self.panel.orderOut(nil)
        }
        kapanisIsi = gorev
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: gorev)
    }

    func paneliAc(fareIle: Bool = false) {
        hudIsi?.cancel()
        if gorunum != .panel { taslakYukle() }
        fareIleAcildi = fareIle
        sesiYenile()
        bilgiler.yenile(sekme)
        if sekme == SekmeNo.sistem { araclar.sistemYenile() }
        goster(.panel)
        panel.makeKey()
        if fareDinleyici == nil {
            fareDinleyici = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                MainActor.assumeIsolated {
                    let u = Ortak.uygulama!
                    if u.gorunum == .panel { u.paneliKapat() }
                }
            }
        }
    }

    func panodanYapistir(_ o: PanoOgesi) {
        araclar.panoyaKopyala(o)
        paneliKapat()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let kaynak = CGEventSource(stateID: .combinedSessionState)
            for asagi in [true, false] {
                let olay = CGEvent(keyboardEventSource: kaynak, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: asagi)
                olay?.flags = .maskCommand
                olay?.post(tap: .cghidEventTap)
            }
        }
    }

    func paneliKapat() {
        if let d = fareDinleyici { NSEvent.removeMonitor(d); fareDinleyici = nil }
        gizle()
    }

    func hud(_ b: Bildirim, sure: Double = 1.4) {
        bildirim = b
        if gorunum == .panel { return }   // panel açıkken ayrıca gösterme
        hudIsi?.cancel()
        goster(.hud)
        let gorev = DispatchWorkItem { [weak self] in
            guard let self = self, self.gorunum == .hud else { return }
            self.gizle()
        }
        hudIsi = gorev
        DispatchQueue.main.asyncAfter(deadline: .now() + sure, execute: gorev)
    }
}

// MARK: - Görünüm: çentik şekli

struct CentikSekli: Shape {
    var ust: CGFloat = 10
    var alt: CGFloat = 24

    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height, t = ust
        let b = min(alt, h / 2, (w - 2 * t) / 2)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: t, y: t), control: CGPoint(x: t, y: 0))
        p.addLine(to: CGPoint(x: t, y: h - b))
        p.addQuadCurve(to: CGPoint(x: t + b, y: h), control: CGPoint(x: t, y: h))
        p.addLine(to: CGPoint(x: w - t - b, y: h))
        p.addQuadCurve(to: CGPoint(x: w - t, y: h - b), control: CGPoint(x: w - t, y: h))
        p.addLine(to: CGPoint(x: w - t, y: t))
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w - t, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - Görünüm: küçük parçalar

let VURGU = Color(red: 0.36, green: 0.84, blue: 0.62)

extension Font {
    static func yuvarlak(_ boyut: CGFloat, _ agirlik: Font.Weight = .medium) -> Font {
        .system(size: boyut, weight: agirlik, design: .rounded)
    }
}

struct BasmaStili: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct HapDugme: View {
    let yazi: String
    var simge: String? = nil
    var vurgulu = false
    let eylem: () -> Void
    @State private var uzerinde = false

    var body: some View {
        Button(action: eylem) {
            HStack(spacing: 6) {
                if let s = simge { Image(systemName: s).font(.yuvarlak(11, .semibold)) }
                Text(yazi).font(.yuvarlak(12, .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(vurgulu ? .black : .white)
            .background(Capsule().fill(vurgulu ? VURGU : Color.white.opacity(uzerinde ? 0.16 : 0.09)))
            .contentShape(Capsule())
        }
        .buttonStyle(BasmaStili())
        .onHover { uzerinde = $0 }
    }
}

struct MedyaDugmesi: View {
    let simge: String
    var buyuk = false
    let eylem: () -> Void
    @State private var uzerinde = false

    var body: some View {
        Button(action: eylem) {
            Image(systemName: simge)
                .font(.system(size: buyuk ? 24 : 17, weight: .semibold))
                .foregroundColor(buyuk ? .black : .white)
                .frame(width: buyuk ? 58 : 44, height: buyuk ? 58 : 44)
                .background(Circle().fill(buyuk ? Color.white : Color.white.opacity(uzerinde ? 0.16 : 0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(BasmaStili())
        .onHover { uzerinde = $0 }
    }
}

struct SesCubugu: View {
    let deger: Double
    let degisti: (Double) -> Void
    @State private var uzerinde = false

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(Color.white).frame(width: max(0, min(1, deger)) * g.size.width)
            }
            .frame(height: uzerinde ? 10 : 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { d in
                degisti(max(0, min(1, d.location.x / g.size.width)))
            })
        }
        .frame(height: 22)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { uzerinde = h } }
    }
}

struct ModSecici: View {
    let secim: Int
    let sec: (Int) -> Void
    let adlar = ["Kapalı", "2 kez", "Kısayol"]
    @Namespace private var alan

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { sec(i) } } label: {
                    Text(adlar[i])
                        .font(.yuvarlak(11, .semibold))
                        .foregroundColor(secim == i ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ZStack {
                            if secim == i {
                                Capsule().fill(Color.white.opacity(0.17))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                                    .matchedGeometryEffect(id: "secim", in: alan)
                            }
                        })
                        .contentShape(Capsule())
                }
                .buttonStyle(BasmaStili())
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .fixedSize()
    }
}

// Albüm kapağı: internet adresi, dosya ya da renkli yer tutucu
struct KapakResmi: View {
    let yol: String
    let boyut: CGFloat
    let kose: CGFloat

    var body: some View {
        Group {
            if yol.hasPrefix("http"), let url = URL(string: yol) {
                AsyncImage(url: url) { resim in
                    resim.resizable().scaledToFill()
                } placeholder: { yerTutucu }
            } else if !yol.isEmpty, let ns = NSImage(contentsOfFile: yol) {
                Image(nsImage: ns).resizable().scaledToFill()
            } else {
                yerTutucu
            }
        }
        .frame(width: boyut, height: boyut)
        .clipShape(RoundedRectangle(cornerRadius: kose, style: .continuous))
    }

    var yerTutucu: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.42, green: 0.32, blue: 0.95), Color(red: 0.95, green: 0.36, blue: 0.62)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "music.note")
                .font(.system(size: boyut * 0.42, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
        }
    }
}

// Hareketli ses çubukları
struct Ekolayzer: View {
    let caliyor: Bool
    var yukseklik: CGFloat = 16
    var renk: Color = VURGU

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !caliyor)) { baglam in
            let t = baglam.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: yukseklik * 0.16) {
                ForEach(0..<4, id: \.self) { i in
                    let oran = caliyor ? 0.3 + 0.7 * abs(sin(t * (4.6 + Double(i) * 1.35) + Double(i) * 1.9)) : 0.22
                    Capsule().fill(renk).frame(width: yukseklik * 0.19, height: yukseklik * oran)
                }
            }
            .frame(height: yukseklik)
        }
    }
}

struct TusCipi: View {
    let tetik: Tetik
    let kaydediliyor: Bool
    let tikla: () -> Void
    @State private var nabiz = false

    var yazi: String {
        if kaydediliyor { return tetik.mod == 1 ? "Bir tuşa bas…" : "Tuşlara bas…" }
        if tetik.mod == 0 { return "—" }
        if tetik.tus < 0 { return "Tıkla, tuşa bas" }
        return tetikAdi(tetik)
    }

    var body: some View {
        Button(action: tikla) {
            Text(yazi)
                .font(.yuvarlak(12, .semibold))
                .foregroundColor(kaydediliyor ? VURGU : .white)
                .lineLimit(1)
                .frame(width: 128, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(kaydediliyor ? 0.04 : 0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VURGU.opacity(kaydediliyor ? (nabiz ? 1 : 0.3) : 0), lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(BasmaStili())
        .disabled(tetik.mod == 0)
        .opacity(tetik.mod == 0 ? 0.35 : 1)
        .onAppear { nabiz = true }
        .animation(kaydediliyor ? .easeInOut(duration: 0.6).repeatForever() : .default, value: nabiz)
    }
}

struct SayiSecici: View {
    let deger: String
    let azalt: () -> Void
    let arttir: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: azalt) { Image(systemName: "minus").frame(width: 26, height: 24).contentShape(Rectangle()) }
                .buttonStyle(BasmaStili())
            Text(deger).font(.yuvarlak(12, .semibold)).monospacedDigit().frame(minWidth: 56)
            Button(action: arttir) { Image(systemName: "plus").frame(width: 26, height: 24).contentShape(Rectangle()) }
                .buttonStyle(BasmaStili())
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.white)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }
}

// MARK: - Görünüm: ana

struct CentikGorunumu: View {
    @ObservedObject var u: Uygulama
    @ObservedObject var b: Bilgiler
    @Namespace private var sekmeAlani

    var genislik: CGFloat {
        switch u.gorunum {
        case .kapali: return u.centikGenislik + 20
        case .kompakt: return u.centikGenislik + 20 + 2 * 46
        case .hud: return max(u.centikGenislik + 20 + 2 * 90, 360)
        case .panel: return 560
        }
    }

    var alt: CGFloat {
        switch u.gorunum {
        case .panel: return 30
        case .hud: return 20
        default: return 12
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if u.gorunum == .panel {
                    panelIcerik.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
                if u.gorunum == .hud {
                    hudIcerik.transition(.opacity)
                }
                if u.gorunum == .kompakt {
                    kompaktIcerik.transition(.opacity)
                }
            }
            .frame(width: genislik, height: (u.gorunum == .kapali || u.gorunum == .kompakt) ? u.centikYukseklik : nil,
                   alignment: .top)
            .background(CentikSekli(ust: 10, alt: alt).fill(
                LinearGradient(colors: [.black, .black, Color(white: 0.07)], startPoint: .top, endPoint: .bottom)))
            .overlay(CentikSekli(ust: 10, alt: alt).stroke(
                LinearGradient(colors: [.clear, .clear, .white.opacity(0.13)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
            .clipShape(CentikSekli(ust: 10, alt: alt))
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { u.icerikYukseklik = g.size.height }
                    .onChange(of: g.size.height) { u.icerikYukseklik = $0 }
            })
            .compositingGroup()
            .shadow(color: .black.opacity(u.gorunum == .panel || u.gorunum == .hud ? 0.22 : 0), radius: 8, y: 3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }

    // Çentiğin iki yanı: solda şarkı kapağı (ya da zamanlayıcı), sağda ses çubukları ya da kalan süre
    var kompaktIcerik: some View {
        let sarki = u.kompaktAcik && b.calan?.caliyor == true
        return HStack(spacing: 0) {
            if sarki {
                KapakResmi(yol: b.calan?.kapak ?? "", boyut: min(22, u.centikYukseklik - 8), kose: 6)
            } else {
                Image(systemName: "timer").font(.system(size: 13, weight: .bold)).foregroundColor(.orange)
            }
            Spacer(minLength: 0)
            if u.araclar.calisiyor {
                TimelineView(.periodic(from: Date(), by: 0.5)) { baglam in
                    Text(sureYazi(u.araclar.kalan(baglam.date).rounded(.up)))
                        .font(.yuvarlak(12, .bold)).monospacedDigit().foregroundColor(.orange)
                }
            } else {
                Ekolayzer(caliyor: b.calan?.caliyor ?? false, yukseklik: min(14, u.centikYukseklik - 12))
            }
        }
        .padding(.horizontal, 24)
        .frame(height: u.centikYukseklik)
        .contentShape(Rectangle())
        .onTapGesture {
            if !sarki { u.sekmeSec(SekmeNo.zamanlayici) }
            u.paneliAc()
        }
    }

    // Kısa gösterge (kısayola basınca, şarj, kulaklık, deprem...)
    var hudIcerik: some View {
        let bl = u.bildirim
        let renk = bl.renk ?? (bl.simge.hasPrefix("checkmark") ? VURGU : .white)
        return VStack(spacing: 0) {
            Color.clear.frame(height: u.centikYukseklik)
            HStack(spacing: 12) {
                if let k = bl.kapak {
                    KapakResmi(yol: k, boyut: 26, kose: 7)
                } else {
                    Image(systemName: bl.simge)
                        .font(.system(size: bl.alt == nil ? 15 : 20, weight: .semibold))
                        .foregroundColor(renk)
                        .frame(width: bl.alt == nil ? 22 : 30)
                }
                if let d = bl.deger {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        GeometryReader { g in
                            Capsule().fill(bl.renk ?? .white).frame(width: g.size.width * d)
                        }
                    }
                    .frame(height: 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: d)
                    Text(bl.yazi)
                        .font(.yuvarlak(13, .semibold))
                        .monospacedDigit()
                        .fixedSize()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bl.yazi).font(.yuvarlak(13, .semibold)).lineLimit(1)
                        if let a = bl.alt {
                            Text(a).font(.yuvarlak(11, .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if bl.kapak != nil {
                        Ekolayzer(caliyor: b.calan?.caliyor ?? false, yukseklik: 13)
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
    }

    // Açık panel
    var panelIcerik: some View {
        VStack(alignment: .leading, spacing: 16) {
            Color.clear.frame(height: max(0, u.centikYukseklik - 8))

            HStack(spacing: 6) {
                if u.kurulumAcik {
                    Label("Kurulum", systemImage: "sparkles").font(.yuvarlak(12, .semibold)).foregroundColor(VURGU)
                } else {
                    ForEach(u.gorunurGruplar(), id: \.self) { g in grupDugmesi(g) }
                }
                Spacer(minLength: 4)
                Button { u.uyutmaDegistir() } label: {
                    Image(systemName: u.araclar.uyutmaKapali ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(u.araclar.uyutmaKapali ? .orange : .white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(u.araclar.uyutmaKapali ? Color.orange.opacity(0.2) : Color.white.opacity(0.08)))
                }
                .buttonStyle(BasmaStili())
                .help(u.araclar.uyutmaKapali ? "Mac uyanık kalıyor (kapatmak için tıkla)" : "Mac uyumasın")
                Button { u.paneliKapat() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(BasmaStili())
            }

            if u.kurulumAcik {
                KurulumGorunumu(u: u)
            } else {
                sekmeIcerigi
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 22)
        .foregroundColor(.white)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: u.sekme)
    }

    @ViewBuilder var sekmeIcerigi: some View {
        // Alt sekmeler (seçilmeyen özellikler gizli)
        let alt = u.gorunurAlt(grupNo(u.sekme))
        if alt.count > 1 {
            HStack(spacing: 4) {
                ForEach(alt, id: \.self) { no in altSekmeDugmesi(no) }
                Spacer(minLength: 0)
            }
            .padding(.top, -6)
        }

        if !u.izinVar { izinUyarisi }

        Group {
            switch u.sekme {
            case SekmeNo.hava: HavaSekmesi(b: b)
            case SekmeNo.para: ParaSekmesi(b: b)
            case SekmeNo.mac: MacSekmesi(b: b)
            case SekmeNo.mail: MailSekmesi(b: b)
            case SekmeNo.takvim: TakvimSekmesi(b: b)
            case SekmeNo.namaz: NamazSekmesi(b: b)
            case SekmeNo.deprem: DepremSekmesi(b: b)
            case SekmeNo.haber: HaberSekmesi(b: b, u: u)
            case SekmeNo.raf: RafSekmesi(a: u.araclar)
            case SekmeNo.pano: PanoSekmesi(a: u.araclar, u: u)
            case SekmeNo.zamanlayici: ZamanlayiciSekmesi(a: u.araclar, u: u)
            case SekmeNo.sistem: SistemSekmesi(a: u.araclar)
            case SekmeNo.kisayollar: kisayollar
            case SekmeNo.genel: GenelAyarlar(u: u, a: u.araclar)
            case SekmeNo.hatirlatici: HatirlaticiSekmesi(b: b)
            case SekmeNo.saatler: SaatlerSekmesi(a: u.araclar)
            case SekmeNo.not: NotSekmesi(a: u.araclar)
            case SekmeNo.hesap: HesapSekmesi(b: b)
            case SekmeNo.ekran: EkranSekmesi(a: u.araclar)
            case SekmeNo.ayna: AynaSekmesi()
            default: kontroller
            }
        }
    }

    func grupDugmesi(_ g: Int) -> some View {
        let grup = GRUPLAR[g]
        let secili = grupNo(u.sekme) == g
        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { u.grupSec(g) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: grup.simge)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secili ? grup.renk : .white.opacity(0.5))
                Text(grup.ad).font(.yuvarlak(12, .semibold)).fixedSize()
                    .foregroundColor(secili ? .white : .white.opacity(0.55))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(ZStack {
                if secili {
                    Capsule().fill(Color.white.opacity(0.14))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                        .matchedGeometryEffect(id: "grup", in: sekmeAlani)
                } else {
                    Capsule().fill(Color.white.opacity(0.045))
                }
            })
            .contentShape(Capsule())
        }
        .buttonStyle(BasmaStili())
    }

    // Seçili alt sekme simge + yazı, diğerleri sadece simge
    func altSekmeDugmesi(_ no: Int) -> some View {
        let bilgi = SEKME_ADLARI[no] ?? ("", "circle")
        let secili = u.sekme == no
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { u.sekmeSec(no) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: bilgi.simge).font(.system(size: 11, weight: .semibold))
                if secili { Text(bilgi.ad).font(.yuvarlak(11, .semibold)).fixedSize() }
            }
            .foregroundColor(secili ? .white : .white.opacity(0.45))
            .padding(.horizontal, secili ? 10 : 8)
            .padding(.vertical, 5)
            .background(ZStack {
                if secili {
                    Capsule().fill(Color.white.opacity(0.12))
                        .matchedGeometryEffect(id: "alt", in: sekmeAlani)
                }
            })
            .contentShape(Capsule())
        }
        .buttonStyle(BasmaStili())
        .help(bilgi.ad)
    }

    var izinUyarisi: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill").foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Klavye izni gerekiyor").font(.yuvarlak(13, .semibold))
                Text("Erişilebilirlik listesinde Ada-X'i aç")
                    .font(.yuvarlak(11)).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            HapDugme(yazi: "İzin ver", vurgulu: true) { u.izinIcinKapat { u.izinAyarlariniAc() } }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.orange.opacity(0.14)))
    }

    var kontroller: some View {
        VStack(spacing: 18) {
            if !b.muzikIzniBekleyen.isEmpty {
                IzinKarti(simge: "music.note",
                          baslik: "Çalan şarkı izni",
                          aciklama: b.muzikIzniBekleyen.map { $0 == "com.spotify.client" ? "Spotify" : "Müzik" }
                              .joined(separator: " ve ") + " için şarkı bilgisini okumak",
                          istek: { await b.muzikIzniIste() })
            }
            calanKarti

            HStack(spacing: 26) {
                MedyaDugmesi(simge: "backward.fill") { u.yap(.onceki, hudGoster: false) }
                MedyaDugmesi(simge: b.calan.map { $0.caliyor ? "pause.fill" : "play.fill" } ?? "playpause.fill",
                             buyuk: true) { u.yap(.oynat, hudGoster: false) }
                MedyaDugmesi(simge: "forward.fill") { u.yap(.sonraki, hudGoster: false) }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                Button { u.yap(.sessiz, hudGoster: false) } label: {
                    Image(systemName: u.sesSimgesi())
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BasmaStili())
                SesCubugu(deger: u.sessiz ? 0 : u.ses) { u.sesAyarla($0) }
                Text(u.sessiz ? "Kapalı" : "%\(Int((u.ses * 100).rounded()))")
                    .font(.yuvarlak(12, .semibold))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    var calanKarti: some View {
        HStack(spacing: 16) {
            KapakResmi(yol: b.calan?.kapak ?? "", boyut: 84, kose: 16)
                .shadow(color: .black.opacity(0.55), radius: 12, y: 5)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    if let c = b.calan {
                        Ekolayzer(caliyor: c.caliyor, yukseklik: 10)
                        Text((c.uygulama == "Music" ? "APPLE MÜZİK" : "SPOTIFY") + (c.caliyor ? " · ÇALIYOR" : " · DURAKLATILDI"))
                    } else {
                        Text("ŞU AN ÇALAN YOK")
                    }
                }
                .font(.yuvarlak(10, .bold))
                .foregroundColor(VURGU)

                Text(b.calan?.ad ?? "Spotify ya da Müzik'te bir şarkı aç")
                    .font(.yuvarlak(17, .semibold))
                    .lineLimit(1)
                Text(b.calan?.sanatci ?? "Çalan şarkı burada görünür")
                    .font(.yuvarlak(13))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                if let c = b.calan, c.sure > 0 { ilerleme(c) }
            }
            Spacer(minLength: 0)
        }
    }

    func ilerleme(_ c: CalanSarki) -> some View {
        TimelineView(.periodic(from: Date(), by: 1)) { baglam in
            let konum = c.simdikiKonum(baglam.date)
            HStack(spacing: 8) {
                Text(sureYazi(konum))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: g.size.width * CGFloat(konum / max(c.sure, 1)))
                    }
                }
                .frame(height: 4)
                Text(sureYazi(c.sure))
            }
            .font(.yuvarlak(10, .semibold))
            .monospacedDigit()
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 4)
    }

    var kisayollar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(u.eylemler.indices), id: \.self) { i in
                HStack(spacing: 10) {
                    Image(systemName: u.eylemler[i].simge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text(u.eylemler[i].ad).font(.yuvarlak(13)).lineLimit(1)
                    Spacer(minLength: 8)
                    ModSecici(secim: u.taslak[i].mod) { u.modSec(i, $0) }
                    TusCipi(tetik: u.taslak[i], kaydediliyor: u.kaydedilen == i) { u.kaydetmeBaslat(i) }
                }
            }

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.vertical, 4)

            HStack {
                Text("İki basış arası en fazla").font(.yuvarlak(12)).foregroundColor(.white.opacity(0.75))
                Spacer()
                SayiSecici(deger: "\(u.taslakCiftMs) ms",
                           azalt: { u.taslakCiftMs = max(150, u.taslakCiftMs - 50) },
                           arttir: { u.taslakCiftMs = min(800, u.taslakCiftMs + 50) })
            }
            HStack {
                Text("Ses her basışta").font(.yuvarlak(12)).foregroundColor(.white.opacity(0.75))
                Spacer()
                SayiSecici(deger: "%\(u.taslakAdim)",
                           azalt: { u.taslakAdim = max(1, u.taslakAdim - 1) },
                           arttir: { u.taslakAdim = min(25, u.taslakAdim + 1) })
            }

            if let h = u.hata {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(h)
                }
                .font(.yuvarlak(12, .semibold))
                .foregroundColor(.orange)
            }

            HStack(spacing: 8) {
                HapDugme(yazi: "Varsayılan", simge: "arrow.counterclockwise") { u.varsayilanaDon() }
                Spacer()
                HapDugme(yazi: "Kaydet", simge: "checkmark", vurgulu: true) { u.kaydet() }
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Çalıştır

MainActor.assumeIsolated {
    let uygulama = Uygulama()
    Ortak.uygulama = uygulama
    NSApplication.shared.delegate = uygulama
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.run()
}
