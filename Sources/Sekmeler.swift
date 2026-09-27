import SwiftUI
import AppKit

// MARK: - Ortak parçalar

struct Kart<Icerik: View>: View {
    @ViewBuilder let icerik: Icerik
    var body: some View {
        icerik
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
    }
}

struct DurumYazisi: View {
    let yukleniyor: Bool
    let hata: String?
    var body: some View {
        HStack(spacing: 8) {
            if yukleniyor {
                ProgressView().controlSize(.small).scaleEffect(0.8)
                Text("Yükleniyor…")
            } else if let h = hata {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(h)
            }
        }
        .font(.yuvarlak(12, .medium))
        .foregroundColor(.white.opacity(0.7))
        .frame(maxWidth: .infinity, minHeight: 80)
    }
}

struct YenileDugmesi: View {
    @ObservedObject var b: Bilgiler
    let sekme: Int

    var body: some View {
        HStack(spacing: 6) {
            if let z = b.guncelleme[sekme] {
                Text(saat(z)).font(.yuvarlak(10)).foregroundColor(.white.opacity(0.35))
            }
            Button { b.yenile(sekme, zorla: true) } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .rotationEffect(.degrees(b.yukleniyor.contains(sekme) ? 360 : 0))
                    .animation(b.yukleniyor.contains(sekme)
                               ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                               value: b.yukleniyor.contains(sekme))
            }
            .buttonStyle(BasmaStili())
        }
    }
}

struct DuzenlenebilirEtiket: View {
    let simge: String
    let yazi: String
    let ipucu: String
    let kaydet: (String) -> Void
    @State private var duzenle = false
    @State private var yeni = ""

    var body: some View {
        if duzenle {
            HStack(spacing: 6) {
                Image(systemName: simge).font(.system(size: 11, weight: .semibold)).foregroundColor(VURGU)
                TextField(ipucu, text: $yeni)
                    .textFieldStyle(.plain)
                    .font(.yuvarlak(13, .semibold))
                    .frame(width: 150)
                    .onSubmit { kaydet(yeni); duzenle = false }
                Button { kaydet(yeni); duzenle = false } label: {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                        .frame(width: 20, height: 20).background(Circle().fill(VURGU))
                }
                .buttonStyle(BasmaStili())
            }
            .padding(.leading, 10).padding(.trailing, 4).padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.1)))
        } else {
            Button { yeni = yazi; duzenle = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: simge).font(.system(size: 11, weight: .semibold)).foregroundColor(VURGU)
                    Text(yazi.isEmpty ? ipucu : yazi).font(.yuvarlak(13, .semibold))
                        .foregroundColor(.white.opacity(yazi.isEmpty ? 0.45 : 1))
                    Image(systemName: "pencil").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(BasmaStili())
        }
    }
}

// MARK: - Hava

struct HavaSekmesi: View {
    @ObservedObject var b: Bilgiler

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DuzenlenebilirEtiket(simge: "location.fill", yazi: b.hava?.sehir ?? b.sehir, ipucu: "Şehir yaz") {
                    b.sehirDegistir($0)
                }
                Spacer()
                YenileDugmesi(b: b, sekme: 1)
            }

            if let h = b.hava {
                HStack(spacing: 16) {
                    Image(systemName: havaSimgesi(h.kod, gunduz: h.gunduz))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 46))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .frame(width: 60)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(Int(h.sicaklik.rounded()))°").font(.yuvarlak(44, .semibold))
                        Text(havaAdi(h.kod)).font(.yuvarlak(13, .semibold)).foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 7) {
                        bilgi("thermometer", "Hissedilen \(Int(h.hissedilen.rounded()))°")
                        bilgi("humidity.fill", "Nem %\(Int(h.nem.rounded()))")
                        bilgi("wind", "Rüzgar \(Int(h.ruzgar.rounded())) km/s")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: havaRenkleri(h.kod, gunduz: h.gunduz),
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))

                HStack(spacing: 8) {
                    ForEach(h.gunler) { g in
                        VStack(spacing: 6) {
                            Text(g.gun).font(.yuvarlak(11, .semibold)).foregroundColor(.white.opacity(0.6))
                            Image(systemName: havaSimgesi(g.kod))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 18))
                                .frame(height: 22)
                            Text("\(Int(g.enYuksek.rounded()))°").font(.yuvarlak(13, .semibold))
                            Text("\(Int(g.enDusuk.rounded()))°").font(.yuvarlak(11)).foregroundColor(.white.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                    }
                }
            } else {
                DurumYazisi(yukleniyor: b.yukleniyor.contains(1), hata: b.havaHata)
            }
        }
    }

    func bilgi(_ simge: String, _ yazi: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: simge).font(.system(size: 11)).frame(width: 14).foregroundColor(.white.opacity(0.75))
            Text(yazi).font(.yuvarlak(12, .medium)).foregroundColor(.white.opacity(0.95))
        }
    }
}

// MARK: - Para

struct ParaSekmesi: View {
    @ObservedObject var b: Bilgiler
    let kolonlar = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Türk lirası karşılığı", systemImage: "turkishlirasign.circle.fill")
                    .font(.yuvarlak(13, .semibold))
                Spacer()
                YenileDugmesi(b: b, sekme: 2)
            }

            if b.kurlar.isEmpty {
                DurumYazisi(yukleniyor: b.yukleniyor.contains(2), hata: b.paraHata)
            } else {
                LazyVGrid(columns: kolonlar, spacing: 10) {
                    ForEach(b.kurlar) { k in
                        HStack(spacing: 10) {
                            Image(systemName: k.simge)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(k.renk)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(k.renk.opacity(0.18)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k.ad).font(.yuvarlak(11)).foregroundColor(.white.opacity(0.6))
                                Text("₺" + sayi(k.deger, k.basamak)).font(.yuvarlak(15, .semibold)).monospacedDigit()
                            }
                            Spacer(minLength: 0)
                            if let d = k.degisim {
                                Text((d >= 0 ? "▲ " : "▼ ") + sayi(abs(d), 1) + "%")
                                    .font(.yuvarlak(11, .semibold))
                                    .foregroundColor(d >= 0 ? VURGU : .red)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
                    }
                }
                Text("Döviz günlük kur, altın ve bitcoin anlık. Gram altın, ons fiyatından hesaplanır.")
                    .font(.yuvarlak(10))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }
}

// MARK: - Maç

struct MacSekmesi: View {
    @ObservedObject var b: Bilgiler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(LIGLER.indices, id: \.self) { i in
                    Button { b.ligDegistir(i) } label: {
                        Text(LIGLER[i].ad)
                            .font(.yuvarlak(11, .semibold))
                            .foregroundColor(b.ligNo == i ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(b.ligNo == i ? 0.16 : 0.045)))
                            .overlay(Capsule().stroke(Color.white.opacity(b.ligNo == i ? 0.1 : 0), lineWidth: 0.5))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(BasmaStili())
                }
                Spacer()
                YenileDugmesi(b: b, sekme: 3)
            }

            DuzenlenebilirEtiket(simge: "star.fill", yazi: b.takim, ipucu: "Takımını yaz (öne çıkar)") {
                b.takimDegistir($0)
            }

            if b.maclar.isEmpty {
                DurumYazisi(yukleniyor: b.yukleniyor.contains(3), hata: b.macHata ?? "Bu hafta maç yok")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(b.maclar) { m in satir(m) }
                    }
                }
                .frame(maxHeight: 290)
            }
        }
    }

    func satir(_ m: Mac) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                if m.durum == "in" {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                }
                Text(m.detay)
                    .font(.yuvarlak(11, .semibold))
                    .foregroundColor(m.durum == "in" ? .red : .white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(width: 74, alignment: .leading)

            Text(m.ev).font(.yuvarlak(13, .semibold)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(m.durum == "pre" ? "–" : "\(m.evSkor) - \(m.depSkor)")
                .font(.yuvarlak(14, .bold))
                .monospacedDigit()
                .foregroundColor(m.durum == "pre" ? .white.opacity(0.4) : .white)
                .frame(width: 58, height: 26)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(m.durum == "in" ? Color.red.opacity(0.22) : Color.white.opacity(0.08)))

            Text(m.dep).font(.yuvarlak(13, .semibold)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(m.favori ? VURGU.opacity(0.14) : Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(m.favori ? VURGU.opacity(0.5) : Color.clear, lineWidth: 1))
    }
}

// MARK: - Mail

struct MailSekmesi: View {
    @ObservedObject var b: Bilgiler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Gelen kutusu", systemImage: "tray.fill").font(.yuvarlak(13, .semibold))
                Spacer()
                YenileDugmesi(b: b, sekme: 4)
            }

            if b.mailIzniGerekli {
                IzinKarti(simge: "envelope.fill", baslik: "Mail izni", aciklama: "Okunmamış iletileri göstermek için",
                          istek: { await b.mailIzniIste() })
            } else if let m = b.mail {
                if m.kapali {
                    Kart {
                        HStack {
                            Image(systemName: "envelope.badge").font(.system(size: 20)).foregroundColor(.white.opacity(0.6))
                            Text("Mail uygulaması kapalı").font(.yuvarlak(13))
                            Spacer()
                            HapDugme(yazi: "Mail'i aç", simge: "arrow.up.forward.app", vurgulu: true) { mailiAc() }
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(m.okunmamis)").font(.yuvarlak(38, .semibold)).monospacedDigit()
                        Text(m.okunmamis == 0 ? "okunmamış ileti yok 🎉" : "okunmamış ileti")
                            .font(.yuvarlak(13)).foregroundColor(.white.opacity(0.7))
                        Spacer()
                        HapDugme(yazi: "Mail'i aç", simge: "arrow.up.forward.app") { mailiAc() }
                    }
                    VStack(spacing: 6) {
                        ForEach(m.mesajlar) { ileti in
                            HStack(spacing: 10) {
                                Circle().fill(Color.blue).frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ileti.kimden).font(.yuvarlak(12, .semibold)).lineLimit(1)
                                    Text(ileti.konu).font(.yuvarlak(12)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.05)))
                        }
                    }
                }
            } else {
                DurumYazisi(yukleniyor: b.yukleniyor.contains(4), hata: b.mailHata)
            }
            if let h = b.mailHata, b.mail != nil {
                Text(h).font(.yuvarlak(11)).foregroundColor(.orange)
            }
        }
    }

    func mailiAc() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mail.app"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { b.yenile(4, zorla: true) }
    }
}
