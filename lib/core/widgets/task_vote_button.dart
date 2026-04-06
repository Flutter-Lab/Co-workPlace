import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/core/app_constants.dart';
import 'package:coworkplace/features/leaderboard/data/score_service.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/core/widgets/user_avatar.dart';
import 'package:coworkplace/core/providers/vote_ticker_provider.dart';
import 'package:coworkplace/core/cache/user_profile_cache.dart';

class TaskVoteButton extends ConsumerStatefulWidget {
  const TaskVoteButton({
    super.key,
    required this.ownerId,
    required this.taskId,
    this.showTransientVoters = false,
  });

  final String ownerId;
  final String taskId;
  final bool showTransientVoters;

  @override
  ConsumerState<TaskVoteButton> createState() => _TaskVoteButtonState();
}

class _TaskVoteButtonState extends ConsumerState<TaskVoteButton>
    with SingleTickerProviderStateMixin {
  List<String> _lastVotes = [];
  List<UserProfile> _recentVoters = [];
  Timer? _clearTimer;
  bool _isProcessing = false;
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
      // fetch voter profiles (small set) and owner name for ticker (cache-first)
      final profiles = await ref
          .read(userProfileCacheProvider)
          .getByIds(newVoters);
      final voterName = profiles.isNotEmpty
          ? profiles.first.displayName
          : 'Someone';
      String ownerName = 'their friend';
      try {
        final owners = await ref.read(userProfileCacheProvider).getByIds([
          widget.ownerId,
        ]);
        if (owners.isNotEmpty) ownerName = owners.first.displayName;
      } catch (_) {}

      // announce via global ticker
      try {
        ref
            .read(voteTickerProvider.notifier)
            .announce(
              "$voterName voted for $ownerName's task",
              color: Colors.pink,
            );
      } catch (_) {}

      if (widget.showTransientVoters) {
        if (!mounted) return;
        setState(() {
          _recentVoters = profiles;
        });
        _pulseController.forward(from: 0.0);
        _clearTimer?.cancel();
        _clearTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            _recentVoters = [];
          });
        });
      }
    } catch (_) {
      // ignore fetch errors for transient UI
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.votingEnabled) return const SizedBox.shrink();

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
                      tooltip: hasVoted ? 'Undo vote' : 'Vote (+1 to friend)',
                      onPressed: () async {
                        if (_isProcessing) return;

                        if (hasVoted) {
                          setState(() => _isProcessing = true);
                          try {
                            await ScoreService().revokeVote(
                              ownerId: widget.ownerId,
                              taskId: widget.taskId,
                              likerId: viewerId,
                              likerLocalDateKey: localDateKey,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vote removed')),
                              );
                            }

                            // announce undo to ticker
                            try {
                              final owners = await ref
                                  .read(userProfileCacheProvider)
                                  .getByIds([widget.ownerId]);
                              final ownerName = owners.isNotEmpty
                                  ? owners.first.displayName
                                  : widget.ownerId;
                              ref
                                  .read(voteTickerProvider.notifier)
                                  .announce(
                                    "${viewerProfile.displayName} removed vote for $ownerName's task",
                                    color: Colors.pink,
                                  );
                            } catch (_) {}
                          } catch (e, st) {
                            // Try to unwrap boxed/converted errors for clearer messages.
                            String message;
                            try {
                              final dyn = e as dynamic;
                              if (dyn.error != null) {
                                message = dyn.error.toString();
                              } else if (dyn.message != null) {
                                message = dyn.message.toString();
                              } else {
                                message = dyn.toString();
                              }
                            } catch (_) {
                              message = e.toString();
                            }
                            debugPrint('revokeVote error: $e');
                            debugPrint('$st');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error removing vote: $message',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        } else {
                          setState(() => _isProcessing = true);
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

                            // Announce immediately for local votes so ticker shows
                            try {
                              final owners = await ref
                                  .read(userProfileCacheProvider)
                                  .getByIds([widget.ownerId]);
                              final ownerName = owners.isNotEmpty
                                  ? owners.first.displayName
                                  : widget.ownerId;
                              ref
                                  .read(voteTickerProvider.notifier)
                                  .announce(
                                    "${viewerProfile.displayName} voted for $ownerName's task",
                                    color: Colors.pink,
                                  );
                            } catch (_) {}
                          } catch (e, st) {
                            String message;
                            try {
                              final dyn = e as dynamic;
                              if (dyn.error != null) {
                                message = dyn.error.toString();
                              } else if (dyn.message != null) {
                                message = dyn.message.toString();
                              } else {
                                message = dyn.toString();
                              }
                            } catch (_) {
                              message = e.toString();
                            }
                            debugPrint('awardVote error: $e');
                            debugPrint('$st');
                            if (context.mounted) {
                              if (message.contains(
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
                                  SnackBar(content: Text('Error: $message')),
                                );
                              }
                            }
                          } finally {
                            if (mounted) setState(() => _isProcessing = false);
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
