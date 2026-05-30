import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'services/chat_service.dart';
import 'screens/nickname_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'LanChat',
        size: Size(820, 640),
        minimumSize: Size(420, 520),
        center: true,
        titleBarStyle: TitleBarStyle.normal,
        backgroundColor: Color(0xFF0A0A0A),
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatService(),
      child: const LanChatApp(),
    ),
  );
}

class LanChatApp extends StatelessWidget {
  const LanChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LanChat',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: _theme(),
      theme: _theme(),
      home: const NicknameScreen(),
    );
  }

  ThemeData _theme() {
    const bg = Color(0xFF0A0A0A);
    const surface = Color(0xFF141414);
    const accent = Color(0xFFE53935);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        surface: bg,
        primary: accent,
        secondary: accent,
        onSurface: Color(0xFFE8E8E8),
        onPrimary: Colors.white,
        surfaceContainerHighest: surface,
        outline: Color(0xFF2A2A2A),
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: Color(0xFFE8E8E8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF555555)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          minimumSize: const Size(double.infinity, 48),
          elevation: 0,
        ),
      ),
    );
  }
}
