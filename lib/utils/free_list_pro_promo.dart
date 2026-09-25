/// Free-DJ: genau eine Pro-Werbung ungefähr in der Listenmitte
/// (nicht mehr alle 5 Songs).
class FreeListProPromo {
  FreeListProPromo._();

  /// Listen-Index der Werbung, oder `-1` wenn keine.
  static int promoIndex(int dataLen, {required bool isFree}) {
    if (!isFree || dataLen <= 0) return -1;
    // 1 Song → nach dem Song; sonst bei dataLen ~/ 2.
    return dataLen == 1 ? 1 : dataLen ~/ 2;
  }

  static int itemCount(int dataLen, {required bool isFree}) {
    if (!isFree || dataLen <= 0) return dataLen;
    return dataLen + 1;
  }

  static bool isPromoIndex(int listIndex, int dataLen, {required bool isFree}) {
    final at = promoIndex(dataLen, isFree: isFree);
    return at >= 0 && listIndex == at;
  }

  static int dataIndex(int listIndex, int dataLen, {required bool isFree}) {
    final at = promoIndex(dataLen, isFree: isFree);
    if (at < 0 || listIndex < at) return listIndex;
    return listIndex - 1;
  }
}
