#!/bin/bash
# Ada-X kurulum:
#   curl -fsSL https://raw.githubusercontent.com/EnessKucukk/ada-x/main/install.sh | bash
# Kaldırma:
#   curl -fsSL https://raw.githubusercontent.com/EnessKucukk/ada-x/main/install.sh | bash -s -- kaldir
set -euo pipefail

REPO="EnessKucukk/ada-x"
URL="https://github.com/$REPO/releases/latest/download/Ada-X.zip"
KIMLIK="com.enesskucukk.adax"
AJAN="$HOME/Library/LaunchAgents/$KIMLIK.plist"

HEDEF="/Applications"
[ -w "$HEDEF" ] || HEDEF="$HOME/Applications"
UYGULAMA="$HEDEF/Ada-X.app"

pkill -x Ada-X 2>/dev/null || true

# Eski adıyla (Medya Tuşları) kurulduysa onu temizle
pkill -x MedyaTuslari 2>/dev/null || true
rm -rf "/Applications/MedyaTuslari.app" "$HOME/Applications/MedyaTuslari.app" \
       "$HOME/Library/LaunchAgents/com.medyatuslari.app.plist"

if [ "${1:-}" = "kaldir" ]; then
  rm -rf "/Applications/Ada-X.app" "$HOME/Applications/Ada-X.app" "$AJAN"
  defaults delete "$KIMLIK" 2>/dev/null || true
  echo "Ada-X kaldırıldı."
  echo "İstersen Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik listesinden de silebilirsin."
  exit 0
fi

GECICI="$(mktemp -d)"
trap 'rm -rf "$GECICI"' EXIT

echo "İndiriliyor..."
curl -fsSL "$URL" -o "$GECICI/Ada-X.zip"

mkdir -p "$HEDEF"
rm -rf "$UYGULAMA"
ditto -x -k "$GECICI/Ada-X.zip" "$HEDEF"
xattr -dr com.apple.quarantine "$UYGULAMA" 2>/dev/null || true

# Yeni sürümde eski izin çalışmaz; eski kaydı temizle ki yeniden sorsun
tccutil reset Accessibility "$KIMLIK" >/dev/null 2>&1 || true

open "$UYGULAMA"
echo ""
echo "✓ Kuruldu: $UYGULAMA"
echo "  Açılan kurulum ekranında kullanacağın özellikleri seç ve izinleri ver."
