import Foundation
import AppKit
import CoreGraphics
import IOKit.pwr_mgt

// MARK: - Parlaklık (dahili ekran, DisplayServices)

private typealias ParlaklikOkuFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias ParlaklikYazFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
private let ekranServisi = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)

func parlaklikOku() -> Float? {
    guard let h = ekranServisi, let f = dlsym(h, "DisplayServicesGetBrightness") else { return nil }
    var deger: Float = -1
    guard unsafeBitCast(f, to: ParlaklikOkuFn.self)(CGMainDisplayID(), &deger) == 0, deger >= 0 else { return nil }
    return deger
}

@discardableResult
func parlaklikAyarla(_ deger: Float) -> Bool {
    guard let h = ekranServisi, let f = dlsym(h, "DisplayServicesSetBrightness") else { return false }
    return unsafeBitCast(f, to: ParlaklikYazFn.self)(CGMainDisplayID(), min(1, max(0, deger))) == 0
}

// MARK: - Dünya saatleri

let SEHIR_SAATLERI: [(ad: String, kimlik: String)] = [
    ("İstanbul", "Europe/Istanbul"), ("Londra", "Europe/London"), ("Berlin", "Europe/Berlin"), ("Paris", "Europe/Paris"),
    ("Amsterdam", "Europe/Amsterdam"), ("Roma", "Europe/Rome"), ("Moskova", "Europe/Moscow"), ("Bakü", "Asia/Baku"),
    ("Dubai", "Asia/Dubai"), ("Delhi", "Asia/Kolkata"), ("Singapur", "Asia/Singapore"), ("Pekin", "Asia/Shanghai"),
    ("Seul", "Asia/Seoul"), ("Tokyo", "Asia/Tokyo"), ("Sidney", "Australia/Sydney"), ("New York", "America/New_York"),
    ("Toronto", "America/Toronto"), ("Chicago", "America/Chicago"), ("Los Angeles", "America/Los_Angeles"),
    ("São Paulo", "America/Sao_Paulo"),
]

func sehirAdi(_ kimlik: String) -> String {
    SEHIR_SAATLERI.first { $0.kimlik == kimlik }?.ad ?? kimlik.components(separatedBy: "/").last ?? kimlik
}

// MARK: - Hesap makinesi (güvenli, kendi ayrıştırıcımız)

// Desteklenen: + - * / × ÷ ^ % ( ) ve ondalık için , ya da .
func hesapla(_ ifade: String) -> Double? {
    var p = HesapAyristirici(ifade)
    guard let sonuc = p.toplam(), p.bitti, sonuc.isFinite else { return nil }
    return sonuc
}

private struct HesapAyristirici {
    let k: [Character]
    var i = 0

    init(_ s: String) {
        k = Array(s.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "x", with: "*").replacingOccurrences(of: ",", with: "."))
    }

    var bitti: Bool { i >= k.count }
    var simdiki: Character? { i < k.count ? k[i] : nil }

    mutating func toplam() -> Double? {
        guard var a = carpim() else { return nil }
        while let c = simdiki, c == "+" || c == "-" {
            i += 1
            guard let b = carpim() else { return nil }
            a = c == "+" ? a + b : a - b
        }
        return a
    }

    mutating func carpim() -> Double? {
        guard var a = us() else { return nil }
        while let c = simdiki, c == "*" || c == "/" {
            i += 1
            guard let b = us() else { return nil }
            if c == "/" && b == 0 { return nil }
            a = c == "*" ? a * b : a / b
        }
        return a
    }

    mutating func us() -> Double? {
        guard let a = tekli() else { return nil }
        if simdiki == "^" {
            i += 1
            guard let b = us() else { return nil }
            return pow(a, b)
        }
        return a
    }

    mutating func tekli() -> Double? {
        if simdiki == "-" { i += 1; return tekli().map { -$0 } }
        if simdiki == "+" { i += 1; return tekli() }
        guard var a = temel() else { return nil }
        while simdiki == "%" { i += 1; a /= 100 }
        return a
    }

    mutating func temel() -> Double? {
        if simdiki == "(" {
            i += 1
            let a = toplam()
            guard simdiki == ")" else { return nil }
            i += 1
            return a
        }
        var s = ""
        while let c = simdiki, c.isNumber || c == "." { s.append(c); i += 1 }
        return Double(s)
    }
}

// MARK: - Ekran görüntüleri

func ekranGoruntusuKlasoru() -> URL {
    if let yol = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !yol.isEmpty {
        return URL(fileURLWithPath: (yol as NSString).expandingTildeInPath)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
}

func sonEkranGoruntuleri() -> [URL] {
    let klasor = ekranGoruntusuKlasoru()
    let onekler = ["Ekran Resmi", "Ekran Görüntüsü", "Ekran Kaydı", "Screenshot", "Screen Shot", "Screen Recording"]
    guard let dosyalar = try? FileManager.default.contentsOfDirectory(
        at: klasor, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return [] }
    return dosyalar
        .filter { u in onekler.contains { u.lastPathComponent.hasPrefix($0) } }
        .map { u in (u, (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        .sorted { $0.1 > $1.1 }
        .prefix(10)
        .map { $0.0 }
}

// MARK: - Uyutma engeli

final class UyutmaEngeli {
    private var kimlik: IOPMAssertionID = 0
    private(set) var acik = false

    func degistir() -> Bool {
        if acik {
            IOPMAssertionRelease(kimlik)
            acik = false
        } else {
            var k: IOPMAssertionID = 0
            let sonuc = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                    "Ada-X: Mac uyanık kalsın" as CFString, &k)
            if sonuc == kIOReturnSuccess {
                kimlik = k
                acik = true
            }
        }
        return acik
    }
}
