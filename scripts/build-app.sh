#!/bin/bash
# Compila em release e monta build/Turma.app (sem ícone no Dock), assinado ad-hoc.
# O diretório de build do SwiftPM fica fora do projeto (a pasta pode estar no iCloud).
set -euo pipefail

cd "$(dirname "$0")/.."
SCRATCH="${TURMA_SCRATCH:-$HOME/.cache/turma-build}"
# Monta e assina fora do projeto: na pasta do iCloud, a File Provider marca toda pasta .app com
# com.apple.FinderInfo na hora, e o codesign recusa ("Finder information ... detritus not allowed").
STAGE="$SCRATCH/app-stage"
APP="$STAGE/Turma.app"
OUT="build/Turma.app"
VERSION="0.1.0"

swift build -c release --scratch-path "$SCRATCH"
BIN="$(swift build -c release --scratch-path "$SCRATCH" --show-bin-path)"
RESOURCES="$BIN/turma-do-dia_Turma.bundle"

[ -x "$BIN/Turma" ] || { echo "Executável não encontrado em $BIN" >&2; exit 1; }
[ -d "$RESOURCES" ] || { echo "Bundle de recursos não encontrado em $RESOURCES" >&2; exit 1; }

rm -rf "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto --noextattr --norsrc "$BIN/Turma" "$APP/Contents/MacOS/Turma"
# Bundle.module procura primeiro em Bundle.main.resourceURL, ou seja, Contents/Resources.
ditto --noextattr --norsrc "$RESOURCES" "$APP/Contents/Resources/$(basename "$RESOURCES")"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt-BR</string>
    <key>CFBundleExecutable</key>
    <string>Turma</string>
    <key>CFBundleIdentifier</key>
    <string>br.com.daviaieta.turma</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Turma</string>
    <key>CFBundleDisplayName</key>
    <string>Turma do Dia</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP"
codesign --verify --deep --strict "$APP"

# Copia o .app assinado para build/. Lá o iCloud volta a pôr o FinderInfo, o que só faz o modo
# --strict reclamar; a assinatura em si continua íntegra (conferida abaixo sem --strict).
rm -rf "$OUT"
mkdir -p build
ditto "$APP" "$OUT"
codesign --verify --deep "$OUT"

echo "$(pwd)/$OUT"
