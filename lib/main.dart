import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'bongolava_chat_page.dart';


const Color kMadaRed   = Color(0xFFCC0000);
const Color kMadaWhite = Color(0xFFFFFFFF);
const Color kMadaGreen = Color(0xFF0E9F6E);


const List<Color> kBrandGradient = [Color(0xFF0E9F6E), Color(0xFFCC0000)];


const Color kSurface     = Color(0xFFF7F8FA);
const Color kSurfaceDark = Color(0xFF131314);

void main() async {

  WidgetsFlutterBinding.ensureInitialized();


  String? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stack) {
    startupError = e.toString();
 
    debugPrint('Erreur d\'initialisation Firebase: $e');
    debugPrint('$stack');
  }

  runApp(BongolavaApp(startupError: startupError));
}


class BongolavaApp extends StatelessWidget {
  final String? startupError;
  const BongolavaApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bongolava AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

  
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

      home: SplashScreen(startupError: startupError),
    );
  }
}


/// Écran de démarrage : logo + texte apparaissent en ~1,3s, puis le cercle
/// de chargement reste visible seul encore un peu (~1,7s) avant de basculer
/// vers le chat avec un fondu rapide et fluide.
class SplashScreen extends StatefulWidget {
  final String? startupError;
  const SplashScreen({super.key, this.startupError});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Durée de l'animation d'entrée du logo + texte (fondu, zoom, glissement).
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
  );
  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
  );
  late final Animation<double> _textOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
  );
  late final Animation<Offset> _textSlide = Tween<Offset>(
    begin: const Offset(0, 0.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.45, 1.0, curve: Curves.easeOut)));

  @override
  void initState() {
    super.initState();
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          // Transition rapide et fluide vers le chat (pas de fondu long).
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: widget.startupError != null
                ? _StartupErrorScreen(error: widget.startupError!)
                : const BongolavaChat(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? kSurfaceDark : kSurface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _logoOpacity,
              child: ScaleTransition(
                scale: _logoScale,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kMadaGreen.withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(colors: kBrandGradient).createShader(bounds),
                      child: const Text(
                        'Bongolava AI',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Votre guide du Bongolava, Madagascar',
                      style: TextStyle(
                        fontSize: 13,
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
            FadeTransition(
              opacity: _textOpacity,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: kMadaGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _StartupErrorScreen extends StatelessWidget {
  final String error;
  const _StartupErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: kMadaRed, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Échec du démarrage de l'application",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "L'initialisation de Firebase a échoué. Détail technique "
                "(à copier/envoyer pour le diagnostic) :",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  error,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}