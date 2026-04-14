import 'package:flutter/material.dart';

bool _hasStrongRtlChar(String text) {
  for (final codeUnit in text.runes) {
    if ((codeUnit >= 0x0600 && codeUnit <= 0x06FF) ||
        (codeUnit >= 0x0750 && codeUnit <= 0x077F) ||
        (codeUnit >= 0x08A0 && codeUnit <= 0x08FF) ||
        (codeUnit >= 0xFB50 && codeUnit <= 0xFDFF) ||
        (codeUnit >= 0xFE70 && codeUnit <= 0xFEFF)) {
      return true;
    }
  }
  return false;
}

TextDirection directionForMixedText(String text) {
  if (text.isEmpty) return TextDirection.ltr;
  return _hasStrongRtlChar(text) ? TextDirection.rtl : TextDirection.ltr;
}
