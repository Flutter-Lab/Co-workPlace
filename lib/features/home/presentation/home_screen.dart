import 'dart:async';

import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:coworkplace/core/app_constants.dart';
import 'package:coworkplace/features/leaderboard/data/score_service.dart';
import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/features/friends/domain/friend_connection.dart';
import 'package:coworkplace/features/friends/presentation/friend_profile_screen.dart';
import 'package:coworkplace/features/friends/providers/friend_providers.dart';
import 'package:coworkplace/features/profile/presentation/personal_profile_screen.dart';
import 'package:coworkplace/features/profile/data/user_profile_repository.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/core/cache/user_profile_cache.dart';
import 'package:coworkplace/features/tasks/data/completion_repository.dart';
import 'package:coworkplace/features/tasks/data/task_repository.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';
import 'package:coworkplace/features/tasks/providers/task_providers.dart';
import 'package:coworkplace/core/widgets/task_vote_button.dart';
import 'package:coworkplace/core/widgets/user_avatar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Session error: $error')),
      data: (session) {
        final profile = session.profile;
        final userId = session.userId;
        if (profile == null || userId == null) {
          return const Center(child: Text('Set up your profile first.'));
        }

        if (Firebase.apps.isEmpty) {
          return const Center(
            child: Text(
              'Feed becomes available after Firebase is initialized.',
            ),
          );
        }

        final friendRepository = ref.watch(friendRepositoryProvider);
        final profileRepository = ref.watch(userProfileRepositoryProvider);
        final taskRepository = ref.watch(taskRepositoryProvider);
        final completionRepository = ref.watch(completionRepositoryProvider);

        return Scaffold(
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 48),
                  const _LeaderboardCard(),
                  const SizedBox(height: 8),
                  _FriendFeedSection(
                    profileRepository: profileRepository,
                    taskRepository: taskRepository,
                    completionRepository: completionRepository,
                    friendStream: friendRepository.watchFriends(userId),
                    currentUserId: userId,
                    currentUserProfile: profile,
                    currentFeedViewMode: profile.feedViewMode,
                  ),
                  const SizedBox(height: 56),
                ],
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withAlpha(235),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(89),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      'v${AppConstants.appVersion}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(209),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              // VoteTicker moved to app root for global visibility.
            ],
          ),
        );
      },
    );
  }
}

class _FriendFeedSection extends ConsumerStatefulWidget {
  const _FriendFeedSection({
    required this.profileRepository,
    required this.taskRepository,
    required this.completionRepository,
    required this.friendStream,
    required this.currentUserId,
    required this.currentUserProfile,
    required this.currentFeedViewMode,
  });

  final UserProfileRepository profileRepository;
  final TaskRepository taskRepository;
  final CompletionRepository completionRepository;
  final Stream<List<FriendConnection>> friendStream;
  final String currentUserId;
  final UserProfile currentUserProfile;
  final FeedViewMode currentFeedViewMode;

  @override
  ConsumerState<_FriendFeedSection> createState() => _FriendFeedSectionState();
}

class _LeaderboardCard extends ConsumerStatefulWidget {
  const _LeaderboardCard();

  @override
  ConsumerState<_LeaderboardCard> createState() => _LeaderboardCardState();
}

class _LeaderboardCardState extends ConsumerState<_LeaderboardCard> {
  final Map<String, Future<List<Map<String, dynamic>>>> _futureCache = {};

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final myId = session?.userId;
    if (myId == null) {
      return const SizedBox.shrink();
    }

    final friendRepo = ref.read(friendRepositoryProvider);
    final profileCache = ref.read(userProfileCacheProvider);
    final service = ScoreService();
    final periodId = service.weekPeriodId(DateTime.now().toUtc());

    return StreamBuilder<List<dynamic>>(
      stream: friendRepo.watchFriends(myId),
      builder: (context, friendSnap) {
        if (friendSnap.hasError) {
          return const SizedBox.shrink();
        }
        if (!friendSnap.hasData) {
          return const _LeaderboardSkeletonCard();
        }

        final friends = friendSnap.data!;
        final friendIds = friends.map((f) => f.friendUserId as String).toSet();
        friendIds.add(myId);

        final key = '${periodId}_${(friendIds.toList()..sort()).join(',')}';
        _futureCache.putIfAbsent(
          key,
          () =>
              service.getScoresForUsers(periodId: periodId, userIds: friendIds),
        );

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureCache[key],
          builder: (context, scoresSnap) {
            if (scoresSnap.hasError) {
              return const SizedBox.shrink();
            }
            if (scoresSnap.connectionState == ConnectionState.waiting) {
              return const _LeaderboardSkeletonCard();
            }

            final docs = scoresSnap.data ?? <Map<String, dynamic>>[];
            if (docs.isEmpty) {
              return Card(
                child: ListTile(
                  title: const Text('👑 Weekly Top'),
                  subtitle: const Text('No leaderboard data yet.'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    );
                  },
                ),
              );
            }

            final top = docs.first;
            final topId = top['userId'] as String;
            final points = top['points'] as int;

            return FutureBuilder<List<UserProfile>>(
              future: (() async {
                final cached = await profileCache.getByIds([topId]);
                if (cached.isNotEmpty && cached.first.displayName != topId) {
                  return cached;
                }
                final repo = ref.read(userProfileRepositoryProvider);
                try {
                  final fresh = await repo.getByIds([topId]);
                  if (fresh.isNotEmpty) {
                    // persist fresh profile into cache for future fast reads
                    try {
                      await profileCache.storeProfiles(fresh);
                    } catch (_) {}
                    return fresh;
                  }
                } catch (_) {}
                return cached;
              })(),
              builder: (context, profilesSnap) {
                if (profilesSnap.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: ListTile(
                      title: Text('👑 Weekly Top'),
                      subtitle: Text('Loading...'),
                    ),
                  );
                }

                final profiles = profilesSnap.data ?? <UserProfile>[];
                final profile = profiles.isNotEmpty ? profiles.first : null;
                final display = profile?.displayName ?? topId;

                return Card(
                  child: ListTile(
                    leading: UserAvatar(profile: profile, radius: 20),
                    title: const Text('👑 Weekly Top'),
                    subtitle: Text(display),
                    trailing: Text(
                      '$points pts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen(),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FriendFeedSectionState extends ConsumerState<_FriendFeedSection> {
  static const _timeService = DayStartTimeService();
  // Grid mode is temporarily disabled — force list view.
  // To re-enable: restore `late FeedViewMode _mode = widget.currentFeedViewMode;`
  FeedViewMode _mode = FeedViewMode.list;

  @override
  void didUpdateWidget(covariant _FriendFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mode = FeedViewMode.list;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _FriendFeedTile(
              profile: widget.currentUserProfile,
              taskRepository: widget.taskRepository,
              completionRepository: widget.completionRepository,
              localDateKeyResolver: _resolveLocalDateKey,
              compact: false,
              isSelf: true,
              viewerTimezone: widget.currentUserProfile.timezone,
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<FriendConnection>>(
              stream: widget.friendStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Failed to load friend feed: ${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return const _FeedSkeletonCard();
                }

                final friends = snapshot.data!;
                if (friends.isEmpty) {
                  return const ListTile(
                    leading: Icon(Icons.people_outline),
                    title: Text('No friends yet'),
                    subtitle: Text(
                      'Add friends from the Friends tab to see their task states here.',
                    ),
                  );
                }

                return StreamBuilder<List<UserProfile>>(
                  stream: widget.profileRepository.watchByIds(
                    friends.map((friend) => friend.friendUserId),
                  ),
                  builder: (context, profileSnapshot) {
                    if (profileSnapshot.hasError) {
                      return Text(
                        'Failed to load friend profiles: ${profileSnapshot.error}',
                      );
                    }

                    if (!profileSnapshot.hasData) {
                      return const _FeedSkeletonCard();
                    }

                    final profiles = profileSnapshot.data!;
                    if (_mode == FeedViewMode.grid) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: profiles.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.35,
                            ),
                        itemBuilder: (context, index) {
                          return _FriendFeedTile(
                            profile: profiles[index],
                            taskRepository: widget.taskRepository,
                            completionRepository: widget.completionRepository,
                            localDateKeyResolver: _resolveLocalDateKey,
                            compact: true,
                            isSelf: false,
                            viewerTimezone: widget.currentUserProfile.timezone,
                          );
                        },
                      );
                    }

                    return Column(
                      children: profiles.map((profile) {
                        return _FriendFeedTile(
                          profile: profile,
                          taskRepository: widget.taskRepository,
                          completionRepository: widget.completionRepository,
                          localDateKeyResolver: _resolveLocalDateKey,
                          compact: false,
                          isSelf: false,
                          viewerTimezone: widget.currentUserProfile.timezone,
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Kept for future re-enable of grid-mode persistence.
  // ignore: unused_element
  Future<void> _persistMode(FeedViewMode nextMode) async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (profile == null) {
      return;
    }

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .upsert(profile.copyWith(feedViewMode: nextMode));
      ref.invalidate(appSessionProvider);
    } catch (_) {
      // Keep UI responsive even if this persistence attempt fails.
    }
  }

  String _resolveLocalDateKey(UserProfile profile) {
    try {
      return _timeService.localDateKeyForUtcInstant(
        instantUtc: DateTime.now().toUtc(),
        timezone: profile.timezone,
        dayStartHour: profile.dayStartHour,
      );
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    }
  }
}

class _FriendFeedTile extends StatefulWidget {
  const _FriendFeedTile({
    required this.profile,
    required this.taskRepository,
    required this.completionRepository,
    required this.localDateKeyResolver,
    required this.compact,
    required this.isSelf,
    required this.viewerTimezone,
  });

  final UserProfile profile;
  final TaskRepository taskRepository;
  final CompletionRepository completionRepository;
  final String Function(UserProfile profile) localDateKeyResolver;
  final bool compact;
  final bool isSelf;
  final String viewerTimezone;

  @override
  State<_FriendFeedTile> createState() => _FriendFeedTileState();
}

class _FriendFeedTileState extends State<_FriendFeedTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: widget.taskRepository.watchUserTasks(widget.profile.id),
      builder: (context, taskSnapshot) {
        if (!taskSnapshot.hasData) {
          return const _FeedSkeletonCard();
        }

        final activeTasks = taskSnapshot.data!
            .where((task) => task.active)
            .toList();
        final localDateKey = widget.localDateKeyResolver(widget.profile);

        return StreamBuilder<List<TaskCompletion>>(
          stream: widget.completionRepository.watchUserCompletionsForDate(
            userId: widget.profile.id,
            localDateKey: localDateKey,
          ),
          builder: (context, completionSnapshot) {
            final completions =
                completionSnapshot.data ?? const <TaskCompletion>[];
            final completionByTaskId = {
              for (final completion in completions)
                completion.taskId: completion,
            };
            final doneCount = completions
                .where((item) => item.status == CompletionStatus.done)
                .length;
            final totalCount = activeTasks.length;
            final firstTaskTitle = activeTasks.isEmpty
                ? 'No active task'
                : activeTasks.first.title;
            final summary = '$doneCount/$totalCount done • $firstTaskTitle';
            return _buildCard(
              context: context,
              summary: summary,
              doneCount: doneCount,
              totalCount: totalCount,
              activeTasks: activeTasks,
              completionByTaskId: completionByTaskId,
            );
          },
        );
      },
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String summary,
    required int doneCount,
    required int totalCount,
    required List<Task> activeTasks,
    required Map<String, TaskCompletion> completionByTaskId,
  }) {
    final profile = widget.profile;
    final modeLabel = profile.currentMode?.label ?? 'No mode';
    final isOnline = _isOnline(profile);
    final cardTitle = widget.isSelf ? 'My Tasks' : profile.displayName;
    final percent = totalCount == 0
        ? 0.0
        : (doneCount / totalCount).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: left=profile tap, right=expand toggle ──
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openProfile(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              UserAvatar(profile: profile, radius: 20),
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? Colors.green
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cardTitle,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                modeLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    tooltip: _expanded ? 'Collapse' : 'Expand',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(summary, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TaskCompletionBar(
              percent: percent,
              done: doneCount,
              total: totalCount,
              colorHint: profile.id,
            ),
            const SizedBox(height: 4),
            Text(
              'Day start: ${_formatDayStartForViewer(widget.viewerTimezone)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // ── Expandable section ──────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
                        Text(
                          widget.isSelf
                              ? 'This is you'
                              : _presenceLabel(profile),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isOnline
                                    ? Colors.green
                                    : Theme.of(context).hintColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (activeTasks.isEmpty)
                          const ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.inbox_outlined),
                            title: Text('No active tasks'),
                          )
                        else
                          ...activeTasks.map((task) {
                            final completion = completionByTaskId[task.id];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _statusIcon(completion?.status),
                                size: 20,
                              ),
                              title: Text(task.title),
                              subtitle: Text(_statusLabel(completion?.status)),
                              trailing: !widget.isSelf
                                  ? TaskVoteButton(
                                      ownerId: profile.id,
                                      taskId: task.id,
                                    )
                                  : null,
                            );
                          }),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _openProfile(context),
                            icon: const Icon(Icons.person_search_outlined),
                            label: Text(
                              widget.isSelf
                                  ? 'My Profile'
                                  : 'Show Full Profile',
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(CompletionStatus? status) {
    if (status == CompletionStatus.done) return Icons.check_circle;
    if (status == CompletionStatus.skipped) return Icons.skip_next;
    return Icons.radio_button_unchecked;
  }

  String _statusLabel(CompletionStatus? status) {
    if (status == CompletionStatus.done) return 'Done';
    if (status == CompletionStatus.skipped) return 'Skipped';
    return 'Pending';
  }

  String _formatDayStartForViewer(String viewerTimezone) {
    try {
      final ownerLocation = tz.getLocation(widget.profile.timezone);
      final now = tz.TZDateTime.now(ownerLocation);
      final ownerDayStart = tz.TZDateTime(
        ownerLocation,
        now.year,
        now.month,
        now.day,
        widget.profile.dayStartHour,
        0,
      );
      final viewerLocation = tz.getLocation(viewerTimezone);
      final viewerDayStart = tz.TZDateTime.from(ownerDayStart, viewerLocation);
      return DateFormat('hh:mm a').format(viewerDayStart);
    } catch (_) {
      return DateFormat(
        'hh:mm a',
      ).format(DateTime(2000, 1, 1, widget.profile.dayStartHour, 0));
    }
  }

  bool _isOnline(UserProfile profile) {
    if (!profile.isOnline) return false;
    final lastSeen = profile.lastSeenAtUtc;
    if (lastSeen == null) return false;
    return DateTime.now().toUtc().difference(lastSeen).inSeconds <= 70;
  }

  String _presenceLabel(UserProfile profile) {
    if (_isOnline(profile)) return 'Online now';
    final lastSeen = profile.lastSeenAtUtc;
    if (lastSeen == null) return 'Offline';
    final diff = DateTime.now().toUtc().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${diff.inDays}d ago';
  }

  void _openProfile(BuildContext context) {
    if (widget.isSelf) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PersonalProfileScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(profile: widget.profile),
      ),
    );
  }
}

class TaskCompletionBar extends StatelessWidget {
  const TaskCompletionBar({
    required this.percent,
    required this.done,
    required this.total,
    this.colorHint,
    super.key,
  });

  final double percent;
  final int done;
  final int total;

  /// Optional string (e.g. userId) used to derive a per-user accent color.
  final String? colorHint;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    final fillColor = colorHint != null
        ? _kFeedPalette[colorHint!.hashCode.abs() % _kFeedPalette.length]
        : (clamped >= 1.0
              ? const Color(0xFF22C55E)
              : clamped >= 0.5
              ? const Color(0xFF3B82F6)
              : const Color(0xFFF59E0B));

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            Flexible(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: clamped),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, child) {
                  return Stack(
                    children: [
                      Container(color: fillColor.withAlpha(30)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(color: fillColor),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(clamped * 100).round()}% \u2022 $done / $total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fillColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feed color palette ────────────────────────────────────────────────────────

const _kFeedPalette = <Color>[
  Color(0xFF0EA5E9), // sky
  Color(0xFF8B5CF6), // violet
  Color(0xFF10B981), // emerald
  Color(0xFFF43F5E), // rose
  Color(0xFF06B6D4), // cyan
  Color(0xFFF97316), // orange
  Color(0xFF6366F1), // indigo
  Color(0xFFEC4899), // pink
];

// ── Skeleton loading cards ─────────────────────────────────────────────────────

class _FeedSkeletonCard extends StatefulWidget {
  const _FeedSkeletonCard();

  @override
  State<_FeedSkeletonCard> createState() => _FeedSkeletonCardState();
}

class _FeedSkeletonCardState extends State<_FeedSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.onSurface.withAlpha(18);
    final highlightColor = Theme.of(
      context,
    ).colorScheme.onSurface.withAlpha(40);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final color = Color.lerp(baseColor, highlightColor, _ctrl.value)!;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 13,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 80,
                          height: 11,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeaderboardSkeletonCard extends StatefulWidget {
  const _LeaderboardSkeletonCard();

  @override
  State<_LeaderboardSkeletonCard> createState() =>
      _LeaderboardSkeletonCardState();
}

class _LeaderboardSkeletonCardState extends State<_LeaderboardSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.onSurface.withAlpha(18);
    final highlightColor = Theme.of(
      context,
    ).colorScheme.onSurface.withAlpha(40);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final color = Color.lerp(baseColor, highlightColor, _ctrl.value)!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 140,
                        height: 11,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
