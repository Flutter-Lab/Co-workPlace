import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coworkplace/features/leaderboard/data/score_service.dart';
import 'package:coworkplace/features/profile/presentation/points_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PointsLogScreen extends StatelessWidget {
  const PointsLogScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final service = ScoreService();
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
      body: StreamBuilder<int>(
        stream: service.watchPointsForUser(userId),
        builder: (context, totalSnap) {
          final total = totalSnap.data ?? 0;
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: service.watchTransactionLog(userId),
            builder: (context, txnSnap) {
              if (txnSnap.hasError) {
                return Center(
                  child: Text('Failed to load points: ${txnSnap.error}'),
                );
              }
              if (!txnSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final txns = txnSnap.data!;

              if (txns.isEmpty) {
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

              // Compute running totals. txns is newest-first; reverse to
              // accumulate chronologically, then show newest-first with balance.
              final reversed = txns.reversed.toList();
              final runningTotals = <int>[];
              int acc = 0;
              for (final t in reversed) {
                acc += (t['delta'] as int? ?? 0);
                runningTotals.add(acc);
              }
              // runningTotals[i] corresponds to reversed[i]
              // Display newest-first → index [n-1] first.
              final n = txns.length;

              return Column(
                children: [
                  // Balance header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All-time Balance',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withAlpha(160),
                                  ),
                            ),
                            Text(
                              '$total pts',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF92400E),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: n,
                      separatorBuilder: (context, i) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final txn = txns[index]; // newest-first
                        final delta = txn['delta'] as int? ?? 0;
                        final reason = txn['reason'] as String? ?? '';
                        final ts = txn['createdAtUtc'];
                        final balanceAfter = runningTotals[n - 1 - index];
                        return _TxnTile(
                          delta: delta,
                          reason: reason,
                          timestamp: ts,
                          balanceAfter: balanceAfter,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({
    required this.delta,
    required this.reason,
    required this.timestamp,
    required this.balanceAfter,
  });

  final int delta;
  final String reason;
  final Object? timestamp;
  final int balanceAfter;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final deltaColor = isPositive
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final deltaText = isPositive ? '+$delta pts' : '$delta pts';

    String timeText = '';
    if (timestamp is Timestamp) {
      timeText = DateFormat(
        'dd MMM yyyy · HH:mm',
      ).format((timestamp as Timestamp).toDate().toLocal());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          _ReasonIcon(reason: reason, isPositive: isPositive),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reasonLabel(reason),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (timeText.isNotEmpty)
                  Text(
                    timeText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                deltaText,
                style: TextStyle(
                  color: deltaColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                '$balanceAfter pts',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reasonLabel(String reason) {
    return switch (reason) {
      'task_done' => 'Task Completed',
      'task_undo' => 'Task Undone',
      'task_create' => 'Task Created',
      'goal_update' => 'Goal Updated',
      'activity_hour' => 'Active Hour',
      'app_open' => 'App Opened',
      'vote' => 'Task Liked',
      'vote_revoked' => 'Like Removed',
      _ => reason,
    };
  }
}

class _ReasonIcon extends StatelessWidget {
  const _ReasonIcon({required this.reason, required this.isPositive});

  final String reason;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final (icon, bg) = switch (reason) {
      'task_done' => (Icons.check_circle_outline, const Color(0xFFDCFCE7)),
      'task_undo' => (Icons.undo, const Color(0xFFFEE2E2)),
      'task_create' => (Icons.add_task, const Color(0xFFEDE9FE)),
      'goal_update' => (Icons.flag_outlined, const Color(0xFFDBEAFE)),
      'activity_hour' => (Icons.timer_outlined, const Color(0xFFFEF3C7)),
      'app_open' => (Icons.login, const Color(0xFFF0FDF4)),
      'vote' => (Icons.thumb_up_outlined, const Color(0xFFFEF9C3)),
      'vote_revoked' => (Icons.thumb_down_outlined, const Color(0xFFFEE2E2)),
      _ => (
        isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
        const Color(0xFFF3F4F6),
      ),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 18,
        color: isPositive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
      ),
    );
  }
}
