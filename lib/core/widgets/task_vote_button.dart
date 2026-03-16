import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/leaderboard/data/score_service.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/core/widgets/user_avatar.dart';

class TaskVoteButton extends ConsumerStatefulWidget {
  const TaskVoteButton({
    super.key,
    required this.ownerId,
    required this.taskId,
  });

  final String ownerId;
  final String taskId;

  @override
  ConsumerState<TaskVoteButton> createState() => _TaskVoteButtonState();
}

class _TaskVoteButtonState extends ConsumerState<TaskVoteButton>
    with SingleTickerProviderStateMixin {
  List<String> _lastVotes = [];
  List<UserProfile> _recentVoters = [];
  Timer? _clearTimer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      lowerBound: 0.9,
      upperBound: 1.15,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clearTimer?.cancel();
    super.dispose();
  }

  void _handleNewVoters(List<String> votes) async {
    final newVoters = votes.where((v) => !_lastVotes.contains(v)).toList();
    _lastVotes = votes;
    if (newVoters.isEmpty) {
      return;
    }

    try {
      final profiles = await ref
          .read(userProfileRepositoryProvider)
          .getByIds(newVoters);
      if (!mounted) {
        return;
      }
      setState(() {
        _recentVoters = profiles;
      });
      _pulseController.forward(from: 0.0);
      _clearTimer?.cancel();
      _clearTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _recentVoters = [];
        });
      });
    } catch (_) {
      // ignore fetch errors for transient UI
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);
    final viewerId = sessionAsync.valueOrNull?.userId;

    if (viewerId == null) {
      return const SizedBox.shrink();
    }

    final repo = ref.watch(userProfileRepositoryProvider);

    return StreamBuilder<List<UserProfile>>(
      stream: repo.watchByIds([viewerId]),
      builder: (context, profileSnap) {
        if (!profileSnap.hasData || profileSnap.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final viewerProfile = profileSnap.data!.first;
        final localDateKey = const DayStartTimeService()
            .localDateKeyForUtcInstant(
              instantUtc: DateTime.now().toUtc(),
              timezone: viewerProfile.timezone,
              dayStartHour: viewerProfile.dayStartHour,
            );

        return StreamBuilder<List<String>>(
          stream: ScoreService().watchTaskVotes(widget.ownerId, widget.taskId),
          builder: (context, snapshot) {
            final votes = snapshot.data ?? [];
            final hasVoted = votes.contains(viewerId);
            final voteCount = votes.length;

            // detect new voters and trigger transient UI
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleNewVoters(votes);
            });

            final avatarRow = _recentVoters.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 4.0, right: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _recentVoters
                          .map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: UserAvatar(profile: p, radius: 20),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );

            // Owner view: read-only, show count and allow viewing voters list
            if (viewerId == widget.ownerId) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatarRow,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (voteCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Text(
                            '$voteCount',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      IconButton(
                        icon: ScaleTransition(
                          scale: _pulseController,
                          child: Icon(
                            Icons.favorite,
                            color: voteCount > 0
                                ? Colors.pink
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        tooltip: voteCount > 0 ? 'View voters' : 'No votes yet',
                        onPressed: voteCount == 0
                            ? null
                            : () async {
                                try {
                                  final profiles = await ref
                                      .read(userProfileRepositoryProvider)
                                      .getByIds(votes);
                                  if (!context.mounted) return;
                                  showDialog<void>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      title: const Text('Voters'),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: ListView(
                                          shrinkWrap: true,
                                          children: profiles
                                              .map(
                                                (p) => ListTile(
                                                  leading: UserAvatar(
                                                    profile: p,
                                                    radius: 16,
                                                  ),
                                                  title: Text(p.displayName),
                                                  subtitle: Text(
                                                    '@${p.username}',
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dCtx).pop(),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to load voters'),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ],
              );
            }

            // Non-owner view: show avatar transient + count and vote button
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatarRow,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (voteCount > 0)
                      Text(
                        '$voteCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasVoted
                              ? Colors.pink
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: hasVoted
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    IconButton(
                      icon: ScaleTransition(
                        scale: _pulseController,
                        child: Icon(
                          hasVoted ? Icons.favorite : Icons.favorite_border,
                          color: hasVoted
                              ? Colors.pink
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                      tooltip: hasVoted ? 'Voted' : 'Vote (+1 to friend)',
                      onPressed: hasVoted
                          ? null
                          : () async {
                              try {
                                await ScoreService().awardVote(
                                  ownerId: widget.ownerId,
                                  taskId: widget.taskId,
                                  likerId: viewerId,
                                  likerLocalDateKey: localDateKey,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Vote recorded! Friend gained +1 point.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  if (e.toString().contains(
                                    'Daily vote limit reached',
                                  )) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "You've used all 10 votes for today!",
                                        ),
                                      ),
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
                ),
              ],
            );
          },
        );
      },
    );
  }
}
