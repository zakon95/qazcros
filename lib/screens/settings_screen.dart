import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import '../theme/app_colors.dart' as app_colors;
import 'dart:io' show Platform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

bool get isIOS {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS;
  } catch (_) {
    return false;
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AudioService _audioService = AudioService();
  final ProgressService _progressService = ProgressService();
  final _logger = Logger('SettingsScreen');
  final _authService = AuthService();
  
  bool soundEnabled = true;
  double soundVolume = 0.7;
  bool musicEnabled = true;
  double musicVolume = 0.6;
  bool notificationsEnabled = true;
  bool _isLoading = false;
  int _completedLevelsCount = 0;
  String? _userName;
  String? _userEmail;
  String? _avatarAsset;
  String? _selectedCity;
  DateTime? _lastCityChange;

  final List<String> _kazakhstanCities = [
    'Астана', 'Алматы', 'Шымкент', 'Караганда', 'Актобе', 'Тараз', 'Павлодар', 'Усть-Каменогорск',
    'Семей', 'Атырау', 'Костанай', 'Кызылорда', 'Петропавловск', 'Темиртау', 'Туркестан',
    'Кокшетау', 'Талдыкорган', 'Экибастуз', 'Рудный', 'Жезказган', 'Жанаозен', 'Каскелен',
    'Балхаш', 'Актау', 'Кентау', 'Сатпаев', 'Аксай', 'Степногорск', 'Шахтинск', 'Арыс', 'Щучинск'
  ];

  @override
  void initState() {
    super.initState();
    soundEnabled = _audioService.effectsEnabled;
    soundVolume = _audioService.effectsVolume;
    musicEnabled = _audioService.musicEnabled;
    musicVolume = _audioService.musicVolume;
    _loadUserData();
    _loadCompletedLevelsCount();
    // Если город не выбран или невалидный, ставим дефолт
    if (_selectedCity == null || !_kazakhstanCities.contains(_selectedCity)) {
      _selectedCity = 'Астана';
    }
    // Если аватар не выбран, ставим дефолт
    if (_avatarAsset == null || _avatarAsset!.isEmpty) {
      _avatarAsset = 'assets/avatars/avatar_1.png';
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? 'Игрок';
        _userEmail = user.email ?? 'Анонимно';
      });
      // Загружаем аватарку и дату последней смены города
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          if (data['avatar'] != null) {
            setState(() {
              _avatarAsset = data['avatar'] as String;
            });
          }
          if (data['lastCityChange'] != null) {
            _lastCityChange = (data['lastCityChange'] as Timestamp).toDate();
          }
        }
      } catch (_) {}
      _loadCity(user.uid);
    }
  }

  Future<void> _loadCompletedLevelsCount() async {
    try {
      final completedLevels = await _progressService.loadCompletedLevels();
      setState(() {
        _completedLevelsCount = completedLevels.length;
      });
    } catch (e) {
      _logger.severe('Error loading completed levels count: $e');
    }
  }

  Future<void> _resetProgress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _progressService.clearProgress();
      // Сброс очков
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'score': 0,
          'score_today': 0,
          'score_month': 0,
        }, SetOptions(merge: true));
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('score', 0);
      await _progressService.setScore(0);
      setState(() {
        _completedLevelsCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прогресс и очки успешно сброшены!')),
      );
    } catch (e) {
      _logger.severe('Error resetting progress: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сбросе прогресса: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncProgress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final completedLevels = await _progressService.syncProgress();
      setState(() {
        _completedLevelsCount = completedLevels.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прогресс синхронизирован!')),
      );
    } catch (e) {
      _logger.severe('Error syncing progress: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при синхронизации прогресса: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      _logger.severe('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выходе из аккаунта: $e')),
      );
    }
  }

  Future<void> _linkAccount() async {
    setState(() { _isLoading = true; });
    try {
      final result = isIOS
          ? await _authService.linkAppleAccount()
          : await _authService.linkGoogleAccount();
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isIOS ? 'Apple ID успешно привязан!' : 'Аккаунт успешно привязан!')),
        );
        await _loadUserData();
        setState(() {});
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else if (result.existingProgress != null && result.credential != null) {
        // Показываем диалог выбора
        final shouldSwitch = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(isIOS ? 'Найден существующий Apple ID' : 'Найден существующий аккаунт'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIOS
                    ? 'Этот Apple ID уже привязан к другому игровому профилю со следующим прогрессом:'
                    : 'Этот Google-аккаунт уже привязан к другому игровому профилю со следующим прогрессом:',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  '• Пройдено уровней: ${result.existingProgress!['totalCompletedLevels']}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '• Максимальный уровень: ${result.existingProgress!['maxCompletedLevel']}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  isIOS
                    ? 'Если вы продолжите, ваш текущий анонимный прогресс будет утерян, и вы войдёте в существующий Apple ID.'
                    : 'Если вы продолжите, ваш текущий анонимный прогресс будет утерян, и вы войдёте в существующий аккаунт.',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Остаться в текущем профиле'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: Text(isIOS ? 'Войти в Apple ID' : 'Войти в Google-аккаунт'),
              ),
            ],
          ),
        );

        if (shouldSwitch == true) {
          // Пользователь выбрал войти в существующий аккаунт
          final success = isIOS
              ? await _authService.signInWithExistingAppleAccount(result.credential!)
              : await _authService.signInWithExistingAccount(result.credential!);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isIOS ? 'Успешно выполнен вход в Apple ID!' : 'Успешно выполнен вход в существующий аккаунт!')),
            );
            await _loadUserData();
            setState(() {});
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isIOS ? 'Ошибка входа в Apple ID' : 'Ошибка входа в существующий аккаунт')),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Неизвестная ошибка')),
        );
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _editUserName() async {
    final controller = TextEditingController(text: _userName ?? '');
    String? errorText;
    String? newName;
    do {
      newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Изменить никнейм'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 15, // Ограничение на 15 символов
                decoration: InputDecoration(
                  hintText: 'Введите новый никнейм',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (newName == null) return; // Отмена
      if (newName.length < 4) {
        errorText = 'Имя должно быть не короче 4 символов';
      } else {
        errorText = null;
      }
    } while (errorText != null);
    if (newName.isNotEmpty && newName != _userName) {
      setState(() {
        _userName = newName;
      });
      // Сохраняем в Firebase, если пользователь авторизован
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
        // Если используешь Firestore для профиля — обнови и там
        try {
          final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
          await doc.set({'displayName': newName}, SetOptions(merge: true));
        } catch (_) {}
      }
    }
  }

  bool get _isAnonymous => FirebaseAuth.instance.currentUser?.isAnonymous == true;

  void _showAvatarPicker() async {
    final avatars = List.generate(10, (i) => 'assets/avatars/avatar_${i + 1}.png');
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите аватар'),
        content: SizedBox(
          width: 320,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: avatars.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => Navigator.pop(ctx, avatars[i]),
              child: CircleAvatar(
                radius: 32,
                backgroundImage: AssetImage(avatars[i]),
                child: avatars[i] == _avatarAsset ? const Icon(Icons.check, color: Colors.green, size: 32) : null,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickAndUploadAvatar();
            },
            child: const Text('Загрузить своё фото'),
          ),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        _avatarAsset = selected;
      });
      // Сохраняем выбранную аватарку в Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
          await doc.set({'avatar': selected}, SetOptions(merge: true));
        } catch (_) {}
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Увеличиваем качество
        maxWidth: 400,   // Уменьшаем максимальный размер
        maxHeight: 400,
      );
      
      if (pickedFile != null) {
        // Показываем индикатор загрузки
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          Navigator.of(context).pop(); // Закрываем индикатор
          return;
        }

        try {
          final file = File(pickedFile.path);
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('avatars')
              .child('${user.uid}.jpg');

          // Загружаем файл
          await storageRef.putFile(
            file,
            SettableMetadata(contentType: 'image/jpeg'),
          );

          // Получаем URL
          final downloadUrl = await storageRef.getDownloadURL();

          // Обновляем в Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'avatar': downloadUrl});

          setState(() {
            _avatarAsset = downloadUrl;
          });

          if (mounted) {
            Navigator.of(context).pop(); // Закрываем индикатор
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Аватар успешно обновлен')),
            );
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Закрываем индикатор
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка загрузки: ${e.toString()}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора файла: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadCity(String userId) async {
    try {
      final doc = FirebaseFirestore.instance.collection('users').doc(userId);
      final city = await doc.get();
      final data = city.data();
      if (data != null && data['city'] != null) {
        setState(() {
          _selectedCity = data['city'] as String;
        });
      }
    } catch (e) {
      _logger.severe('Error loading city: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Настройки', style: TextStyle(color: app_colors.kBrightTextColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: app_colors.kGameScreenBackgroundGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: app_colors.kBrightTextColor),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: app_colors.kGameScreenBackgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Аватарка слева
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        GestureDetector(
                          onTap: _showAvatarPicker,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundImage: (_avatarAsset != null && _avatarAsset!.isNotEmpty)
                                ? (_avatarAsset!.startsWith('http')
                                    ? NetworkImage(_avatarAsset!)
                                    : AssetImage(_avatarAsset!)) as ImageProvider
                                : const AssetImage('assets/avatars/avatar_1.png'),
                            backgroundColor: Colors.grey[400],
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
                            onPressed: _pickAndUploadAvatar,
                            tooltip: 'Загрузить свою аватарку',
                            splashRadius: 22,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Информация справа (адаптивно)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Имя
                                  Row(
                                    children: [
                                      const Text('Имя:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: app_colors.kBrightTextColor)),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _userName ?? 'Игрок',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: app_colors.kBrightTextColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: _editUserName,
                                        child: const Icon(Icons.edit, size: 18, color: app_colors.kAccentColorYellow),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  // Город
                                  Row(
                                    children: [
                                      const Text('Город:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: app_colors.kBrightTextColor)),
                                      SizedBox(width: 8),
                                      DropdownButton<String>(
                                        value: (_selectedCity != null && _kazakhstanCities.contains(_selectedCity))
                                            ? _selectedCity
                                            : _kazakhstanCities.first,
                                        hint: const Text('Выбрать', style: TextStyle(fontSize: 18, color: app_colors.kBrightTextColor)),
                                        dropdownColor: app_colors.kHomeBgGradMid,
                                        style: const TextStyle(fontSize: 18, color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold),
                                        iconEnabledColor: app_colors.kAccentColorYellow,
                                        underline: Container(height: 1, color: app_colors.kAccentColorYellow),
                                        items: _kazakhstanCities.map((city) => DropdownMenuItem<String>(
                                          value: city,
                                          child: Text(city, style: const TextStyle(fontSize: 18, color: app_colors.kBrightTextColor)),
                                        )).toList(),
                                        onChanged: (city) async {
                                          final now = DateTime.now();
                                          // Если lastCityChange не установлен, разрешаем первую смену города без ограничений
                                          if (_lastCityChange != null) {
                                            final diff = now.difference(_lastCityChange!).inDays;
                                            if (diff < 7) {
                                              final daysLeft = 7 - diff;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Город можно менять не чаще, чем раз в 7 дней. Осталось дней: $daysLeft')),
                                              );
                                              return;
                                            }
                                          }
                                          setState(() {
                                            _selectedCity = city;
                                          });
                                          // Сохраняем в Firebase, если пользователь авторизован
                                          final user = FirebaseAuth.instance.currentUser;
                                          if (user != null) {
                                            try {
                                              final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
                                              await doc.set({'city': city, 'lastCityChange': Timestamp.fromDate(now)}, SetOptions(merge: true));
                                              _lastCityChange = now;
                                            } catch (_) {}
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  // Почта
                                  Row(
                                    children: [
                                      const Text('Почта:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: app_colors.kBrightTextColor)),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _userEmail ?? 'Анонимно',
                                          style: const TextStyle(fontSize: 18, color: app_colors.kBrightTextColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  // Пройдено уровней
                                  Row(
                                    children: [
                                      const Icon(Icons.emoji_events, size: 18, color: app_colors.kAccentColorYellow),
                                      SizedBox(width: 4),
                                      Text('Пройдено уровней: $_completedLevelsCount', style: const TextStyle(fontSize: 18, color: app_colors.kBrightTextColor)),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  // Очки
                                  Row(
                                    children: [
                                      const Icon(Icons.star, size: 18, color: app_colors.kAccentColorYellow),
                                      SizedBox(width: 4),
                                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                        stream: FirebaseAuth.instance.currentUser == null
                                          ? null
                                          : FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots(),
                                        builder: (context, snapshot) {
                                          int score = 0;
                                          if (snapshot.hasData && snapshot.data != null && snapshot.data!.data() != null) {
                                            score = (snapshot.data!.data()!['score'] ?? 0) as int;
                                          }
                                          return Text('Очки: $score', style: const TextStyle(fontSize: 18, color: app_colors.kBrightTextColor));
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  // Кнопка выйти/привязать аккаунт
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: _isAnonymous
                                      ? _buildGradientTextButton(
                                          icon: isIOS ? Icons.apple : Icons.g_mobiledata,
                                          label: isIOS ? 'Привязать Apple ID' : 'Привязать Google',
                                          onPressed: _linkAccount,
                                          gradient: isIOS
                                            ? const LinearGradient(colors: [Colors.black87, Colors.black54])
                                            : const LinearGradient(colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
                                          iconColor: app_colors.kBrightTextColor,
                                        )
                                      : _buildGradientTextButton(
                                          icon: Icons.logout,
                                          label: 'Выйти',
                                          onPressed: _signOut,
                                          gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                                          iconColor: Colors.redAccent,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: app_colors.kHomeCircleBorder),
                _buildGradientSwitchTile(
                  icon: Icons.volume_up_rounded,
                  title: 'Звук в игре',
                  value: soundEnabled,
                  onChanged: (v) {
                    setState(() => soundEnabled = v);
                    _audioService.effectsEnabled = v;
                  },
                  gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                ),
                if (soundEnabled)
                  _buildGradientSlider(
                    icon: Icons.music_note,
                    value: soundVolume,
                    onChanged: (v) {
                      setState(() => soundVolume = v);
                      _audioService.effectsVolume = v;
                    },
                    gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                  ),
                _buildGradientSwitchTile(
                  icon: Icons.music_video,
                  title: 'Музыка',
                  value: musicEnabled,
                  onChanged: (v) {
                    setState(() => musicEnabled = v);
                    _audioService.musicEnabled = v;
                  },
                  gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                ),
                if (musicEnabled)
                  _buildGradientSlider(
                    icon: Icons.music_video,
                    value: musicVolume,
                    onChanged: (v) {
                      setState(() => musicVolume = v);
                      _audioService.musicVolume = v;
                    },
                    gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                  ),
                _buildGradientSwitchTile(
                  icon: Icons.notifications_active,
                  title: 'Уведомления',
                  value: notificationsEnabled,
                  onChanged: (v) => setState(() => notificationsEnabled = v),
                  gradient: const LinearGradient(colors: [app_colors.kAccentColorYellow, app_colors.kCardGradientEnd]),
                ),
                const SizedBox(height: 8),
                _buildGradientButton(
                  icon: Icons.restore,
                  label: 'Восстановить покупки',
                  onPressed: () {
                    // TODO: реализовать восстановление покупок
                  },
                  gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                  alignLeft: true,
                ),
                _buildGradientButton(
                  icon: Icons.card_giftcard,
                  label: 'Промокод',
                  onPressed: () {
                    // TODO: реализовать ввод промокода
                  },
                  gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                  alignLeft: true,
                ),
                _buildGradientButton(
                  icon: Icons.info_outline,
                  label: 'О приложении',
                  onPressed: () {
                    // TODO: переход на экран "О приложении"
                  },
                  gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                  alignLeft: true,
                ),
                _buildGradientButton(
                  icon: Icons.language,
                  label: 'Больше игр на казахском языке',
                  onPressed: () {
                    // TODO: реализовать переход на сайт/маркет
                  },
                  gradient: const LinearGradient(colors: [app_colors.kCardGradientStart, app_colors.kCardGradientEnd]),
                  alignLeft: true,
                ),
                const SizedBox(height: 8),
                _buildGradientButton(
                  icon: Icons.delete_forever,
                  label: 'Сбросить прогресс',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: app_colors.kHomeBgGradMid,
                        title: const Text('Сбросить прогресс?', style: TextStyle(color: app_colors.kBrightTextColor)),
                        content: const Text('Вы уверены, что хотите сбросить ваш прогресс? Все пройденные уровни и заработанные очки будут обнулены!', style: TextStyle(color: app_colors.kBrightTextColor)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Отмена', style: TextStyle(color: app_colors.kSubtleTextColor)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _resetProgress();
                              Navigator.of(context).pop(true);
                            },
                            child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  gradient: const LinearGradient(colors: [Colors.red, app_colors.kHomeBgGradMid]),
                  iconColor: Colors.redAccent,
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientSwitchTile({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged, required LinearGradient gradient}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: app_colors.kBrightTextColor),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.w600, fontSize: 16))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: app_colors.kBrightTextColor,
            inactiveThumbColor: app_colors.kSubtleTextColor,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildGradientSlider({required IconData icon, required double value, required ValueChanged<double> onChanged, required LinearGradient gradient}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: app_colors.kBrightTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Slider(
              value: value,
              onChanged: onChanged,
              min: 0.0,
              max: 1.0,
              activeColor: app_colors.kBrightTextColor,
              inactiveColor: app_colors.kSubtleTextColor,
            ),
          ),
          Text((value * 100).toInt().toString(), style: const TextStyle(color: app_colors.kBrightTextColor)),
        ],
      ),
    );
  }

  Widget _buildGradientButton({required IconData icon, required String label, required VoidCallback? onPressed, required LinearGradient gradient, Color? iconColor, bool alignLeft = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
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
          icon: Icon(icon, color: iconColor ?? app_colors.kBrightTextColor),
          label: Align(
            alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
            child: Text(
              label,
              style: const TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
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

  Widget _buildGradientTextButton({required IconData icon, required String label, required VoidCallback? onPressed, required LinearGradient gradient, Color? iconColor}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        icon: Icon(icon, color: iconColor ?? app_colors.kBrightTextColor),
        label: Text(label, style: const TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold)),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
