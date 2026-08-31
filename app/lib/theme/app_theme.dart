import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const background = Color(0xFFF7F5F0);
  static const darkBackground = Color(0xFF151A18);
  static const primary = Color(0xFF496A5A);
  static const darkPrimary = Color(0xFFA7C7B3);
  static const text = Color(0xFF26342D);
  static const darkText = Color(0xFFEAF0EC);
  static const muted = Color(0xFF69776F);
  static const darkMuted = Color(0xFFB7C3BC);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: text,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: text, height: 1.45),
        bodyMedium: TextStyle(color: muted, height: 1.4),
      ),
      cardTheme: const CardTheme(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: darkPrimary,
      brightness: Brightness.dark,
      surface: const Color(0xFF202722),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: darkPrimary,
        surface: const Color(0xFF202722),
        surfaceContainerHighest: const Color(0xFF2B342E),
        secondary: const Color(0xFFF0BF72),
      ),
      scaffoldBackgroundColor: darkBackground,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: darkText,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: darkText, height: 1.45),
        bodyMedium: TextStyle(color: darkMuted, height: 1.4),
        bodySmall: TextStyle(color: darkMuted, height: 1.35),
      ),
      cardTheme: const CardTheme(
        elevation: 0,
        color: Color(0xFF202722),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF102018),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: darkPrimary),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF2B342E),
        contentTextStyle: TextStyle(color: darkText),
      ),
    );
  }

  static SystemUiOverlayStyle systemOverlayStyle(ThemeMode mode) {
    final isDark = mode == ThemeMode.dark;
    return (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: isDark ? darkBackground : background,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}

class StudySisSubjectTheme {
  const StudySisSubjectTheme({
    required this.primary,
    required this.onPrimary,
    required this.soft,
    required this.darkPrimary,
    required this.darkSoft,
  });

  final Color primary;
  final Color onPrimary;
  final Color soft;
  final Color darkPrimary;
  final Color darkSoft;

  Color accent(BuildContext context) {
    return Theme.of(context).colorScheme.brightness == Brightness.dark
        ? darkPrimary
        : primary;
  }

  Color softSurface(BuildContext context) {
    return Theme.of(context).colorScheme.brightness == Brightness.dark
        ? darkSoft
        : soft;
  }

  static const mathematics = StudySisSubjectTheme(
    primary: Color(0xFF2F8F6B),
    onPrimary: Colors.white,
    soft: Color(0xFFDDF3E8),
    darkPrimary: Color(0xFF7ED2A8),
    darkSoft: Color(0xFF1F3D32),
  );

  static const science = StudySisSubjectTheme(
    primary: Color(0xFF3E8EC9),
    onPrimary: Colors.white,
    soft: Color(0xFFDFEFFA),
    darkPrimary: Color(0xFF86C6F0),
    darkSoft: Color(0xFF20384A),
  );

  static const bahasaMelayu = StudySisSubjectTheme(
    primary: Color(0xFFE28A45),
    onPrimary: Colors.white,
    soft: Color(0xFFFCE9D7),
    darkPrimary: Color(0xFFFFB878),
    darkSoft: Color(0xFF4A3324),
  );

  static const english = StudySisSubjectTheme(
    primary: Color(0xFF8067C7),
    onPrimary: Colors.white,
    soft: Color(0xFFEEE8FA),
    darkPrimary: Color(0xFFBBA8F3),
    darkSoft: Color(0xFF332A4E),
  );

  static const sejarah = StudySisSubjectTheme(
    primary: Color(0xFFC96E5D),
    onPrimary: Colors.white,
    soft: Color(0xFFF7E4DF),
    darkPrimary: Color(0xFFEAA08F),
    darkSoft: Color(0xFF4A2D29),
  );

  static const geography = StudySisSubjectTheme(
    primary: Color(0xFF39998E),
    onPrimary: Colors.white,
    soft: Color(0xFFDCF2EF),
    darkPrimary: Color(0xFF7BD7CC),
    darkSoft: Color(0xFF1E3F3B),
  );

  static const rekaBentukTeknologi = StudySisSubjectTheme(
    primary: Color(0xFFD49A32),
    onPrimary: Color(0xFF2B2210),
    soft: Color(0xFFFAEED2),
    darkPrimary: Color(0xFFECC66A),
    darkSoft: Color(0xFF443719),
  );

  static StudySisSubjectTheme forSubject({
    required String id,
    String? displayName,
    String? iconName,
    String? fallbackHex,
  }) {
    final key = [
      id,
      displayName ?? '',
      iconName ?? '',
    ].join(' ').toLowerCase();
    if (key.contains('science') || key.contains('sains')) return science;
    if (key.contains('bahasa') || key.contains('melayu')) {
      return bahasaMelayu;
    }
    if (key.contains('english')) return english;
    if (key.contains('sejarah') || key.contains('history')) return sejarah;
    if (key.contains('geography') || key.contains('geografi')) {
      return geography;
    }
    if (key.contains('reka') ||
        key.contains('teknologi') ||
        key.contains('rbt') ||
        key.contains('computer')) {
      return rekaBentukTeknologi;
    }
    if (key.contains('math') || key.contains('mathematics')) {
      return mathematics;
    }
    final fallback = _parseHex(fallbackHex);
    if (fallback != null) {
      return StudySisSubjectTheme(
        primary: fallback,
        onPrimary: Colors.white,
        soft: fallback.withValues(alpha: 0.14),
        darkPrimary: Color.lerp(fallback, Colors.white, 0.28) ?? fallback,
        darkSoft: Color.lerp(fallback, Colors.black, 0.68) ?? fallback,
      );
    }
    return mathematics;
  }

  static Color? _parseHex(String? value) {
    if (value == null) return null;
    final hex = value.replaceAll('#', '');
    final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}

class StudySisColors {
  const StudySisColors._();

  static const streak = Color(0xFFE26D3D);
  static const streakSoft = Color(0xFFFFE8DC);
  static const streakDark = Color(0xFFFFA27D);
  static const streakDarkSoft = Color(0xFF4B2B22);

  static const muffin = Color(0xFFA45E37);
  static const muffinSoft = Color(0xFFFFEAD8);
  static const muffinDark = Color(0xFFE6A071);
  static const muffinDarkSoft = Color(0xFF463022);

  static const xp = Color(0xFFD49A32);
  static const xpSoft = Color(0xFFFFF0CF);
  static const xpDark = Color(0xFFECC66A);
  static const xpDarkSoft = Color(0xFF443719);

  static const studyPet = Color(0xFF8067C7);
  static const studyPetSoft = Color(0xFFF0E9FF);
  static const studyPetDark = Color(0xFFBBA8F3);
  static const studyPetDarkSoft = Color(0xFF332A4E);

  static const progress = Color(0xFF39998E);
  static const progressSoft = Color(0xFFDCF2EF);
  static const progressDark = Color(0xFF7BD7CC);
  static const progressDarkSoft = Color(0xFF1E3F3B);

  static bool isDark(BuildContext context) {
    return Theme.of(context).colorScheme.brightness == Brightness.dark;
  }

  static Color streakAccent(BuildContext context) {
    return isDark(context) ? streakDark : streak;
  }

  static Color streakSurface(BuildContext context) {
    return isDark(context) ? streakDarkSoft : streakSoft;
  }

  static Color muffinAccent(BuildContext context) {
    return isDark(context) ? muffinDark : muffin;
  }

  static Color muffinSurface(BuildContext context) {
    return isDark(context) ? muffinDarkSoft : muffinSoft;
  }

  static Color xpAccent(BuildContext context) {
    return isDark(context) ? xpDark : xp;
  }

  static Color xpSurface(BuildContext context) {
    return isDark(context) ? xpDarkSoft : xpSoft;
  }

  static Color studyPetAccent(BuildContext context) {
    return isDark(context) ? studyPetDark : studyPet;
  }

  static Color studyPetSurface(BuildContext context) {
    return isDark(context) ? studyPetDarkSoft : studyPetSoft;
  }

  static Color progressAccent(BuildContext context) {
    return isDark(context) ? progressDark : progress;
  }

  static Color progressSurface(BuildContext context) {
    return isDark(context) ? progressDarkSoft : progressSoft;
  }
}

class StudySisDecorations {
  const StudySisDecorations._();

  static LinearGradient softSubjectGradient(
    BuildContext context,
    StudySisSubjectTheme subject,
  ) {
    final base = subject.softSurface(context);
    final surface = Theme.of(context).colorScheme.surface;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        base,
        Color.lerp(base, surface, 0.58) ?? surface,
      ],
    );
  }

  static BoxDecoration playfulCard(
    BuildContext context,
    StudySisSubjectTheme subject, {
    double radius = 24,
  }) {
    return BoxDecoration(
      gradient: softSubjectGradient(context, subject),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: subject.accent(context).withValues(alpha: 0.14),
      ),
    );
  }

  static BoxDecoration softAccentSurface(
    BuildContext context, {
    required Color accent,
    required Color surface,
    double radius = 18,
  }) {
    final base = Theme.of(context).colorScheme.surface;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surface,
          Color.lerp(surface, base, 0.52) ?? base,
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.12)),
    );
  }
}
