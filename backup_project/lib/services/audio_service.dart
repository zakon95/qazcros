import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService with ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Плееры для музыки и эффектов
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();

  final _logger = Logger('AudioService');

  bool _isInitialized = false;
  bool _isMusicEnabled = true;
  bool _isEffectsEnabled = true;
  double _musicVolume = 0.1;    // 10% громкости для фоновой музыки
  double _effectsVolume = 0.5;  // 50% громкости для звуковых эффектов

  // Пути к аудиофайлам
  static const String _bgMusicAsset = 'audio/bg_music.mp3';
  static const String _clickAsset = 'audio/click.wav';
  static const String _successAsset = 'audio/success.wav';
  static const String _errorAsset = 'audio/error.wav';

  // Кэшируем источники аудио
  late final AssetSource _musicSource;
  late final AssetSource _clickSource;
  late final AssetSource _successSource;
  late final AssetSource _errorSource;

  // Инициализация при создании сервиса
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing audio service...');
      
      // Загружаем настройки
      final prefs = await SharedPreferences.getInstance();
      _isMusicEnabled = prefs.getBool('music_enabled') ?? true;
      _isEffectsEnabled = prefs.getBool('effects_enabled') ?? true;

      // Инициализируем источники аудио
      _musicSource = AssetSource(_bgMusicAsset);
      _clickSource = AssetSource(_clickAsset);
      _successSource = AssetSource(_successAsset);
      _errorSource = AssetSource(_errorAsset);

      // Настраиваем плееры
      await Future.wait([
        _configurePlayer(_musicPlayer, _musicVolume, ReleaseMode.loop),
        _configurePlayer(_effectPlayer, _effectsVolume, ReleaseMode.release)
      ]);

      _isInitialized = true;
      _logger.info('Audio service initialized successfully');
      
      // Запускаем фоновую музыку если включена
      if (_isMusicEnabled) {
        await playMusic();
      }
    } catch (e, stackTrace) {
      _logger.severe('Error initializing audio service: $e\nStack trace: $stackTrace');
      _isInitialized = false;
    }
  }

  Future<void> _configurePlayer(AudioPlayer player, double volume, ReleaseMode mode) async {
    try {
      await player.setVolume(volume);
      await player.setReleaseMode(mode);
      
      // Дополнительные настройки для веб
      if (kIsWeb) {
        await player.setPlaybackRate(1.0);
      }
    } catch (e) {
      _logger.warning('Error configuring player: $e');
    }
  }

  // --- Геттеры/сеттеры для настроек ---
  bool get musicEnabled => _isMusicEnabled;
  set musicEnabled(bool value) => setMusicEnabled(value);

  bool get effectsEnabled => _isEffectsEnabled;
  set effectsEnabled(bool value) => setEffectsEnabled(value);

  double get musicVolume => _musicVolume;
  set musicVolume(double value) {
    if (value < 0.0 || value > 1.0) return;
    _musicVolume = value;
    _musicPlayer.setVolume(value);
    notifyListeners();
  }

  double get effectsVolume => _effectsVolume;
  set effectsVolume(double value) {
    if (value < 0.0 || value > 1.0) return;
    _effectsVolume = value;
    _effectPlayer.setVolume(value);
    notifyListeners();
  }

  // --- Музыка ---
  Future<void> playMusic() async {
    if (!_isInitialized || !_isMusicEnabled) return;
    
    try {
      _logger.info('Attempting to play music');
      
      final playerState = await _musicPlayer.state;
      if (playerState == PlayerState.playing) {
        return;
      }

      // Проверяем доступность файла перед воспроизведением
      final ByteData data = await rootBundle.load('assets/$_bgMusicAsset');
      if (data.lengthInBytes == 0) {
        throw Exception('Audio file is empty');
      }

      await _musicPlayer.stop();
      await _musicPlayer.play(_musicSource);
    } catch (e) {
      _logger.warning('Error playing music: $e');
      // Пытаемся восстановиться после ошибки
      _isInitialized = false;
      await initialize();
    }
  }

  Future<void> stopMusic() async {
    if (!_isInitialized) return;
    
    try {
      await _musicPlayer.stop();
    } catch (e) {
      _logger.warning('Error stopping music: $e');
    }
  }

  Future<void> pauseMusic() async {
    if (!_isInitialized || !_isMusicEnabled) return;
    
    try {
      await _musicPlayer.pause();
    } catch (e) {
      _logger.warning('Error pausing music: $e');
    }
  }

  Future<void> resumeMusic() async {
    if (!_isInitialized || !_isMusicEnabled) return;
    
    try {
      await _musicPlayer.resume();
    } catch (e) {
      _logger.warning('Error resuming music: $e');
    }
  }

  // --- Звуковые эффекты ---
  Future<void> _playEffect(AssetSource source) async {
    if (!_isInitialized || !_isEffectsEnabled) return;
    
    try {
      // Проверяем доступность файла перед воспроизведением
      final String assetPath = source.path.startsWith('assets/') 
          ? source.path 
          : 'assets/${source.path}';
      await rootBundle.load(assetPath);

      await _effectPlayer.stop();
      await _effectPlayer.play(source);
    } catch (e) {
      _logger.warning('Error playing effect: $e');
    }
  }

  Future<void> playClick() async => _playEffect(_clickSource);
  Future<void> playSuccess() async => _playEffect(_successSource);
  Future<void> playError() async => _playEffect(_errorSource);

  // --- Управление настройками ---
  Future<void> setMusicEnabled(bool enabled) async {
    if (_isMusicEnabled == enabled) return;
    
    _isMusicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', enabled);
    
    if (enabled) {
      await playMusic();
    } else {
      await stopMusic();
    }
    
    notifyListeners();
  }

  Future<void> setEffectsEnabled(bool enabled) async {
    if (_isEffectsEnabled == enabled) return;
    
    _isEffectsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('effects_enabled', enabled);
    
    notifyListeners();
  }

  // --- Освобождение ресурсов ---
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      await stopMusic();
      await Future.wait([
        _musicPlayer.dispose(),
        _effectPlayer.dispose()
      ]);
      _isInitialized = false;
      _logger.info('Audio resources disposed');
    } catch (e) {
      _logger.severe('Error disposing audio resources: $e');
    }
  }
}
