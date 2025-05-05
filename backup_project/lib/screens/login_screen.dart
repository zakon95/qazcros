import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart' as app_colors;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _checkAndNavigate());
  }

  Future<void> _checkAndNavigate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        // Проверяем существование документа пользователя
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        // Если документа нет, создаем его
        if (!docSnapshot.exists) {
          await _saveUserToFirestore(user, user.isAnonymous ? 'anonymous' : 'existing');
        }
        
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при проверке статуса входа: $e')),
        );
      }
    }
  }

  Future<void> _saveUserToFirestore(User user, String provider) async {
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final now = DateTime.now().toUtc().toIso8601String();
      
      // Если пользователь анонимный, генерируем уникальное имя
      String displayName = user.displayName ?? '';
      if (provider == 'anonymous' && (displayName.isEmpty || displayName == 'Аноним')) {
        // Получаем всех пользователей с displayName, начинающимся на 'Ойыншы'
        final query = await users
            .where('displayName', isGreaterThanOrEqualTo: 'Ойыншы')
            .where('displayName', isLessThan: 'Ойыншы\uffff')
            .get();
        int maxNumber = 0;
        for (var doc in query.docs) {
          final name = doc['displayName'] ?? '';
          final match = RegExp(r'Ойыншы(\d+)').firstMatch(name);
          if (match != null) {
            final num = int.tryParse(match.group(1) ?? '0') ?? 0;
            if (num > maxNumber) maxNumber = num;
          }
        }
        displayName = 'Ойыншы${maxNumber + 1}';
        await user.updateDisplayName(displayName);
      }

      final userData = {
        'uid': user.uid,
        'displayName': displayName,
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': user.metadata.creationTime?.toUtc().toIso8601String() ?? now,
        'lastLogin': now,
        'authProvider': provider,
        'hintsCount': 3,
        'score': 0,
        'score_today': 0,
        'score_month': 0,
        'city': 'Астана',
        'avatar': 'assets/avatars/avatar_1.png',
      };
      
      await users.doc(user.uid).set(userData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
      rethrow;
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      await _saveUserToFirestore(cred.user!, 'anonymous');
      _goToHome();
    } catch (e) {
      setState(() { _error = 'Ошибка анонимного входа: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Инициализируем Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Очищаем предыдущую сессию
      await googleSignIn.signOut();
      
      // Запускаем процесс входа
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() { 
          _loading = false;
          _error = 'Вход через Google отменён.';
        });
        return;
      }

      try {
        // Получаем данные аутентификации
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Создаем учетные данные для Firebase
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Входим в Firebase
        final UserCredential userCredential = 
            await FirebaseAuth.instance.signInWithCredential(credential);
        
        // Сохраняем данные пользователя
        if (userCredential.user != null) {
          await _saveUserToFirestore(
            userCredential.user!,
            'google',
          );
          _goToHome();
        }
      } catch (e) {
        setState(() {
          _error = 'Ошибка аутентификации в Firebase: $e';
        });
        debugPrint('Firebase auth error: $e');
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка входа через Google: $e';
      });
      debugPrint('Google sign in error: $e');
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _loading = true; _error = null; });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );
      final cred = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      await _saveUserToFirestore(cred.user!, 'apple');
      _goToHome();
    } catch (e) {
      setState(() { _error = 'Ошибка входа через Apple: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_main.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xCC232946), Color(0xCC372772), Color(0xCC2C2438)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'QazCros',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: app_colors.kBrightTextColor,
                      letterSpacing: 2,
                      shadows: [Shadow(offset: Offset(1,2), blurRadius: 8, color: Colors.black54)]
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                    ),
                  _buildGradientButton(
                    icon: Icons.person_outline,
                    label: 'Войти анонимно',
                    onPressed: _loading ? null : _signInAnonymously,
                  ),
                  const SizedBox(height: 12),
                  _buildGradientButton(
                    icon: Icons.g_mobiledata,
                    label: 'Войти через Google',
                    onPressed: _loading ? null : _signInWithGoogle,
                    gradient: const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
                  ),
                  const SizedBox(height: 12),
                  if (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.macOS)
                    _buildGradientButton(
                      icon: Icons.apple,
                      label: 'Войти через Apple',
                      onPressed: _loading ? null : _signInWithApple,
                      gradient: const LinearGradient(colors: [Colors.black87, Colors.black54]),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(app_colors.kAccentColorYellow)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({required IconData icon, required String label, required VoidCallback? onPressed, LinearGradient? gradient}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient ?? const LinearGradient(colors: [app_colors.kPlayBtnGradStart, app_colors.kPlayBtnGradEnd]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: Icon(icon, color: app_colors.kBrightTextColor),
          label: Text(label, style: const TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
      ),
    );
  }
} 