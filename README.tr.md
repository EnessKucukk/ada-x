# Ada-X ✦

[English](README.md) · **Türkçe**

MacBook'un çentiğinden açılan şık bir panel: müzik kontrolü, hava, döviz, takvim, namaz vakitleri,
zamanlayıcı ve daha fazlası. Neleri kullanacağını ilk açılışta sen seçersin, gerisi gizlenir.

## Kurulum (Mac)

Terminal'e yapıştır:

```bash
curl -fsSL https://raw.githubusercontent.com/EnessKucukk/ada-x/main/install.sh | bash
```

İlk açılışta kurulum ekranı çıkar:
1. **Neleri kullanacaksın?** Kullanacağın özellikleri seç.
2. **İzinler:** Sadece seçtiklerinin gerektirdiği izinler, her birinin neden istendiği yazılı.

Kişisel verilerin hiçbir yere gönderilmez.

## Kullanım

| | |
|---|---|
| Paneli aç / kapat | **⌘ Command'a 2 kez bas**, çentiğe fareyle gel ya da menü çubuğundaki ♪ |
| Oynat / Duraklat | **⌥ Option'a 2 kez bas** |
| Ses aç / kıs | **⌃⌥ ↑ / ↓** ya da çentiğin üstünde kaydır |
| Parlaklık | **⇧ Shift** basılıyken çentiğin üstünde kaydır |
| Sonraki / önceki şarkı | **⌃⌥ → / ←** |
| Sesi kapat | **⌃⌥ M** |

Bütün tuşlar **Ayarlar → Kısayollar**'dan değiştirilebilir.
Özellik seçimi: **Ayarlar → Genel → Kullandığım özellikler**.

## Özellikler

- **Müzik:** Spotify / Apple Müzik'te çalan şarkı, kapak, ilerleme; çentiğin yanında canlı gösterge
- **Bilgi:** Hava, döviz ve altın, maç skorları, takvim, hatırlatıcılar, namaz vakitleri, deprem (AFAD), haberler, dünya saatleri, mail
- **Araçlar:** Dosya rafı, pano geçmişi, hızlı not, hesap makinesi ve kur çevirici, zamanlayıcı, ekran görüntüleri, ayna, sistem durumu
- **Çentik bildirimleri:** ses, parlaklık, şarj, AirPods bağlanınca pil durumu, büyük deprem uyarısı
- **Uyutma engeli:** tek tıkla Mac uyanık kalır

## Veriler nereden geliyor?

Uygulamanın kendi sunucusu yok, kullanım istatistiği toplamaz, hesap istemez.
İnternetten gelen bilgiler herkese açık, ücretsiz kaynaklardan **doğrudan senin Mac'inden** çekilir.
Sadece seçtiğin özelliklerin kaynağına bağlanılır.

**İnternetten gelenler**

| Özellik | Kaynak | Oraya ne gider? |
|---|---|---|
| Hava | [Open-Meteo](https://open-meteo.com) | Yazdığın şehir adı ve onun koordinatları |
| Namaz vakitleri | [Aladhan](https://aladhan.com) (Diyanet hesaplama yöntemi) | Şehrin koordinatları |
| Döviz (dolar, euro, sterlin) | [ExchangeRate-API](https://www.exchangerate-api.com) açık kuru | Hiçbir şey, sadece istek |
| Gram altın, bitcoin | [CoinGecko](https://www.coingecko.com) | Hiçbir şey. Gram altın, ons fiyatından (PAX Gold) hesaplanır, yaklaşıktır |
| Maç skorları | ESPN'in açık skor verisi (resmî bir servis değildir) | Seçtiğin lig |
| Deprem | [AFAD](https://deprem.afad.gov.tr) | Son 48 saatin tarih aralığı |
| Haberler | BBC Türkçe, NTV, TRT Haber, Anadolu Ajansı RSS | Hiçbir şey, sadece istek |

**Mac'in içinden gelenler (internete hiç gitmez)**

| Özellik | Nereden okunur? |
|---|---|
| Çalan şarkı | Spotify / Müzik uygulaması |
| Takvim, hatırlatıcılar | Mac'teki Takvim ve Anımsatıcılar |
| Mail | Mac'teki Mail uygulaması (sadece gönderen ve konu, içerik okunmaz) |
| Sistem, pil, AirPods | macOS |
| Ekran görüntüleri | Masaüstü (sadece ekran görüntüsü dosyaları) |
| Ayna | Kamera (görüntü kaydedilmez) |

**Mac'te saklananlar**
Ayarların, hızlı notun ve raftaki dosya listesi sadece bu Mac'te saklanır.
Pano geçmişi hiç kaydedilmez, sadece uygulama açıkken bellekte durur. Şifre yöneticilerinin kopyaları alınmaz.

## Kaldırma

```bash
curl -fsSL https://raw.githubusercontent.com/EnessKucukk/ada-x/main/install.sh | bash -s -- kaldir
```

## Kaynaktan derleme

Xcode Komut Satırı Araçları gerekir (`xcode-select --install`).

```bash
./build.sh
open build/Ada-X.app
```

## Windows

[`windows`](windows) klasöründe daha basit bir sürüm var (sadece medya kısayolları ve ayar penceresi).
İki dosyayı aynı klasöre koy, **BASLAT.bat**'a çift tıkla. Kurulum gerekmez.
