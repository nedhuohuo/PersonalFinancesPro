import 'package:flutter/cupertino.dart';

abstract final class AppTheme {
  static const CupertinoThemeData data = CupertinoThemeData(
    primaryColor: CupertinoColors.systemBlue,
    scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    barBackgroundColor: CupertinoColors.systemBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: CupertinoColors.label,
      textStyle: TextStyle(
        color: CupertinoColors.label,
        fontSize: 17,
        letterSpacing: -0.4,
      ),
      actionTextStyle: TextStyle(
        color: CupertinoColors.systemBlue,
        fontSize: 17,
        letterSpacing: -0.4,
      ),
      navLargeTitleTextStyle: TextStyle(
        color: CupertinoColors.label,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      navTitleTextStyle: TextStyle(
        color: CupertinoColors.label,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      tabLabelTextStyle: TextStyle(fontSize: 11, letterSpacing: -0.1),
    ),
  );
}
