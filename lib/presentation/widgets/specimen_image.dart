// 標本のローカル画像表示（ADR-0011 決定4/8）。
//
// `local_path` のバイトを [ImageStore] 経由で読み、`Image.memory` で表示する。
// - 未取得（local_path == null / deferred）や読み取り失敗時は**プレースホルダ**を出す。
// - [weather]（経年劣化 0..1・封印は 0）に応じて**退色オーバーレイ**を掛ける
//   （ベクター描画時代の weathering を画像に最小移植。封印標本は退色しない＝永久保存の意味を維持）。
//
// 旧 `SpecimenPainter`（ベクター）の置き換え。
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:specimen_box/presentation/providers/providers.dart';

/// 経年劣化レベル [w]（0..1）に対応する退色 ColorFilter を返す。
///
/// w が大きいほど彩度を落とし、わずかに暗くする（古びる表現）。w=0 は素通し（identity）。
ColorFilter weatherColorFilter(double w) {
  final t = w.clamp(0.0, 1.0);
  // 彩度を最大 70% まで落とす。
  final sat = 1.0 - 0.7 * t;
  // 明度を最大 20% 落とす。
  final b = 1.0 - 0.2 * t;
  // 輝度係数（Rec.709）。
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  double m(double base, double lum) => (base * sat + lum * (1 - sat)) * b;
  return ColorFilter.matrix(<double>[
    m(1, lr), m(0, lg), m(0, lb), 0, 0, //
    m(0, lr), m(1, lg), m(0, lb), 0, 0, //
    m(0, lr), m(0, lg), m(1, lb), 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// 標本のローカル画像を表示するウィジェット。
class SpecimenImage extends ConsumerStatefulWidget {
  const SpecimenImage({
    super.key,
    required this.localPath,
    this.weather = 0.0,
    this.fit = BoxFit.cover,
  });

  /// 端末ローカルの保存先パス。null は未取得（deferred）。
  final String? localPath;

  /// 経年劣化レベル（0..1）。封印標本は 0（呼び出し側で算出）。
  final double weather;

  final BoxFit fit;

  @override
  ConsumerState<SpecimenImage> createState() => _SpecimenImageState();
}

class _SpecimenImageState extends ConsumerState<SpecimenImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SpecimenImage old) {
    super.didUpdateWidget(old);
    if (old.localPath != widget.localPath) _load();
  }

  Future<void> _load() async {
    final path = widget.localPath;
    if (path == null) {
      setState(() {
        _bytes = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    List<int>? raw;
    try {
      raw = await ref.read(imageStoreProvider).read(path);
    } catch (_) {
      // 読み取り経路の異常（path_provider 未初期化等）でもスピナーで固まらないよう
      // プレースホルダ（_bytes=null）に落とす。
      raw = null;
    }
    if (!mounted) return;
    setState(() {
      _bytes = raw == null ? null : Uint8List.fromList(raw);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return _SpecimenPlaceholder(
        loading: _loading && widget.localPath != null,
      );
    }
    Widget image = Image.memory(bytes, fit: widget.fit, gaplessPlayback: true);
    if (widget.weather > 0) {
      image = ColorFiltered(
        colorFilter: weatherColorFilter(widget.weather),
        child: image,
      );
    }
    return image;
  }
}

/// 未取得（deferred）/ 読み取り失敗時のプレースホルダ。
class _SpecimenPlaceholder extends StatelessWidget {
  const _SpecimenPlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1E4CC), // 発掘前の土の色（アースポップ）
      child: Center(
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFFC8A24A),
                ),
              )
            : const Icon(
                Icons.hourglass_empty,
                size: 18,
                color: Color(0xFFC3B29C),
              ),
      ),
    );
  }
}
