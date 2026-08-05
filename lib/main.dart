import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:provider/provider.dart';
import 'package:mombongo/ui/screens/caissier/caissier_screen.dart';
import 'package:mombongo/ui/screens/caissier/sales_journal_screen.dart';
import 'package:mombongo/ui/screens/gestionnaire_screen.dart';
import 'package:mombongo/ui/screens/admin/admin_screen.dart';
import 'package:mombongo/ui/screens/home_screen.dart';
import 'services/service_locator.dart';
import 'services/cart_service.dart';
import 'ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await locator.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CartService(),
      child: MaterialApp(
      title: 'Mombongo',
      theme: _buildAppTheme(),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false, // Désactiver la bannière par défaut
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginScreen());
          case '/caissier':
            return MaterialPageRoute(builder: (context) => CaissierScreen());
          case '/gestionnaire':
            return MaterialPageRoute(builder: (context) => GestionnaireScreen());
          case '/home':
            return MaterialPageRoute(builder: (context) => const HomeScreen());
          case '/sales-journal':
            return MaterialPageRoute(builder: (context) => SalesJournalScreen());
          default:
            return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
      },
    ));
  }

  ThemeData _buildAppTheme() {
    // Palette de couleurs personnalisée
    const Color primaryColor = Color(0xFF1E0F1C); // Violet foncé
    const Color secondaryColor = Color(0xFF26474E); // Bleu foncé
    const Color accentColor = Color(0xFF18534F); // Vert
    const Color lightBackgroundColor = Color(0xFFFFFFFF); // Blanc clair
    const Color errorColor = Color(0xFF955149); // Terre cuite

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: lightBackgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: primaryColor,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // Give a small delay to ensure auth data is loaded
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Check if user is authenticated
    bool isAuth = locator.authRepository.isAuthenticated;
    
    if (isAuth) {
      // Validate the token
      final isValid = await locator.authRepository.validateSession();
      
      if (!isValid) {
        // Token is invalid or expired, logout the user
        await locator.authRepository.logout();
        isAuth = false;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre session a expiré. Veuillez vous reconnecter.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });
    }
  }

  Widget _getAuthenticatedScreen() {
    final user = locator.authRepository.currentUser;
    
    if (user?.role == 'CAISSIER') {
      return CaissierScreen();
    } else if (user?.role == 'GESTIONNAIRE') {
      return GestionnaireScreen();
    } else if (user?.role == 'ADMINISTRATEUR' || user?.role == 'Administrateur') {
      return AdminScreen();
    } else {
      // Default to login screen for unknown roles
      return const LoginScreen();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    Widget screen = _isAuthenticated 
        ? _getAuthenticatedScreen() 
        : const LoginScreen();
    
    // Ajouter la bannière de développement si on est en mode debug
    if (!kReleaseMode) {
      screen = Stack(
        children: [
          screen,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 24,
              color: const Color(0xFFA7001E), // Couleur rouge de la palette
              child: const Center(
                child: Text(
                  'En mode développement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                  
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    return screen;
  }
}