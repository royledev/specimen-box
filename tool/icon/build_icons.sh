#!/usr/bin/env bash
# 化石箱アイコン: 1024 マスター PNG から各プラットフォームのサイズを生成・配置する。
# マスター: assets/icon/app_icon_1024.png（透過なし＝App Store のアルファ無し要件を満たす）
# 依存: sips（macOS 標準）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MASTER="$ROOT/assets/icon/app_icon_1024.png"

emit() { # <px> <out>
  sips -z "$1" "$1" "$MASTER" --out "$2" >/dev/null
}

echo "1) iOS AppIcon"
IOS="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
emit 20   "$IOS/Icon-App-20x20@1x.png"
emit 40   "$IOS/Icon-App-20x20@2x.png"
emit 60   "$IOS/Icon-App-20x20@3x.png"
emit 29   "$IOS/Icon-App-29x29@1x.png"
emit 58   "$IOS/Icon-App-29x29@2x.png"
emit 87   "$IOS/Icon-App-29x29@3x.png"
emit 40   "$IOS/Icon-App-40x40@1x.png"
emit 80   "$IOS/Icon-App-40x40@2x.png"
emit 120  "$IOS/Icon-App-40x40@3x.png"
emit 120  "$IOS/Icon-App-60x60@2x.png"
emit 180  "$IOS/Icon-App-60x60@3x.png"
emit 76   "$IOS/Icon-App-76x76@1x.png"
emit 152  "$IOS/Icon-App-76x76@2x.png"
emit 167  "$IOS/Icon-App-83.5x83.5@2x.png"
cp "$MASTER" "$IOS/Icon-App-1024x1024@1x.png"

echo "2) macOS AppIcon"
MAC="$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
for s in 16 32 64 128 256 512; do emit "$s" "$MAC/app_icon_${s}.png"; done
cp "$MASTER" "$MAC/app_icon_1024.png"

echo "3) web icons"
WEB="$ROOT/web"
emit 192 "$WEB/icons/Icon-192.png"
emit 512 "$WEB/icons/Icon-512.png"
emit 192 "$WEB/icons/Icon-maskable-192.png"
emit 512 "$WEB/icons/Icon-maskable-512.png"
emit 16  "$WEB/favicon.png"

echo "完了"
