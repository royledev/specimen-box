# prototype — 標本生成プレビュー

正典の生成エンジン（`lib/domain/generation/`）を使い、サンプル回答から標本PNGを
書き出して**目視確認**するためのもの。Flutter UI を起動せず pure Dart で動く。

## 実行
```sh
dart run tool/preview.dart
# 出力: prototype/out/specimen_*.png
```
（`dart` は `~/development/flutter/bin` 配下。`~/.zshrc` でPATHに追加済み。）

## 確認できること
- **決定論**: 同じ (回答, 問いID, 日付, salt) → 同じseed → 同じ標本（`specimen_01` と `_07` は一致）。
- **回答依存**: 同じ問いでも回答が違えば別の標本（`_08`）。
- パラメータ（hue/lobes/rings/scale）は実行ログに出る。

## 注意
- このプレビューのラスタライザは `lib/domain/generation/raster_renderer.dart`（Flutter非依存）。
  アプリ実機の描画は `lib/presentation/widgets/specimen_painter.dart`（Flutter Canvas）で、
  **同じ SpecimenParams** を使う。両者のアルゴリズム同期は今後ゴールデンテストで担保する。
- 生成ロジックは `generator_v1`。見た目を変える時は v2 を追加し、既存標本は v1 のまま保つ
  （= 一点物の保証 / 設計概要 §1.5）。
