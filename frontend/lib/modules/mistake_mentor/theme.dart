import 'package:flutter/material.dart';

class AppTheme {
  // ==========================================
  // 1. 暖色护眼亮色主题 (Solarized Cream & Green)
  // ==========================================
  static ThemeData lightEyeCare() {
    final primaryColor = Colors.teal[800]!; // 沉静稳定的茶绿色，对眼睛极好
    const scaffoldColor = Color(0xFFFDF6E3); // 经典的 Solarized Base3 (米黄色)
    const cardColor = Color(0xFFF5E4C3);    // 略深一号的暖色底卡片

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: scaffoldColor,
      cardColor: cardColor,
      primaryColor: primaryColor,
      dividerColor: Colors.brown[200],
      dialogBackgroundColor: scaffoldColor,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        background: scaffoldColor,
        surface: cardColor,
        primary: primaryColor,
        secondary: Colors.brown[600]!, // 辅助色：红褐/咖色
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFE9DDBF), // 稍微融合的纸页 AppBar 顶栏
        foregroundColor: const Color(0xFF3C3836), // 暖度适中的灰黑色字
        elevation: 0,
        centerTitle: true,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFFE9DDBF),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.brown[400],
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: const Color(0xFFFDF6E3), // 浮动按钮文字使用米白
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF3C3836)),
        bodyMedium: TextStyle(color: Color(0xFF3C3836)),
        titleLarge: TextStyle(color: Color(0xFF3C3836), fontWeight: FontWeight.bold),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0D4B8),
        thickness: 0.8,
      ),
    );
  }

  // ==========================================
  // 2. 暖色护眼暗色主题 (Warm Dark Grid)
  // ==========================================
  static ThemeData darkEyeCare() {
    final primaryColor = Colors.teal[300]!; // 暗色下主色亮调
    const scaffoldColor = Color(0xFF191B19); // 温暖暗黑（带有一丝极光绿调，缓解疲劳）
    const cardColor = Color(0xFF232822);    // 深茶色卡片

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: scaffoldColor,
      cardColor: cardColor,
      primaryColor: primaryColor,
      dividerColor: Colors.white10,
      dialogBackgroundColor: const Color(0xFF222822),

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        background: scaffoldColor,
        surface: cardColor,
        primary: primaryColor,
        secondary: Colors.amber[600]!, // 黄金辅助色
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF151815),
        foregroundColor: Color(0xFFE0E5DF),
        elevation: 0,
        centerTitle: true,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF151815),
        selectedItemColor: primaryColor,
        unselectedItemColor: const Color(0xFF8B958A),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: const Color(0xFF191B19),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFE0E5DF)),
        bodyMedium: TextStyle(color: Color(0xFFE0E5DF)),
        titleLarge: TextStyle(color: Color(0xFFE0E5DF), fontWeight: FontWeight.bold),
      ),

      dividerTheme: const DividerThemeData(
        color: Colors.white12,
        thickness: 0.8,
      ),
    );
  }
}
