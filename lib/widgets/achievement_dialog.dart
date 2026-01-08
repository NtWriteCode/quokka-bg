import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:quokka/models/user_stats.dart';

class AchievementDialog extends StatefulWidget {
  final List<Achievement> achievements;

  const AchievementDialog({super.key, required this.achievements});

  @override
  State<AchievementDialog> createState() => _AchievementDialogState();
}

class _AchievementDialogState extends State<AchievementDialog> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 3));
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AlertDialog(
          title: const Text('New Achievement Unlocked!', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.achievements.map((ach) => _AchievementItem(achievement: ach)).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Awesome!'),
            ),
          ],
        ),
        ConfettiWidget(
          confettiController: _controller,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
        ),
      ],
    );
  }
}

class _AchievementItem extends StatelessWidget {
  final Achievement achievement;
  const _AchievementItem({required this.achievement});

  @override
  Widget build(BuildContext context) {
    Color tierColor;
    switch (achievement.tier) {
      case AchievementTier.bronze: tierColor = Colors.brown; break;
      case AchievementTier.silver: tierColor = Colors.grey; break;
      case AchievementTier.gold: tierColor = Colors.amber; break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: tierColor, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(achievement.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('+${achievement.xpReward} XP', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
