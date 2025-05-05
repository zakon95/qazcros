import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'dart:io' show Platform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _logger = Logger('AuthService');
  
  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;
  
  // Получение прогресса пользователя по его UID
  Future<Map<String, dynamic>?> getUserProgress(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
          
      if (!doc.exists) return null;
      
      return {
        'completedLevels': (doc.data()?['completedLevels'] as List<dynamic>?)?.cast<int>() ?? [],
        'totalCompletedLevels': doc.data()?['totalCompletedLevels'] ?? 0,
        'maxCompletedLevel': doc.data()?['maxCompletedLevel'] ?? 0,
      };
    } catch (e) {
      _logger.severe('Error getting user progress: $e');
      return null;
    }
  }

  // Получение данных существующего аккаунта по credentials
  Future<Map<String, dynamic>?> getExistingAccountProgress(AuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user == null) return null;
      final progress = await getUserProgress(userCredential.user!.uid);
      // Возвращаемся к анонимному пользователю
      await _auth.signInAnonymously();
      return progress;
    } catch (e) {
      _logger.severe('Error checking existing account: $e');
      return null;
    }
  }

  // Привязка Google аккаунта с обработкой конфликтов
  Future<LinkAccountResult> linkGoogleAccount() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return LinkAccountResult(
          success: false,
          error: 'Вход через Google отменён',
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      try {
        // Пробуем привязать аккаунт
        await currentUser?.linkWithCredential(credential);
        return LinkAccountResult(success: true);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          // Получаем прогресс существующего аккаунта
          final existingProgress = await getExistingAccountProgress(credential);
          
          if (existingProgress != null) {
            return LinkAccountResult(
              success: false,
              error: 'Аккаунт уже существует',
              existingProgress: existingProgress,
              credential: credential,
            );
          }
        }
        return LinkAccountResult(
          success: false,
          error: 'Ошибка привязки аккаунта: ${e.message}',
        );
      }
    } catch (e) {
      return LinkAccountResult(
        success: false,
        error: 'Неизвестная ошибка: $e',
      );
    }
  }

  // Вход в существующий аккаунт (после подтверждения пользователем)
  Future<bool> signInWithExistingAccount(AuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      _logger.severe('Error signing in with existing account: $e');
      return false;
    }
  }

  // Привязка Apple ID с обработкой конфликтов
  Future<LinkAccountResult> linkAppleAccount() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      try {
        await currentUser?.linkWithCredential(oauthCredential);
        return LinkAccountResult(success: true);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          final existingProgress = await getExistingAccountProgress(oauthCredential);
          if (existingProgress != null) {
            return LinkAccountResult(
              success: false,
              error: 'Apple ID уже привязан к другому профилю',
              existingProgress: existingProgress,
              credential: oauthCredential,
            );
          }
        }
        return LinkAccountResult(
          success: false,
          error: 'Ошибка привязки Apple ID: ${e.message}',
        );
      }
    } catch (e) {
      return LinkAccountResult(
        success: false,
        error: 'Неизвестная ошибка: $e',
      );
    }
  }

  // Вход в существующий Apple ID аккаунт (после подтверждения пользователем)
  Future<bool> signInWithExistingAppleAccount(AuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      _logger.severe('Error signing in with existing Apple account: $e');
      return false;
    }
  }
}

class LinkAccountResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? existingProgress;
  final AuthCredential? credential;

  LinkAccountResult({
    required this.success,
    this.error,
    this.existingProgress,
    this.credential,
  });
} 