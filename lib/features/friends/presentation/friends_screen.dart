import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:coworkplace/features/friends/domain/friend_connection.dart';
import 'package:coworkplace/features/friends/presentation/friend_profile_screen.dart';
import 'package:coworkplace/features/friends/domain/friend_request.dart';
import 'package:coworkplace/features/friends/providers/friend_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/features/tasks/domain/task.dart';
import 'package:coworkplace/features/tasks/domain/task_completion.dart';
import 'package:coworkplace/features/tasks/providers/task_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  static const _timeService = DayStartTimeService();
  final _usernameController = TextEditingController();
  bool _isSendingRequest = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Session error: $error')),
      data: (session) {
        final userId = session.userId;
        final profile = session.profile;
        if (userId == null || profile == null) {
          return const Center(child: Text('Set up your profile first.'));
        }

        if (Firebase.apps.isEmpty) {
          return const _FriendsNoDataRuntimeScreen();
        }

        final friendRepository = ref.watch(friendRepositoryProvider);

        return StreamBuilder<List<FriendRequest>>(
          stream: friendRepository.watchIncomingRequests(userId),
          builder: (context, incomingSnapshot) {
            if (incomingSnapshot.hasError) {
              return Center(child: Text('Failed to load requests: ${incomingSnapshot.error}'));
            }

            return StreamBuilder<List<FriendRequest>>(
              stream: friendRepository.watchOutgoingRequests(userId),
              builder: (context, outgoingSnapshot) {
                if (outgoingSnapshot.hasError) {
                  return Center(child: Text('Failed to load outgoing requests: ${outgoingSnapshot.error}'));
                }

                return StreamBuilder<List<FriendConnection>>(
                  stream: friendRepository.watchFriends(userId),
                  builder: (context, friendsSnapshot) {
                    if (friendsSnapshot.hasError) {
                      return Center(child: Text('Failed to load friends: ${friendsSnapshot.error}'));
                    }

                    final incomingRequests = incomingSnapshot.data ?? const <FriendRequest>[];
                    final outgoingRequests = outgoingSnapshot.data ?? const <FriendRequest>[];
                    final friends = friendsSnapshot.data ?? const <FriendConnection>[];

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Find friends', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                  'Send a request using an exact username. Full search and richer discovery come next.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _usernameController,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                    hintText: 'friend_username',
                                    border: OutlineInputBorder(),
                                    prefixText: '@',
                                  ),
                                  onSubmitted: (_) => _sendRequest(currentUserId: userId),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _isSendingRequest ? null : () => _sendRequest(currentUserId: userId),
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: Text(_isSendingRequest ? 'Sending...' : 'Send Friend Request'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(title: 'Incoming Requests', count: incomingRequests.length),
                        const SizedBox(height: 8),
                        _ProfileLookupList(
                          ids: incomingRequests.map((request) => request.otherUserId).toList(),
                          emptyTitle: 'No incoming requests',
                          emptySubtitle: 'When someone adds you, the request will appear here.',
                          itemBuilder: (otherProfile) {
                            final request = incomingRequests.firstWhere(
                              (item) => item.otherUserId == otherProfile.id,
                            );
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(otherProfile.displayName.isEmpty ? '?' : otherProfile.displayName[0].toUpperCase()),
                                ),
                                title: Text(otherProfile.displayName),
                                subtitle: Text('@${otherProfile.username} • ${_formatDate(request.createdAtUtc)}'),
                                isThreeLine: false,
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      tooltip: 'Accept',
                                      onPressed: () => _acceptRequest(userId: userId, fromUserId: otherProfile.id),
                                      icon: const Icon(Icons.check_circle_outline),
                                    ),
                                    IconButton(
                                      tooltip: 'Reject',
                                      onPressed: () => _rejectRequest(userId: userId, fromUserId: otherProfile.id),
                                      icon: const Icon(Icons.cancel_outlined),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(title: 'Outgoing Requests', count: outgoingRequests.length),
                        const SizedBox(height: 8),
                        _ProfileLookupList(
                          ids: outgoingRequests.map((request) => request.otherUserId).toList(),
                          emptyTitle: 'No pending requests',
                          emptySubtitle: 'Requests you send will stay here until accepted or canceled.',
                          itemBuilder: (otherProfile) {
                            final request = outgoingRequests.firstWhere(
                              (item) => item.otherUserId == otherProfile.id,
                            );
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(otherProfile.displayName.isEmpty ? '?' : otherProfile.displayName[0].toUpperCase()),
                                ),
                                title: Text(otherProfile.displayName),
                                subtitle: Text('@${otherProfile.username} • ${_formatDate(request.createdAtUtc)}'),
                                trailing: TextButton(
                                  onPressed: () => _cancelRequest(userId: userId, toUserId: otherProfile.id),
                                  child: const Text('Cancel'),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _SectionTitle(title: 'Friends', count: friends.length),
                        const SizedBox(height: 8),
                        _ProfileLookupList(
                          ids: friends.map((friend) => friend.friendUserId).toList(),
                          emptyTitle: 'No friends yet',
                          emptySubtitle: 'Add people by username to start building your social layer.',
                          itemBuilder: (otherProfile) {
                            final friend = friends.firstWhere(
                              (item) => item.friendUserId == otherProfile.id,
                            );
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(otherProfile.displayName.isEmpty ? '?' : otherProfile.displayName[0].toUpperCase()),
                                ),
                                title: Text(otherProfile.displayName),
                                subtitle: Text(
                                  '@${otherProfile.username} • ${otherProfile.currentMode?.label ?? 'No mode set'}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'view') {
                                      _showFriendQuickProfile(otherProfile, friend);
                                    }
                                    if (value == 'remove') {
                                      _removeFriend(userId: userId, friendUserId: otherProfile.id);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(value: 'view', child: Text('View profile')),
                                    PopupMenuItem(value: 'remove', child: Text('Remove friend')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _sendRequest({required String currentUserId}) async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty) {
      _showSnack('Enter a username first.');
      return;
    }

    setState(() {
      _isSendingRequest = true;
    });

    try {
      final profileRepository = ref.read(userProfileRepositoryProvider);
      final friendRepository = ref.read(friendRepositoryProvider);
      final targetProfile = await profileRepository.findByUsername(username);

      if (targetProfile == null) {
        throw StateError('No user found with @$username.');
      }

      await friendRepository.sendFriendRequest(
        fromUserId: currentUserId,
        toUserId: targetProfile.id,
      );

      _usernameController.clear();
      _showSnack('Friend request sent to @${targetProfile.username}.');
    } catch (error) {
      _showSnack('Failed to send request: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });
      }
    }
  }

  Future<void> _acceptRequest({required String userId, required String fromUserId}) async {
    try {
      await ref.read(friendRepositoryProvider).acceptFriendRequest(
        userId: userId,
        fromUserId: fromUserId,
      );
      _showSnack('Friend request accepted.');
    } catch (error) {
      _showSnack('Failed to accept request: $error');
    }
  }

  Future<void> _rejectRequest({required String userId, required String fromUserId}) async {
    try {
      await ref.read(friendRepositoryProvider).rejectFriendRequest(
        userId: userId,
        fromUserId: fromUserId,
      );
      _showSnack('Friend request rejected.');
    } catch (error) {
      _showSnack('Failed to reject request: $error');
    }
  }

  Future<void> _cancelRequest({required String userId, required String toUserId}) async {
    try {
      await ref.read(friendRepositoryProvider).cancelOutgoingRequest(
        userId: userId,
        toUserId: toUserId,
      );
      _showSnack('Friend request canceled.');
    } catch (error) {
      _showSnack('Failed to cancel request: $error');
    }
  }

  Future<void> _removeFriend({required String userId, required String friendUserId}) async {
    try {
      await ref.read(friendRepositoryProvider).removeFriend(
        userId: userId,
        friendUserId: friendUserId,
      );
      _showSnack('Friend removed.');
    } catch (error) {
      _showSnack('Failed to remove friend: $error');
    }
  }

  Future<void> _showFriendQuickProfile(UserProfile profile, FriendConnection connection) async {
    final taskRepository = ref.read(taskRepositoryProvider);
    final completionRepository = ref.read(completionRepositoryProvider);
    final localDateKey = _safeLocalDateKey(profile);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(profile.displayName),
          content: StreamBuilder<List<Task>>(
            stream: taskRepository.watchUserTasks(profile.id),
            builder: (context, taskSnapshot) {
              final activeTasks = (taskSnapshot.data ?? const <Task>[])
                  .where((task) => task.active)
                  .toList();

              return StreamBuilder<List<TaskCompletion>>(
                stream: completionRepository.watchUserCompletionsForDate(
                  userId: profile.id,
                  localDateKey: localDateKey,
                ),
                builder: (context, completionSnapshot) {
                  final completions = completionSnapshot.data ?? const <TaskCompletion>[];
                  final doneCount = completions
                      .where((item) => item.status == CompletionStatus.done)
                      .length;
                  final summary =
                      '$doneCount/${activeTasks.length} done • ${activeTasks.isEmpty ? 'No active task' : activeTasks.first.title}';

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@${profile.username}'),
                      const SizedBox(height: 6),
                      Text('Mode: ${profile.currentMode?.label ?? 'No mode set'}'),
                      const SizedBox(height: 6),
                      Text('Timezone: ${profile.timezone} • Owner day: $localDateKey'),
                      const SizedBox(height: 6),
                      Text('Friends since: ${_formatDate(connection.createdAtUtc)}'),
                      const SizedBox(height: 6),
                      Text(summary),
                    ],
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openFullProfile(profile, connection);
              },
              child: const Text('Show Full Profile'),
            ),
          ],
        );
      },
    );
  }

  void _openFullProfile(UserProfile profile, FriendConnection connection) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(
          profile: profile,
          friendSince: connection.createdAtUtc,
        ),
      ),
    );
  }

  String _safeLocalDateKey(UserProfile profile) {
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

  String _formatDate(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileLookupList extends ConsumerWidget {
  const _ProfileLookupList({
    required this.ids,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.itemBuilder,
  });

  final List<String> ids;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget Function(UserProfile profile) itemBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ids.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.inbox_outlined),
          title: Text(emptyTitle),
          subtitle: Text(emptySubtitle),
        ),
      );
    }

    final profileRepository = ref.watch(userProfileRepositoryProvider);
    return FutureBuilder<List<UserProfile>>(
      future: profileRepository.getByIds(ids),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Failed to load profiles'),
              subtitle: Text('${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Loading profiles...'),
            ),
          );
        }

        final profiles = snapshot.data!;
        return Column(
          children: profiles.map(itemBuilder).toList(),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text('$count'),
      ],
    );
  }
}

class _FriendsNoDataRuntimeScreen extends StatelessWidget {
  const _FriendsNoDataRuntimeScreen();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.people_outline),
            title: Text('Friends'),
            subtitle: Text('Friend data becomes available after Firebase is initialized.'),
          ),
        ),
      ],
    );
  }
}
