// ============================================================
//  main.dart — Point d'entrée de l'application Bongolava AI
//  Auteur du projet : RATAHINJANAHARY Ruphin Henri (ENI Fianarantsoa)
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ⚠️ Généré par `flutterfire configure` — relie ce projet à Firebase
import 'bongolava_chat_page.dart';

/// Couleurs officielles du drapeau de Madagascar (utilisées comme accents,
/// pas comme fond — l'interface générale reste neutre et moderne, style Gemini)
const Color kMadaRed   = Color(0xFFCC0000);
const Color kMadaWhite = Color(0xFFFFFFFF);
const Color kMadaGreen = Color(0xFF0E9F6E);

/// Dégradé "signature" de l'IA Bongolava (remplace le vert plein d'origine)
const List<Color> kBrandGradient = [Color(0xFF0E9F6E), Color(0xFFCC0000)];

/// Fond neutre façon Gemini (gris très clair, presque blanc)
const Color kSurface     = Color(0xFFF7F8FA);
const Color kSurfaceDark = Color(0xFF131314);

void main() async {
  // Assure que les widgets Flutter sont prêts avant d'appeler Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialisation Firebase liée à CE projet précis ────────────────
  // DefaultFirebaseOptions.currentPlatform vient de firebase_options.dart,
  // le fichier généré par la CLI FlutterFire pour le projet "Bongolava-Guide-IA".
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BongolavaApp());
}

/// Widget racine de l'application
class BongolavaApp extends StatelessWidget {
  const BongolavaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bongolava AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // ── Thème clair, neutre et moderne (inspiration Gemini) ──────────
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kSurface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kMadaGreen,
          brightness: Brightness.light,
          primary: kMadaGreen,
          secondary: kMadaRed,
          surface: kMadaWhite,
        ),
        fontFamily: 'Roboto',

        appBarTheme: const AppBarTheme(
          backgroundColor: kSurface,
          foregroundColor: Color(0xFF1A1A1A),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kMadaWhite,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
      ),

      // ── Thème sombre, façon Gemini dark mode ──────────────────────────
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kSurfaceDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kMadaGreen,
          brightness: Brightness.dark,
          primary: const Color(0xFF6FDCB0),
          secondary: const Color(0xFFFF8A80),
          surface: const Color(0xFF1E1F20),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: kSurfaceDark,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1F20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
      ),

      home: const BongolavaChat(),
    );
  }
}
