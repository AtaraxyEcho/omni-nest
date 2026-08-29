import 'package:flutter/foundation.dart';

void readerDebugLog(String message, {int? wrapWidth}) {
  if (kDebugMode) {
    debugPrint(message, wrapWidth: wrapWidth);
  }
}
