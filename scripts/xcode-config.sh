#!/usr/bin/env bash
# Xcode から直接ビルド/Run する前に 1 回実行する（特に `flutter clean` の後）。
#
# 課題: dart-define（API_BASE_URL 等）は ios/Flutter/Generated.xcconfig に
#       「最後に実行した flutter コマンドの値」で焼かれる。別の flutter コマンドや
#       flutter clean を挟むと既定（http://localhost:8787）に戻り、実機から到達できず
#       画像取得が失敗する（IAP は StoreKit なので影響なし）。
#
# このスクリプトは config/dev.json の dart-define を Generated.xcconfig に確実に
# 焼き込み、その後 Xcode で Run しても API_BASE_URL 等が反映されるようにする。
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-config/dev.json}"
if [ ! -f "$CONFIG" ]; then
  echo "❌ $CONFIG が見つかりません。config/dev.json.example をコピーして母艦の LAN IP を設定してください。" >&2
  exit 1
fi
flutter build ios --config-only --dart-define-from-file="${CONFIG}"
echo "✅ dart-define を Xcode 用に設定しました（${CONFIG}）。Xcode で Runner を Run できます。"
