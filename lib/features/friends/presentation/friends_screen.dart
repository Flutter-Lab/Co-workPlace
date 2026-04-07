import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/friends/domain/friend_connection.dart';
import 'package:coworkplace/features/friends/presentation/friend_profile_screen.dart';
import 'package:coworkplace/features/friends/domain/friend_request.dart';
import 'package:coworkplace/features/friends/providers/friend_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/core/cache/user_profile_cache.dart';
import 'package:coworkplace/core/widgets/user_avatar.dart';
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('Session error: $error'))),
      data: (session) {
        final userId = session.userId;
        final profile = session.profile;
        if (userId == null || profile == null) {
          return const Scaffold(
            body: Center(child: Text('Set up your profile first.')),
          );
        }

        if (Firebase.apps.isEmpty) {
          return const _FriendsNoDataRuntimeScreen();
        }

        final friendRepository = ref.watch(friendRepositoryProvider);

        return StreamBuilder<List<FriendRequest>>(
          stream: friendRepository.watchIncomingRequests(userId),
          builder: (context, incomingSnapshot) {
            return StreamBuilder<List<FriendRequest>>(
              stream: friendRepository.watchOutgoingRequests(userId),
              builder: (context, outgoingSnapshot) {
                return StreamBuilder<List<FriendConnection>>(
                  stream: friendRepository.watchFriends(userId),
                  builder: (context, friendsSnapshot) {
                    final incomingRequests =
                        incomingSnapshot.data ?? const <FriendRequest>[];
                    final outgoingRequests =
                        outgoingSnapshot.data ?? const <FriendRequest>[];
                    final friends =
                        friendsSnapshot.data ?? const <FriendConnection>[];
                    final pendingCount = incomingRequests.length;

                    return Scaffold(
                      appBar: AppBar(
                        title: const Text('Friends'),
                        actions: [
                          Badge(
                            isLabelVisible: pendingCount > 0,
                            label: Text('$pendingCount'),
                            child: IconButton(
                              tooltip: 'Friend Requests',
                              icon: const Icon(Icons.inbox_outlined),
                              onPressed: () => _showRequestsSheet(
                                context,
                                userId,
                                incomingRequests,
                                outgoingRequests,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      floatingActionButton: FloatingActionButton.extended(
                        onPressed: () => _showAddFriendSheet(context, userId),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add Friend'),
                      ),
                      body: friendsSnapshot.hasError
                          ? Center(
                              child: Text(
                                'Failed to load friends: ${friendsSnapshot.error}',
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (friends.isEmpty)
                                  Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.people_outline),
                                      title: const Text('No friends yet'),
                                      subtitle: const Text(
                                        'Tap "Add Friend" to start building your social layer.',
                                      ),
                                    ),
                                  )
                                else
                                  _ProfileLookupList(
                                    ids: friends
                                        .map((f) => f.friendUserId)
                                        .toList(),
                                    emptyTitle: 'No friends yet',
                                    emptySubtitle:
                                        'Tap "Add Friend" to start building your social layer.',
                                    itemBuilder: (otherProfile) {
                                      final friend = friends.firstWhere(
                                        (item) =>
                                            item.friendUserId ==
                                            otherProfile.id,
                                      );
                                      return Card(
                                        child: ListTile(
                                          onTap: () => _openFullProfile(
                                            otherProfile,
                                            friend,
                                          ),
                                          leading: _PresenceAvatar(
                                            profile: otherProfile,
                                            radius: 22,
                                          ),
                                          title: Text(otherProfile.displayName),
                                          subtitle: Text(
                                            '@${otherProfile.username} • ${_presenceLabel(otherProfile)}',
                                          ),
                                          trailing: PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'view') {
                                                _openFullProfile(
                                                  otherProfile,
                                                  friend,
                                                );
                                              }
                                              if (value == 'remove') {
                                                _removeFriend(
                                                  userId: userId,
                                                  friendUserId: otherProfile.id,
                                                );
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'view',
                                                child: Text('View profile'),
                                              ),
                                              PopupMenuItem(
                                                value: 'remove',
                                                child: Text('Remove friend'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(height: 80),
                              ],
                            ),
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

  void _showAddFriendSheet(BuildContext context, String userId) {
    _usernameController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a Friend',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Send a request using an exact username.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'friend_username',
                      border: OutlineInputBorder(),
                      prefixText: '@',
                    ),
                    onSubmitted: (_) {
                      _sendRequest(currentUserId: userId);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSendingRequest
                          ? null
                          : () {
                              _sendRequest(currentUserId: userId);
                              Navigator.of(sheetContext).pop();
                            },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(
                        _isSendingRequest
                            ? 'Sending...'
                            : 'Send Friend Request',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRequestsSheet(
    BuildContext context,
    String userId,
    List<FriendRequest> incoming,
    List<FriendRequest> outgoing,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.onSurface.withAlpha(50),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Friend Requests',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _SectionTitle(title: 'Incoming', count: incoming.length),
                const SizedBox(height: 8),
                _ProfileLookupList(
                  ids: incoming.map((r) => r.otherUserId).toList(),
                  emptyTitle: 'No incoming requests',
                  emptySubtitle:
                      'When someone adds you, the request will appear here.',
                  itemBuilder: (otherProfile) {
                    final request = incoming.firstWhere(
                      (r) => r.otherUserId == otherProfile.id,
                    );
                    return Card(
                      child: ListTile(
                        leading: UserAvatar(profile: otherProfile, radius: 20),
                        title: Text(otherProfile.displayName),
                        subtitle: Text(
                          '@${otherProfile.username} • ${_formatDate(request.createdAtUtc)}',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Accept',
                              onPressed: () {
                                _acceptRequest(
                                  userId: userId,
                                  fromUserId: otherProfile.id,
                                );
                                Navigator.of(sheetContext).maybePop();
                              },
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: () {
                                _rejectRequest(
                                  userId: userId,
                                  fromUserId: otherProfile.id,
                                );
                                Navigator.of(sheetContext).maybePop();
                              },
                              icon: const Icon(
                                Icons.cancel_outlined,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _SectionTitle(title: 'Outgoing', count: outgoing.length),
                const SizedBox(height: 8),
                _ProfileLookupList(
                  ids: outgoing.map((r) => r.otherUserId).toList(),
                  emptyTitle: 'No pending requests',
                  emptySubtitle: 'Requests you send will appear here.',
                  itemBuilder: (otherProfile) {
                    final request = outgoing.firstWhere(
                      (r) => r.otherUserId == otherProfile.id,
                    );
                    return Card(
                      child: ListTile(
                        leading: UserAvatar(profile: otherProfile, radius: 20),
                        title: Text(otherProfile.displayName),
                        subtitle: Text(
                          '@${otherProfile.username} • ${_formatDate(request.createdAtUtc)}',
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            _cancelRequest(
                              userId: userId,
                              toUserId: otherProfile.id,
                            );
                            Navigator.of(sheetContext).maybePop();
                          },
                          child: const Text('Cancel'),
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

  Future<void> _acceptRequest({
    required String userId,
    required String fromUserId,
  }) async {
    try {
      await ref
          .read(friendRepositoryProvider)
          .acceptFriendRequest(userId: userId, fromUserId: fromUserId);
      _showSnack('Friend request accepted.');
    } catch (error) {
      _showSnack('Failed to accept request: $error');
    }
  }

  Future<void> _rejectRequest({
    required String userId,
    required String fromUserId,
  }) async {
    try {
      await ref
          .read(friendRepositoryProvider)
          .rejectFriendRequest(userId: userId, fromUserId: fromUserId);
      _showSnack('Friend request rejected.');
    } catch (error) {
      _showSnack('Failed to reject request: $error');
    }
  }

  Future<void> _cancelRequest({
    required String userId,
    required String toUserId,
  }) async {
    try {
      await ref
          .read(friendRepositoryProvider)
          .cancelOutgoingRequest(userId: userId, toUserId: toUserId);
      _showSnack('Friend request canceled.');
    } catch (error) {
      _showSnack('Failed to cancel request: $error');
    }
  }

  Future<void> _removeFriend({
    required String userId,
    required String friendUserId,
  }) async {
    try {
      await ref
          .read(friendRepositoryProvider)
          .removeFriend(userId: userId, friendUserId: friendUserId);
      _showSnack('Friend removed.');
    } catch (error) {
      _showSnack('Failed to remove friend: $error');
    }
  }

  String _presenceLabel(UserProfile p) {
    final lastSeen = p.lastSeenAtUtc;
    if (p.isOnline &&
        lastSeen != null &&
        DateTime.now().toUtc().difference(lastSeen).inSeconds <= 70) {
      return 'Online now';
    }
    if (lastSeen != null) {
      final diff = DateTime.now().toUtc().difference(lastSeen);
      if (diff.inSeconds > 70 && diff.inMinutes < 10) return 'Idle';
      if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    }
    return p.currentMode?.label ?? 'Offline';
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

  String _formatDate(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

    final cache = ref.watch(userProfileCacheProvider);
    return FutureBuilder<List<UserProfile>>(
      future: cache.getByIds(ids),
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
        return Column(children: profiles.map(itemBuilder).toList());
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
            subtitle: Text(
              'Friend data becomes available after Firebase is initialized.',
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar widget that overlays a coloured presence dot.
class _PresenceAvatar extends StatelessWidget {
  const _PresenceAvatar({required this.profile, required this.radius});

  final UserProfile profile;
  final double radius;

  static Color? _dotColor(UserProfile p) {
    final lastSeen = p.lastSeenAtUtc;
    if (p.isOnline &&
        lastSeen != null &&
        DateTime.now().toUtc().difference(lastSeen).inSeconds <= 70) {
      return const Color(0xFF22C55E); // green — online
    }
    if (lastSeen != null) {
      final diff = DateTime.now().toUtc().difference(lastSeen);
      if (diff.inSeconds > 70 && diff.inMinutes < 10) {
        return const Color(0xFFF59E0B); // amber — idle
      }
    }
    return null; // no dot — offline
  }

  @override
  Widget build(BuildContext context) {
    final dot = _dotColor(profile);
    final dotSize = radius * 0.5;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        UserAvatar(profile: profile, radius: radius),
        if (dot != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
