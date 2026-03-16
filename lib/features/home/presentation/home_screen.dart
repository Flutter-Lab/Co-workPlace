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
import 'package:coworkplace/features/tasks/data/completion_repository.dart';
import 'package:coworkplace/features/tasks/data/task_repository.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';
import 'package:coworkplace/features/tasks/providers/task_providers.dart';
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.35),
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
                        ).colorScheme.onSurface.withOpacity(0.82),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
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

class _LeaderboardCard extends ConsumerWidget {
  const _LeaderboardCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final myId = session?.userId;
    if (myId == null) return const SizedBox.shrink();

    final friendRepo = ref.read(friendRepositoryProvider);
    final profileRepo = ref.read(userProfileRepositoryProvider);
    final service = ScoreService();
    final periodId = service.weekPeriodId(DateTime.now().toUtc());

    return StreamBuilder<List<dynamic>>(
      stream: friendRepo.watchFriends(myId),
      builder: (context, friendSnap) {
        if (friendSnap.hasError) return const SizedBox.shrink();
        if (!friendSnap.hasData) return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        );

        final friends = friendSnap.data!;
        final friendIds = friends.map((f) => f.friendUserId as String).toSet();
        friendIds.add(myId);

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: service.getScoresForUsers(periodId: periodId, userIds: friendIds),
          builder: (context, scoresSnap) {
            if (scoresSnap.hasError) return const SizedBox.shrink();
            if (scoresSnap.connectionState == ConnectionState.waiting) return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );

            final docs = scoresSnap.data ?? <Map<String, dynamic>>[];
            if (docs.isEmpty) {
              return Card(
                child: ListTile(
                  title: const Text('Weekly Top'),
                  subtitle: const Text('No leaderboard data yet.'),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
                  },
                ),
              );
            }

            final top = docs.first;
            final topId = top['userId'] as String;
            final points = top['points'] as int;

            return FutureBuilder<List<UserProfile>>(
              future: profileRepo.getByIds([topId]),
              builder: (context, profilesSnap) {
                if (profilesSnap.connectionState == ConnectionState.waiting) return const Card(
                  child: ListTile(
                    title: Text('Weekly Top'),
                    subtitle: Text('Loading...'),
                  ),
                );

                final profiles = profilesSnap.data ?? <UserProfile>[];
                final profile = profiles.isNotEmpty ? profiles.first : null;
                final display = profile?.displayName ?? topId;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(profile != null && profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?'),
                    ),
                    title: const Text('Weekly Top'),
                    subtitle: Text(display),
                    trailing: Text('$points pts'),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
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
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  );
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
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      );
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

class _FriendFeedTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: taskRepository.watchUserTasks(profile.id),
      builder: (context, taskSnapshot) {
        if (!taskSnapshot.hasData) {
          return const Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('Loading tasks...'),
              subtitle: Text('Checking latest state...'),
            ),
          );
        }

        final activeTasks = taskSnapshot.data!
            .where((task) => task.active)
            .toList();
        final localDateKey = localDateKeyResolver(profile);

        return StreamBuilder<List<TaskCompletion>>(
          stream: completionRepository.watchUserCompletionsForDate(
            userId: profile.id,
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
            return _buildExpandableCard(
              context: context,
              summary: summary,
              activeTasks: activeTasks,
              completionByTaskId: completionByTaskId,
            );
          },
        );
      },
    );
  }

  Widget _buildExpandableCard({
    required BuildContext context,
    required String summary,
    required List<Task> activeTasks,
    required Map<String, TaskCompletion> completionByTaskId,
  }) {
    final modeLabel = profile.currentMode?.label ?? 'No mode';
    final isOnline = _isOnline(profile);
    final cardTitle = isSelf ? 'My Tasks' : profile.displayName;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              child: Text(
                profile.displayName.isEmpty
                    ? '?'
                    : profile.displayName[0].toUpperCase(),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(cardTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(modeLabel),
            const SizedBox(height: 6),
            Text(summary),
            const SizedBox(height: 8),
            // Progress bar: completed vs total
            Builder(
              builder: (context) {
                final doneCount = completionByTaskId.values
                    .where((c) => c.status == CompletionStatus.done)
                    .length;
                final totalCount = activeTasks.length;
                final percent = totalCount == 0
                    ? 0.0
                    : (doneCount / totalCount).clamp(0.0, 1.0);
                return TaskCompletionBar(
                  percent: percent,
                  done: doneCount,
                  total: totalCount,
                );
              },
            ),
            const SizedBox(height: 6),
            Text('Day start: ${_formatDayStartForViewer(viewerTimezone)}'),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                isSelf ? 'This is you' : _presenceLabel(profile),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isOnline ? Colors.green : Theme.of(context).hintColor,
                ),
              ),
            ),
          ),
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
                leading: Icon(_statusIcon(completion?.status), size: 20),
                title: Text(task.title),
                subtitle: Text(_statusLabel(completion?.status)),
              );
            }),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => _openProfile(context),
              icon: const Icon(Icons.person_search_outlined),
              label: Text(isSelf ? 'My Profile' : 'Show Full Profile'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(CompletionStatus? status) {
    if (status == CompletionStatus.done) {
      return Icons.check_circle;
    }
    if (status == CompletionStatus.skipped) {
      return Icons.skip_next;
    }
    return Icons.radio_button_unchecked;
  }

  String _statusLabel(CompletionStatus? status) {
    if (status == CompletionStatus.done) {
      return 'Done';
    }
    if (status == CompletionStatus.skipped) {
      return 'Skipped';
    }
    return 'Pending';
  }

  String _formatDayStartForViewer(String viewerTimezone) {
    try {
      final ownerLocation = tz.getLocation(profile.timezone);
      final now = tz.TZDateTime.now(ownerLocation);
      final ownerDayStart = tz.TZDateTime(
        ownerLocation,
        now.year,
        now.month,
        now.day,
        profile.dayStartHour,
        0,
      );
      final viewerLocation = tz.getLocation(viewerTimezone);
      final viewerDayStart = tz.TZDateTime.from(ownerDayStart, viewerLocation);
      final formatted = DateFormat('hh:mm a').format(viewerDayStart);
      return formatted;
    } catch (_) {
      return DateFormat(
        'hh:mm a',
      ).format(DateTime(2000, 1, 1, profile.dayStartHour, 0));
    }
  }

  bool _isOnline(UserProfile profile) {
    if (!profile.isOnline) {
      return false;
    }
    final lastSeen = profile.lastSeenAtUtc;
    if (lastSeen == null) {
      return false;
    }
    return DateTime.now().toUtc().difference(lastSeen).inSeconds <= 70;
  }

  String _presenceLabel(UserProfile profile) {
    if (_isOnline(profile)) {
      return 'Online now';
    }

    final lastSeen = profile.lastSeenAtUtc;
    if (lastSeen == null) {
      return 'Offline';
    }

    final diff = DateTime.now().toUtc().difference(lastSeen);
    if (diff.inMinutes < 1) {
      return 'Last seen just now';
    }
    if (diff.inHours < 1) {
      return 'Last seen ${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return 'Last seen ${diff.inHours}h ago';
    }
    return 'Last seen ${diff.inDays}d ago';
  }

  void _openProfile(BuildContext context) {
    if (isSelf) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PersonalProfileScreen()),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(profile: profile),
      ),
    );
  }
}

class TaskCompletionBar extends StatelessWidget {
  const TaskCompletionBar({
    required this.percent,
    required this.done,
    required this.total,
    super.key,
  });

  final double percent;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.06);
    final fillColor = percent >= 1.0
        ? Colors.green
        : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: percent),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, value, child) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(percent * 100).round()}% • $done / $total',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
