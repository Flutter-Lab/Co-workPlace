import 'package:coworkplace/features/leaderboard/data/score_service.dart';
import 'package:coworkplace/features/profile/presentation/points_info_screen.dart';
import 'package:flutter/material.dart';

class PointsLogScreen extends StatelessWidget {
  const PointsLogScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points Log'),
        actions: [
          IconButton(
            tooltip: 'How to earn points',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PointsInfoScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ScoreService().watchAllScores(userId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Failed to load points: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 48,
                      color: Color(0xFFF59E0B),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No points yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Complete tasks, open the app daily, and earn points!',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final periodId = doc['periodId'] as String;
              final points = doc['points'] as int;
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    _periodLabel(periodId),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(_periodSubtitle(periodId)),
                  trailing: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: Text(
                        '$points pts',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _periodLabel(String periodId) {
    if (periodId == 'alltime') return 'All-time Total';
    if (periodId.startsWith('week_')) {
      final parts = periodId.split('_');
      if (parts.length == 3) return 'Week ${parts[2]} · ${parts[1]}';
    }
    if (periodId.startsWith('month_')) {
      final parts = periodId.split('_');
      if (parts.length == 3) {
        final monthNames = [
          '',
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        final m = int.tryParse(parts[2]) ?? 0;
        return '${monthNames[m]} ${parts[1]}';
      }
    }
    return periodId;
  }

  String _periodSubtitle(String periodId) {
    if (periodId == 'alltime') return 'Cumulative score across all time';
    if (periodId.startsWith('week_')) return 'Weekly score';
    if (periodId.startsWith('month_')) return 'Monthly score';
    return '';
  }
}
