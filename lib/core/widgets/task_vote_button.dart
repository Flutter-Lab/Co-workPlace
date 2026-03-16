import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/leaderboard/data/score_service.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/core/time/day_start_time_service.dart';

class TaskVoteButton extends ConsumerWidget {
  const TaskVoteButton({
    super.key,
    required this.ownerId,
    required this.taskId,
  });

  final String ownerId;
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final viewerId = session.requireValue.userId;

    if (viewerId == null || viewerId == ownerId) {
      return const SizedBox.shrink();
    }

    final repo = ref.watch(userProfileRepositoryProvider);
    
    return StreamBuilder<List<UserProfile>>(
      stream: repo.watchByIds([viewerId]),
      builder: (context, profileSnap) {
        if (!profileSnap.hasData || profileSnap.data!.isEmpty) return const SizedBox.shrink();
        
        final viewerProfile = profileSnap.data!.first;
        final localDateKey = const DayStartTimeService().localDateKeyForUtcInstant(
          instantUtc: DateTime.now().toUtc(),
          timezone: viewerProfile.timezone,
          dayStartHour: viewerProfile.dayStartHour,
        );

        return StreamBuilder<List<String>>(
          stream: ScoreService().watchTaskVotes(ownerId, taskId),
          builder: (context, snapshot) {
            final votes = snapshot.data ?? [];
            final hasVoted = votes.contains(viewerId);
            final voteCount = votes.length;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (voteCount > 0)
                  Text(
                    '$voteCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasVoted ? Colors.pink : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    hasVoted ? Icons.favorite : Icons.favorite_border,
                    color: hasVoted ? Colors.pink : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  tooltip: hasVoted ? 'Voted' : 'Vote (+1 to friend)',
                  onPressed: hasVoted
                      ? null
                      : () async {
                          try {
                            await ScoreService().awardVote(
                              ownerId: ownerId,
                              taskId: taskId,
                              likerId: viewerId,
                              likerLocalDateKey: localDateKey,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vote recorded! Friend gained +1 point.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              if (e.toString().contains('Daily vote limit reached')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("You've used all 10 votes for today!")),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

