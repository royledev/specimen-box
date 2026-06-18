// 1日に掘れる化石の上限（取得回数キャップ）。
//
// 「1日3回」は通知本数 [kNotificationsPerDay] が正本（ADR-0018: 1日3通知＝最大3化石）。
// 取得上限もこれと同一値を使い、ズレないようにする。
//
// カウントは「その日付（YYYY-MM-DD）の化石数」を真実の源とする（別カウンタは持たない）。
library;

import 'package:specimen_box/domain/notification/notify_time.dart'
    show kNotificationsPerDay;
import 'package:specimen_box/domain/specimen/specimen.dart';

/// 1日に掘れる化石の上限（= 1日の通知本数）。
const int kDailyDigLimit = kNotificationsPerDay;

/// [ymd]（'YYYY-MM-DD'）に掘った化石の数。
int digsOnDate(Iterable<Specimen> specimens, String ymd) =>
    specimens.where((s) => s.date == ymd).length;

/// [ymd] にまだ掘れるか（上限未満か）。
bool canDigOnDate(
  Iterable<Specimen> specimens,
  String ymd, {
  int limit = kDailyDigLimit,
}) =>
    digsOnDate(specimens, ymd) < limit;
