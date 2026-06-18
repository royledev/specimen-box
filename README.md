# specimen_box（化石箱）

「化石箱」アプリ（Flutter / iOS first）。アプリ内の表示語彙は「化石」、コード語彙は「標本（specimen）」。

## ローカル実機テスト（画像取得 ＋ 課金 を同時に動かす）

実機（iPhone）でサーバ配信の**画像取得**と**課金（IAP sandbox）**の両方を動かすには、
クライアントの dart-define とサーバのローカル設定の両方を合わせる必要がある。

### 1. dart-define（クライアント）

API 接続先などは `--dart-define` で渡す（`lib/platform/api/api_config.dart`）。値は
`config/dev.json`（`config/dev.json.example` をコピーして母艦の LAN IP を設定）に集約する。

- **母艦の LAN IP を確認**: `ipconfig getifaddr en0`
- `config/dev.json` の `API_BASE_URL` を `http://<母艦のLAN IP>:8787` に設定する。

> ⚠️ `API_BASE_URL` を渡さないと既定 `http://localhost:8787` になり、実機からは到達できず
> 画像取得が失敗する（IAP は StoreKit なので影響を受けない）。

### 2-A. Xcode から Run する（推奨・画像も課金も動く）

課金はローカルの **StoreKit Configuration（`ios/Configuration.storekit`、Runner スキームが参照）** で
テストする。このローカル StoreKit は **Xcode から Run したときだけ適用**される（商品が解決される）。

1. dart-define を Generated.xcconfig に焼き込む（画像用。`flutter clean` の後は必須）:
   ```sh
   ./scripts/xcode-config.sh   # = flutter build ios --config-only --dart-define-from-file=config/dev.json
   ```
2. `ios/Runner.xcworkspace` を Xcode で開き、Runner スキームで実機/シミュレータに **Run**。
   → 画像（dart-define）も課金（.storekit の3商品）も動く。

### 2-B. `flutter run` の場合（課金は商品が出ない）

```sh
flutter run -d <iPhoneのID> --dart-define-from-file=config/dev.json
```

- 画像は動く（dart-define が渡る）。
- **課金は「現在購入できません」になる**。`flutter run` はスキームの **ローカル StoreKit 設定を適用しない**ため、
  `queryProductDetails` が空になる（バグではなく仕様）。課金を試すなら **2-A の Xcode Run** を使う。
  （`flutter run` で課金を出すには、App Store Connect に審査前でも商品を登録し Sandbox テスターで動かす必要がある。）

### 3. サーバ（specimen-box-server）をLANに公開する

実機がローカルのワーカーに到達でき、かつ返ってくる画像URLも到達可能である必要がある。

- **LAN 公開で起動**: `npm run dev:lan`（= `wrangler dev --ip 0.0.0.0`）。既定の `npm run dev` は
  localhost のみで実機から到達できない。
- **`.dev.vars` の `IMAGE_CDN_BASE`** を `http://<母艦のLAN IP>:8787/dev/img` にする
  （`localhost` のままだと `images/draw` は成功しても、返る画像URLを実機がDLできず失敗する）。

### チェックリスト（実機で画像が出ないとき）

1. `config/dev.json` の `API_BASE_URL` が母艦の LAN IP になっているか。
2. Xcode 直接ビルドなら `./scripts/xcode-config.sh` を実行したか。
3. サーバを `npm run dev:lan` で起動したか（LAN 公開）。
4. サーバ `.dev.vars` の `IMAGE_CDN_BASE` が LAN IP になっているか。
5. iPhone と母艦が同じ Wi-Fi か。（ATS は `NSAllowsLocalNetworking` で私的IPのHTTPを許可済み）

### 課金が「現在購入できません」と出るとき

`flutter run` で起動していないか確認する。ローカル StoreKit は **Xcode から Run** したときだけ商品が出る
（→ 2-A）。商品IDは `ios/Configuration.storekit` と `lib/platform/purchase/purchase_service.dart` で一致済み。
