import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/features/friends/domain/friend_connection.dart';
import 'package:coworkplace/features/friends/presentation/friend_profile_screen.dart';
import 'package:coworkplace/features/friends/providers/friend_providers.dart';
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Session error: $error')),
      data: (session) {
        final profile = session.profile;
        final userId = session.userId;
        if (profile == null || userId == null) {
          return const Center(child: Text('Set up your profile first.'));
        }

        if (Firebase.apps.isEmpty) {
          return const Center(
            child: Text('Feed becomes available after Firebase is initialized.'),
          );
        }

        final friendRepository = ref.watch(friendRepositoryProvider);
        final profileRepository = ref.watch(userProfileRepositoryProvider);
        final taskRepository = ref.watch(taskRepositoryProvider);
        final completionRepository = ref.watch(completionRepositoryProvider);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.dynamic_feed_outlined),
                title: const Text('Friends Feed'),
                subtitle: Text(
                  'Quick social snapshot in ${profile.feedViewMode.name} mode.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FriendFeedSection(
              profileRepository: profileRepository,
              taskRepository: taskRepository,
              completionRepository: completionRepository,
              friendStream: friendRepository.watchFriends(userId),
              currentFeedViewMode: profile.feedViewMode,
            ),
          ],
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
    required this.currentFeedViewMode,
  });

  final UserProfileRepository profileRepository;
  final TaskRepository taskRepository;
  final CompletionRepository completionRepository;
  final Stream<List<FriendConnection>> friendStream;
  final FeedViewMode currentFeedViewMode;

  @override
  ConsumerState<_FriendFeedSection> createState() => _FriendFeedSectionState();
}

class _FriendFeedSectionState extends ConsumerState<_FriendFeedSection> {
  static const _timeService = DayStartTimeService();
  late FeedViewMode _mode = widget.currentFeedViewMode;

  @override
  void didUpdateWidget(covariant _FriendFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentFeedViewMode != widget.currentFeedViewMode) {
      _mode = widget.currentFeedViewMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Today',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SegmentedButton<FeedViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: FeedViewMode.list,
                      icon: Icon(Icons.view_list),
                      label: Text('List'),
                    ),
                    ButtonSegment(
                      value: FeedViewMode.grid,
                      icon: Icon(Icons.grid_view),
                      label: Text('Grid'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    final nextMode = selection.first;
                    setState(() {
                      _mode = nextMode;
                    });
                    _persistMode(nextMode);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
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

                return FutureBuilder<List<UserProfile>>(
                  future: widget.profileRepository.getByIds(
                    friends.map((friend) => friend.friendUserId),
                  ),
                  builder: (context, profileSnapshot) {
                    if (profileSnapshot.hasError) {
                      return Text('Failed to load friend profiles: ${profileSnapshot.error}');
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
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

  Future<void> _persistMode(FeedViewMode nextMode) async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (profile == null) {
      return;
    }

    try {
      await ref.read(userProfileRepositoryProvider).upsert(
            profile.copyWith(feedViewMode: nextMode),
          );
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
  });

  final UserProfile profile;
  final TaskRepository taskRepository;
  final CompletionRepository completionRepository;
  final String Function(UserProfile profile) localDateKeyResolver;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: taskRepository.watchUserTasks(profile.id),
      builder: (context, taskSnapshot) {
        if (!taskSnapshot.hasData) {
          return _buildCard(context, 'Loading tasks...', 'Checking latest state...');
        }

        final activeTasks = taskSnapshot.data!.where((task) => task.active).toList();
        final localDateKey = localDateKeyResolver(profile);

        return StreamBuilder<List<TaskCompletion>>(
          stream: completionRepository.watchUserCompletionsForDate(
            userId: profile.id,
            localDateKey: localDateKey,
          ),
          builder: (context, completionSnapshot) {
            final completions = completionSnapshot.data ?? const <TaskCompletion>[];
            final doneCount =
                completions.where((item) => item.status == CompletionStatus.done).length;
            final totalCount = activeTasks.length;
            final firstTaskTitle = activeTasks.isEmpty ? 'No active task' : activeTasks.first.title;
            final summary = '$doneCount/$totalCount done • $firstTaskTitle';
            return _buildCard(
              context,
              profile.displayName,
              '${profile.currentMode?.label ?? 'No mode'}\n$summary',
              onTap: () => _showQuickProfilePopup(
                context,
                summary: summary,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    if (compact) {
      return Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
                const Spacer(),
                TextButton(
                  onPressed: onTap,
                  child: const Text('View'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(title.isEmpty ? '?' : title[0].toUpperCase()),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: TextButton(
          onPressed: onTap,
          child: const Text('View'),
        ),
      ),
    );
  }

  Future<void> _showQuickProfilePopup(
    BuildContext context, {
    required String summary,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(profile.displayName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${profile.username}'),
              const SizedBox(height: 6),
              Text('Mode: ${profile.currentMode?.label ?? 'No mode'}'),
              const SizedBox(height: 6),
              Text(summary),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FriendProfileScreen(profile: profile),
                  ),
                );
              },
              child: const Text('Show Full Profile'),
            ),
          ],
        );
      },
    );
  }
}
