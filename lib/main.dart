import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'services/chat_service.dart';
import 'screens/nickname_screen.dart';
import 'theme/retro.dart';

/// The app draws its own Macintosh title bar inside the client area, but the
/// native one is left in place: on some Wayland compositors a hidden title
/// bar plus custom drag can leave the window unmovable, which is far too high
/// a price for chrome. Flip this to true to try the real frameless look —
/// the in-app title bar is already there either way.
const bool _kFrameless = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'LanChat',
        size: Size(680, 520),
        minimumSize: Size(440, 420),
        center: true,
        titleBarStyle:
            _kFrameless ? TitleBarStyle.hidden : TitleBarStyle.normal,
        backgroundColor: Retro.bg,
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
    const square = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Retro.rule),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: Retro.mono,
      fontFamilyFallback: Retro.monoFallback,
      colorScheme: const ColorScheme.dark(
        surface: Retro.bg,
        primary: Retro.accent,
        secondary: Retro.accent,
        onSurface: Retro.ink,
        onPrimary: Retro.bg,
        surfaceContainerHighest: Retro.panel,
        outline: Retro.rule,
      ),
      scaffoldBackgroundColor: Retro.bg,
      dividerTheme: const DividerThemeData(
        color: Retro.ruleDim,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Retro.accent,
        selectionColor: Retro.accentDim,
        selectionHandleColor: Retro.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Retro.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: square,
        enabledBorder: square,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Retro.accent),
        ),
        hintStyle: Retro.text(size: 13, color: Retro.inkFaint),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: Retro.panelHi,
          border: Retro.box,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        textStyle: Retro.text(size: 10, color: Retro.ink, spacing: 1),
        waitDuration: const Duration(milliseconds: 450),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Retro.panelHi,
        contentTextStyle: Retro.text(size: 12, color: Retro.ink),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        behavior: SnackBarBehavior.fixed,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6.0),
        radius: Radius.zero,
        thumbColor: WidgetStateProperty.all(Retro.rule),
      ),
    );
  }
}
