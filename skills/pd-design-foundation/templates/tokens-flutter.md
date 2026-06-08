# Skeleton — Flutter tokens file

Path: `lib/design_system/tokens.dart`

```dart
import 'package:flutter/material.dart';

class AppTokens {
  static const colorPrimaryLight   = Color(0xFF2E5BFF);
  static const colorPrimaryDark    = Color(0xFF6B8EFF);
  static const colorOnPrimaryLight = Color(0xFFFFFFFF);
  static const colorOnPrimaryDark  = Color(0xFF0E0F12);

  static const fontBody    = TextStyle(fontSize: 17, height: 24/17, fontWeight: FontWeight.w400);
  static const fontTitle   = TextStyle(fontSize: 22, height: 28/22, fontWeight: FontWeight.w600);
  static const fontCaption = TextStyle(fontSize: 13, height: 18/13);

  static const spaceXs = 4.0, spaceSm = 8.0, spaceMd = 16.0, spaceLg = 24.0;
  static const radiusSm = 8.0, radiusMd = 14.0, radiusLg = 20.0, radiusFull = 999.0;
}

ThemeData appTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: isDark ? AppTokens.colorPrimaryDark : AppTokens.colorPrimaryLight,
      brightness: brightness,
    ),
  );
}
```
