# Ada-X ✦

**English** · [Türkçe](README.tr.md)

A sleek panel that drops down from your MacBook's notch: music controls, weather, currency rates, calendar,
prayer times, a timer and more. You pick what you use on first launch; everything else stays hidden.

> The app's interface is in Turkish.

## Install (Mac)

Paste this into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/EnessKucukk/ada-x/main/install.sh | bash
```

On first launch a setup screen appears:
1. **What will you use?** Pick the features you want.
2. **Permissions:** Only the permissions your chosen features need, each with a short note on why it's needed.

Your personal data is never sent anywhere.

## Usage

| | |
|---|---|
| Open / close the panel | **Double-press ⌘ Command**, hover over the notch, or click ♪ in the menu bar |
| Play / pause | **Double-press ⌥ Option** |
| Volume up / down | **⌃⌥ ↑ / ↓**, or scroll over the notch |
| Brightness | Hold **⇧ Shift** and scroll over the notch |
| Next / previous track | **⌃⌥ → / ←** |
| Mute | **⌃⌥ M** |

All shortcuts can be changed in **Ayarlar → Kısayollar** (Settings → Shortcuts).
To change which features are shown: **Ayarlar → Genel → Kullandığım özellikler**.

## Features

- **Music:** now playing from Spotify / Apple Music with artwork and progress; a live indicator next to the notch
- **Info:** weather, currency and gold, football scores, calendar, reminders, prayer times, earthquakes (AFAD), news, world clocks, mail
- **Tools:** file shelf, clipboard history, quick note, calculator and currency converter, timer, screenshots, mirror, system stats
- **Notch notifications:** volume, brightness, charging, AirPods battery when connected, major earthquake alerts
- **Keep awake:** one click keeps your Mac from sleeping

## Where does the data come from?

The app has no server of its own, collects no usage statistics and needs no account.
Online information comes from free, public sources and is fetched **directly from your Mac**.
Only the sources for features you've enabled are contacted.

**From the internet**

| Feature | Source | What is sent |
|---|---|---|
| Weather | [Open-Meteo](https://open-meteo.com) | The city name you type and its coordinates |
| Prayer times | [Aladhan](https://aladhan.com) (Diyanet calculation method) | The city's coordinates |
| Currency (USD, EUR, GBP) | [ExchangeRate-API](https://www.exchangerate-api.com) open rates | Nothing, just the request |
| Gold (per gram), bitcoin | [CoinGecko](https://www.coingecko.com) | Nothing. Gram gold is derived from the ounce price (PAX Gold) and is approximate |
| Football scores | ESPN's public score data (not an official service) | The league you pick |
| Earthquakes | [AFAD](https://deprem.afad.gov.tr) | The date range for the last 48 hours |
| News | BBC Türkçe, NTV, TRT Haber, Anadolu Ajansı RSS | Nothing, just the request |

**From your Mac (never leaves it)**

| Feature | Read from |
|---|---|
| Now playing | Spotify / Music app |
| Calendar, reminders | Calendar and Reminders on your Mac |
| Mail | The Mail app (sender and subject only, message content is never read) |
| System, battery, AirPods | macOS |
| Screenshots | Desktop (screenshot files only) |
| Mirror | Camera (nothing is recorded) |

**Stored on your Mac**
Your settings, quick note and file shelf list are stored only on this Mac.
Clipboard history is never saved; it lives in memory only while the app is running. Copies from password managers are skipped.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/EnessKucukk/ada-x/main/install.sh | bash -s -- kaldir
```

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh
open build/Ada-X.app
```

## Windows

The [`windows`](windows) folder contains a simpler version (media shortcuts and a settings window only).
Put both files in the same folder and double-click **BASLAT.bat**. Nothing to install.
