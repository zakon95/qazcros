import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart' as app_colors;
import '../services/progress_service.dart';

class StatisticsWidget extends StatefulWidget {
  const StatisticsWidget({Key? key}) : super(key: key);

  @override
  State<StatisticsWidget> createState() => _StatisticsWidgetState();
}

class _StatisticsWidgetState extends State<StatisticsWidget> {
  int _completedLevels = 0;
  String _city = '';
  String _createdAt = '';
  int _hintsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _city = data['city'] ?? '';
          _createdAt = data['createdAt'] != null ? data['createdAt'].toString().substring(0, 10) : '';
          _hintsCount = data['hintsCount'] ?? 0;
        });
      }
      // Загружаем количество пройденных уровней
      final progressService = ProgressService();
      final completed = await progressService.loadCompletedLevels();
      setState(() {
        _completedLevels = completed.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: app_colors.kHomeBgGradMid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ваша статистика', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: app_colors.kAccentColorYellow)),
            const SizedBox(height: 16),
            Row(children: [const Icon(Icons.emoji_events, color: app_colors.kAccentColorYellow), SizedBox(width: 8), Text('Пройдено уровней: $_completedLevels', style: TextStyle(fontSize: 16, color: app_colors.kBrightTextColor))]),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.location_city, color: app_colors.kAccentColorYellow), SizedBox(width: 8), Text('Город: ${_city.isNotEmpty ? _city : 'Не выбран'}', style: TextStyle(fontSize: 16, color: app_colors.kBrightTextColor))]),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.calendar_today, color: app_colors.kAccentColorYellow), SizedBox(width: 8), Text('Регистрация: ${_createdAt.isNotEmpty ? _createdAt : '—'}', style: TextStyle(fontSize: 16, color: app_colors.kBrightTextColor))]),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.lightbulb, color: app_colors.kAccentColorYellow), SizedBox(width: 8), Text('Подсказок: $_hintsCount', style: TextStyle(fontSize: 16, color: app_colors.kBrightTextColor))]),
            const SizedBox(height: 10),
            // Очки — через StreamBuilder
            Row(
              children: [
                const Icon(Icons.star, color: app_colors.kAccentColorYellow),
                const SizedBox(width: 8),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseAuth.instance.currentUser == null
                    ? null
                    : FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots(),
                  builder: (context, snapshot) {
                    int score = 0;
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.data() != null) {
                      score = (snapshot.data!.data()!['score'] ?? 0) as int;
                    }
                    return Text('Очки: $score', style: const TextStyle(fontSize: 16, color: app_colors.kBrightTextColor));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 