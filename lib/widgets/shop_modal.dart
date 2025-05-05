import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart' as app_colors;
import '../services/progress_service.dart';

class ShopModal extends StatefulWidget {
  final VoidCallback onFreeHintTaken;
  final DateTime? lastFreeHintTime;
  final Duration cooldown;

  const ShopModal({
    super.key,
    required this.onFreeHintTaken,
    required this.lastFreeHintTime,
    required this.cooldown,
  });

  @override
  State<ShopModal> createState() => _ShopModalState();
}

class _ShopModalState extends State<ShopModal> {
  late DateTime? _lastFreeHintTime;
  late Duration _cooldown;
  late bool _freeHintAvailable;
  late Duration _timeLeft;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _lastFreeHintTime = widget.lastFreeHintTime;
    _cooldown = widget.cooldown;
    _updateState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration _) {
    if (mounted) {
      setState(_updateState);
    }
  }

  void _updateState() {
    if (_lastFreeHintTime == null) {
      _freeHintAvailable = true;
      _timeLeft = Duration.zero;
      return;
    }
    final now = DateTime.now();
    final nextAvailable = _lastFreeHintTime!.add(_cooldown);
    _freeHintAvailable = now.isAfter(nextAvailable);
    _timeLeft = _freeHintAvailable ? Duration.zero : nextAvailable.difference(now);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: app_colors.kHomeBgGradMid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Магазин', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: app_colors.kBrightTextColor)),
                IconButton(
                  icon: const Icon(Icons.close, color: app_colors.kBrightTextColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _shopItem(
              icon: Icons.workspace_premium,
              title: '20 подсказок, 50 баллов и больше с Пропуском Эксперта',
              color: app_colors.kLevelsBtnGradStart,
              trailing: const Icon(Icons.arrow_forward_ios, color: app_colors.kBrightTextColor, size: 18),
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _shopItem(
              icon: Icons.remove_circle_outline,
              title: 'Убрать рекламу',
              color: Colors.orange,
              trailing: Text('2 390 ₸', style: TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold)),
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _shopItem(
              icon: Icons.card_giftcard,
              title: 'Бесплатная подсказка',
              color: Colors.amber,
              trailing: _freeHintAvailable
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app_colors.kLevelsBtnGradEnd,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      ),
                      onPressed: () async {
                        await ProgressService().incrementHints();
                        widget.onFreeHintTaken();
                        Navigator.pop(context);
                      },
                      child: const Text('Получить'),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: app_colors.kHomeCircleBorder,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_formatDuration(_timeLeft), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
            ),
            const SizedBox(height: 8),
            _shopItem(
              icon: Icons.lightbulb_outline,
              title: '10 Подсказок',
              color: app_colors.kAccentColorYellow,
              trailing: Text('1 490 ₸', style: TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold)),
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _shopItem(
              icon: Icons.lightbulb,
              title: '50 Подсказок',
              color: app_colors.kAccentColorYellow,
              trailing: Text('2 390 ₸', style: TextStyle(color: app_colors.kBrightTextColor, fontWeight: FontWeight.bold)),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _shopItem({
    required IconData icon,
    required String title,
    required Color color,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: app_colors.kHomeBgGradStart.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15, color: app_colors.kBrightTextColor, fontWeight: FontWeight.w500)),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing,
            ]
          ],
        ),
      ),
    );
  }
}

class Ticker {
  final void Function(Duration) onTick;
  late final Stopwatch _stopwatch;
  late final Duration _interval;
  bool _active = false;

  Ticker(this.onTick, [Duration interval = const Duration(seconds: 1)]) {
    _interval = interval;
    _stopwatch = Stopwatch();
  }

  void start() {
    _active = true;
    _stopwatch.start();
    _tick();
  }

  void _tick() async {
    while (_active) {
      await Future.delayed(_interval);
      if (_active) onTick(_stopwatch.elapsed);
    }
  }

  void dispose() {
    _active = false;
    _stopwatch.stop();
  }
} 