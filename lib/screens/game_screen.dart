import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../data/levels_loader.dart';
import '../models/level_model.dart';
import '../models/question_model.dart';
import '../widgets/phrase_display.dart';
import '../widgets/kazakh_keyboard.dart';
import '../services/progress_service.dart';
import 'level_complete_screen.dart';
import '../theme/app_colors.dart';
import 'settings_screen.dart';
import '../services/audio_service.dart';
import '../widgets/hint_floating_button.dart';
import '../widgets/shop_modal.dart';

class GameScreen extends StatefulWidget {
  final int levelNumber;
  const GameScreen({super.key, required this.levelNumber});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final _logger = Logger('GameScreen');
  LevelModel? level; String? error; final Set<int> guessedCodes = {};
  List<List<FocusNode>> answerFocusNodes = [];
  final Map<int, TextEditingController> _answerTextControllers = {};
  final Map<int, String> _incorrectInputs = {};
  int? _currentQuestionIndex; int? _currentLetterIndex;
  FocusNode? _activeFocusNode; TextEditingController? _activeController; int? _activeCode;
  bool _isKeyboardVisible = false; bool _isPhraseInputFocused = false;
  final ProgressService _progressService = ProgressService();
  int hintsCount = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadHintsCount();
      _initializeGame();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioService().stopMusic();
    for (final row in answerFocusNodes) { for (final node in row) { node.dispose(); } }
    answerFocusNodes.clear();
    for (final controller in _answerTextControllers.values) { controller.dispose(); }
    _answerTextControllers.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      AudioService().stopMusic();
    } else if (state == AppLifecycleState.resumed) {
      AudioService().playMusic();
    }
  }

  Future<void> _loadHintsCount() async {
    final newCount = await _progressService.getHintsCount();
    if (mounted) {
      setState(() {
        hintsCount = newCount;
      });
    }
  }

  Future<void> _initializeGame() async {
    if (!mounted) return;
    
    try {
      setState(() {
        error = null;
        _isKeyboardVisible = false;
        _isPhraseInputFocused = false;
      });

      // Загружаем уровень
      final loadedLevel = await LevelsLoader.loadLevel(widget.levelNumber);
      if (!mounted) return;
      
      if (loadedLevel == null) {
        _logger.severe('Failed to load level: ${widget.levelNumber}');
        if (mounted) {
          setState(() {
            error = 'Не удалось загрузить уровень';
          });
          return;
        }
      }

      // Инициализируем состояние игры
      await _initializeGameState(loadedLevel!);

      // Инициализируем аудио после загрузки уровня
      await _initializeAudio();

    } catch (e, stackTrace) {
      _logger.severe('Error initializing game: $e\nStack trace: $stackTrace');
      if (mounted) {
        setState(() {
          error = 'Ошибка инициализации игры';
        });
      }
    }
  }

  Future<void> _initializeGameState(LevelModel loadedLevel) async {
    if (!mounted) return;
    
    setState(() {
      level = loadedLevel;
      guessedCodes.clear();
      _incorrectInputs.clear();
      _activeFocusNode = null;
      _activeController = null;
      _activeCode = null;
      _currentQuestionIndex = null;
      _currentLetterIndex = null;

      // Очищаем старые FocusNode
      for (final row in answerFocusNodes) {
        for (final node in row) {
          node.dispose();
        }
      }
      answerFocusNodes.clear();
      _answerTextControllers.forEach((_, controller) => controller.dispose());
      _answerTextControllers.clear();

      // Инициализируем новые FocusNode для каждого вопроса
      answerFocusNodes = List.generate(
        loadedLevel.questions.length,
        (qIndex) => (loadedLevel.questions[qIndex].answer?.isNotEmpty ?? false)
            ? List.generate(loadedLevel.questions[qIndex].answer!.length, (_) => FocusNode())
            : <FocusNode>[]
      );

      // Инициализируем контроллеры для каждого кода
      for (var question in loadedLevel.questions) {
        if (question.letterCodes == null) continue;
        for (var codeRaw in question.letterCodes!) {
          final int? code = codeRaw as int?;
          if (code != null) {
            if (!_answerTextControllers.containsKey(code)) {
              _answerTextControllers[code] = TextEditingController();
            } else {
              _answerTextControllers[code]?.clear();
            }
          }
        }
      }
    });

    // Настраиваем слушатели фокуса
    _setupFocusListeners();
  }

  Future<void> _initializeAudio() async {
    try {
      // Инициализируем аудио сервис
      await AudioService().initialize();
      
      // Запускаем фоновую музыку с небольшой задержкой
      if (mounted && AudioService().musicEnabled) {
        await Future.delayed(const Duration(milliseconds: 500));
        await AudioService().playMusic();
      }
    } catch (e, stackTrace) {
      _logger.warning('Error initializing audio: $e\nStack trace: $stackTrace');
      // Продолжаем работу даже при ошибках аудио
    }
  }

  void _setupFocusListeners() {
    if (level == null) return;
    for (int qIndex = 0; qIndex < answerFocusNodes.length; qIndex++) {
      if (qIndex >= level!.questions.length || qIndex >= answerFocusNodes.length) continue;
      final question = level!.questions[qIndex];
      final letterCodes = question.letterCodes; final answer = question.answer;
      if (letterCodes == null || answer == null) continue;
      for (int lIndex = 0; lIndex < answerFocusNodes[qIndex].length; lIndex++) {
        if (lIndex >= letterCodes.length || lIndex >= answer.length) continue;
        final focusNode = answerFocusNodes[qIndex][lIndex];
        final codeRaw = letterCodes[lIndex]; final int? code = codeRaw as int?;
        if (code != null) {
          final listener = () => _focusChanged(focusNode, code, qIndex, lIndex);
          try { focusNode.removeListener(listener); } catch(e) {}
          focusNode.addListener(listener);
        }
      }
    }
  }

  void _focusChanged(FocusNode focusNode, int code, int qIndex, int lIndex) {
    if (!mounted) return;
    if (focusNode.hasFocus) {
      final controller = _answerTextControllers[code];
      if (controller != null) {
        if (_activeFocusNode != focusNode || !_isKeyboardVisible) {
          bool needsSetState = false;
          if (_incorrectInputs.containsKey(code)) {
            _incorrectInputs.remove(code);
            if (controller.text.isNotEmpty) { controller.clear(); }
            needsSetState = true;
          } else if (controller.text.isNotEmpty && !guessedCodes.contains(code)) {
            controller.clear();
          }
          _currentQuestionIndex = qIndex; _currentLetterIndex = lIndex;
          _activeFocusNode = focusNode; _activeCode = code; _activeController = controller;
          _isPhraseInputFocused = false;
          if (!_isKeyboardVisible) { _isKeyboardVisible = true; needsSetState = true; }
          if (needsSetState) { setState(() {}); } else { setState(() {}); }
        }
      }
    } else {
      if (_activeFocusNode == focusNode) {}
    }
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (mounted) {
      setState(() {
        _activeFocusNode = null; _activeController = null; _activeCode = null;
        _currentQuestionIndex = null; _currentLetterIndex = null;
        _isKeyboardVisible = false; _isPhraseInputFocused = false;
      });
    }
  }

  void _handleKeyboardInput(String key) {
    if (!mounted) return;
    if (key == 'HIDE_KEYBOARD') { _hideKeyboard(); return; }
    if (key == 'BACKSPACE') { if (_activeController != null && _activeCode != null) { _handleBackspace(); AudioService().playClick(); } return; }
    if (key == 'HINT') { useHint(); return; }
    if (_activeController != null && _activeCode != null && _currentQuestionIndex != null && _currentLetterIndex != null) {
      final code = _activeCode!; final controller = _activeController!; final inputLetter = key.toUpperCase();
      if (guessedCodes.contains(code)) { _moveToNextUnguessed(_currentQuestionIndex!, _currentLetterIndex!); return; }
      handleAnswerLetterInput( code, inputLetter, controller, _currentQuestionIndex!, _currentLetterIndex! );
      AudioService().playClick();
    }
  }

  void _playSoundForAnswer(bool isCorrect, int code) {
    if (!isCorrect) {
      AudioService().playError();
      return;
    }

    // Проверяем, все ли буквы в слове угаданы
    bool allLettersGuessed = true;
    for (var cell in level!.phraseDisplay) {
      if (cell.letter != null && !guessedCodes.contains(cell.code)) {
        allLettersGuessed = false;
        break;
      }
    }

    if (allLettersGuessed) {
      AudioService().playSuccess();
    } else {
      AudioService().playClick();
    }
  }

  void handleAnswerLetterInput(int code, String value, TextEditingController controller, int questionIndex, int letterIndex) {
    if (!mounted) return; 
    if (value.isEmpty || level == null) return; 
    final correctLetter = getLetterForCode(code); 
    if (correctLetter == '?') return;
    
    bool isCorrect = value == correctLetter;
    if (isCorrect) {
      bool needsSetState = false;
      if (controller.text != correctLetter) { 
        controller.text = correctLetter; 
        controller.selection = TextSelection.collapsed(offset: correctLetter.length); 
      }
      if (!guessedCodes.contains(code)) { 
        guessedCodes.add(code); 
        needsSetState = true; 
      }
      if (_incorrectInputs.containsKey(code)) { 
        _incorrectInputs.remove(code); 
        needsSetState = true; 
      }
      if (needsSetState) { 
        setState(() {}); 
      }
      HapticFeedback.lightImpact(); 
      
      _playSoundForAnswer(true, code);
      _checkLevelCompletion();
      _moveToNextUnguessed(questionIndex, letterIndex);
    } else {
      AudioService().playError();
      _incorrectInputs[code] = value;
      setState(() {});
    }
  }

  void _moveToNextUnguessed(int currentQ, int currentL){
    if (level == null || !mounted) return; int nextQ = currentQ; int nextL = -1;
    if (currentQ < level!.questions.length && level!.questions[currentQ].answer != null && currentL + 1 < level!.questions[currentQ].answer!.length) { final cQ = level!.questions[currentQ]; if(cQ.letterCodes != null) { for (int i = currentL + 1; i < cQ.answer!.length; i++) { if (i < cQ.letterCodes!.length) { final nC = cQ.letterCodes![i] as int?; if (nC != null && !guessedCodes.contains(nC)) { nextL = i; break; } } } } }
    if (nextL == -1) { for (int q = currentQ + 1; q < level!.questions.length; q++) { if (q >= level!.questions.length) break; final nQ = level!.questions[q]; if (nQ.answer != null && nQ.answer!.isNotEmpty && nQ.letterCodes != null) { for (int l = 0; l < nQ.answer!.length; l++) { if (l < nQ.letterCodes!.length) { final nC = nQ.letterCodes![l] as int?; if (nC != null && !guessedCodes.contains(nC)) { nextQ = q; nextL = l; break; } } } } if (nextL != -1) break; } }
    if (nextL != -1 && answerFocusNodes.length > nextQ && answerFocusNodes[nextQ].length > nextL) { Future.delayed(const Duration(milliseconds: 50), () { if(mounted) FocusScope.of(context).requestFocus(answerFocusNodes[nextQ][nextL]); }); }
    else { _hideKeyboard(); }
  }

  void _handleBackspace() {
    if (!mounted || _activeController == null || _activeCode == null || _currentQuestionIndex == null || _currentLetterIndex == null) { return; }
    final controller = _activeController!; final code = _activeCode!; final qIndex = _currentQuestionIndex!; final lIndex = _currentLetterIndex!;
    if (!guessedCodes.contains(code) && (_incorrectInputs.containsKey(code) || controller.text.isNotEmpty)) {
      bool needsSetState = false;
      if (_incorrectInputs.containsKey(code)) { _incorrectInputs.remove(code); needsSetState = true; }
      if (controller.text.isNotEmpty) { controller.clear(); }
      if (needsSetState) { setState(() {}); }
      return;
    }
    _moveToPrevious(qIndex, lIndex);
  }

  void _moveToPrevious(int currentQ, int currentL){
    if (level == null || !mounted) return; int prevQ = currentQ; int prevL = -1;
    if (currentQ < level!.questions.length) { final cQ = level!.questions[currentQ]; if (cQ.answer != null) { for (int i = currentL - 1; i >= 0; i--) { prevL = i; break; } } }
    if (prevL == -1 && currentQ > 0) { for (int q = currentQ - 1; q >= 0; q--) { if (q < level!.questions.length && level!.questions[q].answer?.isNotEmpty == true) { prevL = level!.questions[q].answer!.length - 1; prevQ = q; break; } } }
    if (prevL != -1 && answerFocusNodes.length > prevQ && answerFocusNodes[prevQ].length > prevL) { Future.delayed(const Duration(milliseconds: 50), () { if(mounted) answerFocusNodes[prevQ][prevL].requestFocus(); }); }
  }

  String getLetterForCode(int code) { 
    if (level == null) { return '?'; } 
    for (final q in level!.questions) { 
      if (q.letterCodes==null || q.answer==null) continue; 
      for (int i=0; i<q.letterCodes!.length; i++) { 
        final cCode = q.letterCodes![i] as int?; 
        if (cCode == code) { 
          if (i < q.answer!.length) { 
            return q.answer![i]?.toUpperCase() ?? '?'; 
          } else { 
            return '?'; 
          } 
        } 
      } 
    } 
    if (level!.phraseDisplay != null) { 
      for (final cell in level!.phraseDisplay) { 
        if (cell.code == code && cell.letter?.isNotEmpty==true) { 
          return cell.letter!.toUpperCase(); 
        } 
      } 
    } 
    return '?'; 
  }

  Future<void> _checkLevelCompletion() async { 
    if (level == null || !mounted) return; 
    Set<int> allCodes={}; 
    for(var q in level!.questions){
      allCodes.addAll(q.letterCodes?.whereType<int>()??{}); 
    } 
    if(allCodes.isEmpty){return;} 
    final bool allGuessed = guessedCodes.containsAll(allCodes); 
    if(allGuessed){ 
      await _progressService.addCompletedLevel(widget.levelNumber); 
      if(mounted){ 
        const maxLvl=100; 
        Navigator.pushReplacement(context, MaterialPageRoute(builder:(ctx)=>LevelCompleteScreen(completedLevel: level!, maxLevel: maxLvl))); 
      } 
    } 
  }

  void _handlePhraseInput(int code, String value) {
    setState(() {
      if (value.isEmpty) {
        _incorrectInputs[code] = '';
      } else {
        final correctLetter = level!.phraseDisplay.firstWhere((c) => c.code == code).letter?.toUpperCase();
        if (value == correctLetter) {
          guessedCodes.add(code);
          _incorrectInputs.remove(code);
        } else {
          _incorrectInputs[code] = value;
        }
      }
      // Показываем кастомную клавиатуру при любом фокусе на PhraseDisplay
      _isKeyboardVisible = true;
    });
  }

  void _onLetterInput(int code, String value) {
    if (!mounted) return; 
    if (value.isEmpty || level == null) return; 
    final correctLetter = getLetterForCode(code); 
    if (correctLetter == '?') return;
    
    bool isCorrect = value == correctLetter;
    if (isCorrect) {
      bool needsSetState = false;
      if (_answerTextControllers[code]!.text.contains(correctLetter)) { 
        _answerTextControllers[code]!.text = correctLetter; 
        _answerTextControllers[code]!.selection = TextSelection.collapsed(offset: correctLetter.length); 
      }
      if (!guessedCodes.contains(code)) { 
        guessedCodes.add(code); 
        needsSetState = true; 
      }
      if (_incorrectInputs.containsKey(code)) { 
        _incorrectInputs.remove(code); 
        needsSetState = true; 
      }
      if (needsSetState) { 
        setState(() {}); 
      }
      HapticFeedback.lightImpact(); 
      
      _playSoundForAnswer(true, code);
      _checkLevelCompletion();
      _moveToNextUnguessed(_currentQuestionIndex!, _currentLetterIndex!);
    } else {
      AudioService().playError();
      _incorrectInputs[code] = value;
      setState(() {});
    }
  }

  void useHint() {
    if (level == null) return;
    if (hintsCount <= 0) return;
    // Если есть активный вопрос
    int? qIndex = _currentQuestionIndex;
    if (qIndex == null) {
      // Если нет активного, ищем первый вопрос с неотгаданной буквой
      for (var i = 0; i < level!.questions.length; i++) {
        final question = level!.questions[i];
        if (question.letterCodes == null) continue;
        for (var codeRaw in question.letterCodes!) {
          final code = codeRaw as int?;
          if (code != null && !guessedCodes.contains(code)) {
            qIndex = i;
            break;
          }
        }
        if (qIndex != null) break;
      }
    }
    if (qIndex == null) return;
    final question = level!.questions[qIndex];
    if (question.letterCodes == null) return;
    for (var codeRaw in question.letterCodes!) {
      final code = codeRaw as int?;
      if (code != null && !guessedCodes.contains(code)) {
        guessedCodes.add(code);
        _answerTextControllers[code]?.text = getLetterForCode(code);
        hintsCount = hintsCount - 1;
        setState(() {});
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) { return Scaffold( body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(error!, style: TextStyle(color: Colors.red, fontSize: 16)))) ); }
    if (level == null) { return Scaffold( body: Container( decoration: BoxDecoration( gradient: LinearGradient(colors: [kHomeBgGradStart, kHomeBgGradMid, kHomeBgGradEnd]), ), child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kLoadingIndicatorColor))), ), ); }
    const double backgroundOverlayOpacity = 0.5;
    return Scaffold(
      extendBodyBehindAppBar: false,
      resizeToAvoidBottomInset: false,
      backgroundColor: Color(0xFF2C2438),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: kGameScreenBackgroundGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            automaticallyImplyLeading: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: kIconColor),
              onPressed: () async {
                final shouldExit = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: kHomeBgGradMid,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text('Выйти из игры?', style: TextStyle(fontWeight: FontWeight.bold, color: kAccentColorYellow)),
                    content: const Text('Вы потеряете свой прогресс', style: TextStyle(color: kBrightTextColor)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: kLevelsBtnGradStart,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Нет'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: kPlayBtnGradStart,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Да, выйти'),
                      ),
                    ],
                  ),
                );
                if (shouldExit == true) {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  level!.category,
                  style: const TextStyle(color: kBrightTextColor, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Уровень ${widget.levelNumber}',
                  style: const TextStyle(color: kSubtleTextColor, fontSize: 13),
                ),
              ],
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: kIconColor),
                tooltip: 'Настройки',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: kGameScreenBackgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: PhraseDisplay(
                          phrase: level!.phraseDisplay,
                          guessedCodes: guessedCodes,
                          primaryColor: kBrightTextColor,
                          backgroundColor: kAnswerBoxBg,
                          correctGuessColor: kAnswerBoxCorrectBgStart,
                          correctGuessBorderColor: kAnswerBoxBorder,
                          shadowDarkColor: Colors.transparent,
                          shadowLightColor: Colors.transparent,
                          textColor: kAnswerBoxCorrectText,
                          hintTextColor: kHintTextColorNormal,
                          incorrectInputMap: _incorrectInputs,
                          incorrectBackgroundColor: kAnswerBoxIncorrectBg,
                          incorrectBorderColor: kAnswerBoxIncorrectBorder,
                          activeCode: _activeCode,
                          onLetterInput: _handlePhraseInput,
                          onActiveCodeChange: (int code) {
                            setState(() {
                              _activeCode = code;
                            });
                          },
                          onShowCustomKeyboard: () {
                            setState(() {
                              _isKeyboardVisible = true;
                            });
                          },
                          disableSystemKeyboard: true,
                        ),
                      ),
                    ),
                    ...List.generate(
                      level!.questions.length,
                      (index) => _buildQuestionAnswerBlock(level!.questions[index], index),
                    ),
                  ],
                ),
              ),
              if (_isKeyboardVisible)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: KazakhKeyboard(
                      onKeyPressed: _handleKeyboardInput,
                      hintsCount: hintsCount,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionAnswerBlock(QuestionModel question, int questionIndex) {
    final String questionText = question.question ?? "?";
    final String? answerText = question.answer;
    if (answerText == null || question.letterCodes == null) return const SizedBox.shrink();

    final bool isEven = questionIndex % 2 == 0;
    final List<Color> gradientColors = isEven ? kQABlockGradientA : kQABlockGradientB;
    final int answerLength = answerText.length;

    // Минималистичная компоновка: вопрос сверху, ячейки снизу
    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 6.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              questionText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kBrightTextColor,
                height: 1.4,
                shadows: [Shadow(offset: Offset(0, 1), blurRadius: 1, color: Colors.black45)],
              ),
              textAlign: TextAlign.left,
            ),
          ),
          Wrap(
            spacing: 4.0, // Минималистичный spacing
            children: List.generate(answerLength, (letterIndex) {
              return _buildSquareCell(
                question,
                questionIndex,
                letterIndex,
                32.0, // Минималистичный размер клетки
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareCell(QuestionModel question, int questionIndex, int letterIndex, double size) {
    final letterCodes = question.letterCodes;
    if (letterCodes == null || letterIndex >= letterCodes.length) {
      return SizedBox(width: size, height: size);
    }

    final codeRaw = letterCodes[letterIndex];
    final int? code = codeRaw as int?;
    if (code == null) {
      return SizedBox(width: size, height: size);
    }

    final controller = _answerTextControllers[code];
    final focusNode = (answerFocusNodes.length > questionIndex &&
        answerFocusNodes[questionIndex].length > letterIndex)
      ? answerFocusNodes[questionIndex][letterIndex]
      : null;
    if (controller == null || focusNode == null) {
      return SizedBox(width: size, height: size);
    }

    final isRevealed = guessedCodes.contains(code);
    // Подсвечиваем ВСЕ ячейки с этим кодом, если активный код совпадает
    final bool hasFocus = _activeCode != null && code == _activeCode;
    final String? incorrectLetter = _incorrectInputs[code];
    final bool hasIncorrectInput = !isRevealed && incorrectLetter != null;

    Decoration decoration;
    Color letterColor = kBrightTextColor;
    FontWeight letterWeight = FontWeight.bold;
    Color hintNumberColor = kHintTextColorNormal;
    bool showCursor = false;
    String cellLetter = '';

    if (isRevealed) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
            colors: [kAnswerBoxCorrectBgStart, kAnswerBoxCorrectBgEnd]
        ),
        borderRadius: BorderRadius.circular(8),
      );
      letterColor = kAnswerBoxCorrectText;
      letterWeight = FontWeight.w900;
      hintNumberColor = kHintTextColorCorrect;
      cellLetter = getLetterForCode(code);
    } else {
      if (hasIncorrectInput) {
        decoration = BoxDecoration(
          color: kAnswerBoxIncorrectBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAnswerBoxIncorrectBorder, width: 1.5),
        );
        letterColor = kAnswerBoxIncorrectText;
        letterWeight = FontWeight.w900;
        hintNumberColor = kHintTextColorIncorrect;
        cellLetter = incorrectLetter ?? '';
      } else if (hasFocus) {
        decoration = BoxDecoration(
            gradient: const LinearGradient(
                colors: [kAccentColorYellow, kPlayBtnGradEnd]
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kFocusHighlightColor, width: 2.0)
        );
        letterColor = kBrightTextColor;
        letterWeight = FontWeight.w900;
        hintNumberColor = kHintTextColorFocus;
        showCursor = true;
        cellLetter = controller.text;
      } else {
        decoration = BoxDecoration(
          color: kAnswerBoxBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAnswerBoxBorder),
        );
        letterColor = kSubtleTextColor;
        letterWeight = FontWeight.w700;
        hintNumberColor = kHintTextColorNormal;
        cellLetter = controller.text;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          child: GestureDetector(
            onTap: () {
              if (!isRevealed) {
                focusNode.requestFocus();
                // Принудительно показываем клавиатуру
                if (!_isKeyboardVisible) {
                  setState(() {
                    _isKeyboardVisible = true;
                  });
                }
                // Явно обновляем индексы активной ячейки (для корректного курсора)
                setState(() {
                  _currentQuestionIndex = questionIndex;
                  _currentLetterIndex = letterIndex;
                  _activeFocusNode = focusNode;
                  _activeController = controller;
                  _activeCode = code;
                });
              } else {
                _hideKeyboard();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: decoration,
              alignment: Alignment.center,
              child: Text(
                cellLetter,
                style: TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: letterWeight,
                  color: letterColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        Container(
          width: size,
          height: 16,
          alignment: Alignment.center,
          child: Text(
            '$code',
            style: TextStyle(
              fontSize: 10,
              color: hintNumberColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> reloadHintsCount() async {
    final newCount = await _progressService.getHintsCount();
    setState(() {
      hintsCount = newCount;
    });
  }
}