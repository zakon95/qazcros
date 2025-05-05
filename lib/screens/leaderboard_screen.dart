import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart' as app_colors;
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:logger/logger.dart'; // Удаляем, если logger не установлен
import '../services/progress_service.dart';
// import '../services/auth_service.dart'; // Удаляем, если не используется
import '../models/leaderboard_entry.dart';

// Везде далее заменить все обращения к цветам и градиентам на переменные из app_colors.dart (например, kBrightTextColor, kPlayBtnGradStart и т.д.)
// Заменяем стандартные цвета на фирменные из app_colors.dart
// Например:
// Colors.red -> kAnswerBoxIncorrectBorder
// Colors.grey[850] -> kHomeBgGradMid
// Colors.grey[500] -> kSubtleBtnText
// Colors.black -> kHomeBgGradStart
// Colors.white -> kBrightTextColor
// и т.д.

// Исправление: заменяем все обращения к AppColors на прямые переменные из app_colors.dart
// Например: AppColors.kBrightTextColor -> kBrightTextColor
//           AppColors.kHomeBgGradStart -> kHomeBgGradStart
//           AppColors.kLeaderboardGradStart -> kLeaderboardGradStart
//           AppColors.kLeaderboardGradEnd -> kLeaderboardGradEnd
//           AppColors.kLeaderboardShadow -> kLeaderboardShadow
//           AppColors.kLeaderboardBorder -> kLeaderboardBorder
//           AppColors.kLeaderboardText -> kLeaderboardText
//           и т.д.

// Logger _logger = Logger('LeaderboardScreen');

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  final List<String> _periods = ['Сегодня', 'За месяц', 'За всё время'];
  int _selectedPeriod = 0; // 0 - сегодня, 1 - месяц, 2 - всё время
  int _selectedTab = 0; // 0 - Казахстан, 1 - Мой город
  String? _userCity;

  @override
  void initState() {
    super.initState();
    _loadUserCity();
  }

  Future<void> _loadUserCity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && data['city'] != null && data['city'].toString().isNotEmpty) {
        setState(() {
          _userCity = data['city'] as String;
        });
      }
    }
  }

  Stream<List<LeaderboardEntry>> _getLeaderboardStream() {
    String orderField;
    switch (_selectedPeriod) {
      case 0:
        orderField = 'score_today';
        break;
      case 1:
        orderField = 'score_month';
        break;
      default:
        orderField = 'score';
    }
    var query = FirebaseFirestore.instance
        .collection('leaderboard')
        .orderBy(orderField, descending: true)
        .limit(100);
    if (_selectedTab == 1 && _userCity != null && _userCity!.isNotEmpty) {
      query = query.where('city', isEqualTo: _userCity);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => LeaderboardEntry.fromMap(doc.data())).toList());
  }

  int _getScoreForPeriod(LeaderboardEntry entry) {
    switch (_selectedPeriod) {
      case 0:
        return entry.scoreToday;
      case 1:
        return entry.scoreMonth;
      default:
        return entry.score;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Лидерборд', style: TextStyle(color: app_colors.kBrightTextColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: app_colors.kBrightTextColor),
      ),
      body: Column(
        children: [
          // Переключатель периода
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_periods.length, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ChoiceChip(
                  label: Text(_periods[i], style: TextStyle(color: _selectedPeriod == i ? app_colors.kBrightTextColor : app_colors.kSubtleTextColor)),
                  selected: _selectedPeriod == i,
                  selectedColor: app_colors.kAccentColorYellow,
                  backgroundColor: app_colors.kHomeBgGradMid,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPeriod = i;
                    });
                  },
                ),
              )),
            ),
          ),
          // Вкладки Казахстан/Мой город
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab('Казахстан', 0),
                const SizedBox(width: 16),
                _buildTab('Мой город', 1),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LeaderboardEntry>>(
              stream: _getLeaderboardStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: \\${snapshot.error}', style: TextStyle(color: app_colors.kBrightTextColor)));
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Center(child: Text('Нет данных', style: TextStyle(color: app_colors.kSubtleTextColor)));
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => Divider(color: app_colors.kHomeCircleBorder, height: 1),
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    final isCurrentUser = entry.userId == FirebaseAuth.instance.currentUser?.uid;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: entry.avatar.isNotEmpty
                            ? (entry.avatar.startsWith('http')
                                ? NetworkImage(entry.avatar)
                                : AssetImage(entry.avatar)) as ImageProvider
                            : const AssetImage('assets/avatars/avatar_1.png'),
                        backgroundColor: app_colors.kHomeBgGradMid,
                      ),
                      title: Text(
                        entry.displayName,
                        style: TextStyle(
                          color: isCurrentUser ? app_colors.kAccentColorYellow : app_colors.kBrightTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        entry.city,
                        style: const TextStyle(color: app_colors.kSubtleTextColor),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: app_colors.kAccentColorYellow, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _getScoreForPeriod(entry).toString(),
                            style: const TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: app_colors.kHomeBgGradMid,
    );
  }

  Widget _buildTab(String label, int idx) {
    final selected = _selectedTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? app_colors.kAccentColorYellow.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? app_colors.kAccentColorYellow : app_colors.kSubtleTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}