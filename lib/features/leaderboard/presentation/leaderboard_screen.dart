import 'package:coworkplace/features/friends/providers/friend_providers.dart';
import 'package:coworkplace/features/leaderboard/data/score_service.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _service = ScoreService();
  String _period = 'weekly';

  String _periodIdFor(String period) {
    return period == 'weekly'
        ? _service.weekPeriodId(DateTime.now().toUtc())
        : period == 'monthly'
        ? _service.monthPeriodId(DateTime.now().toUtc())
        : _service.alltimePeriodId();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final myId = session?.userId;

    final periodId = _periodIdFor(_period);

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ToggleButtons(
              isSelected: [
                _period == 'weekly',
                _period == 'monthly',
                _period == 'alltime',
              ],
              onPressed: (i) {
                setState(() {
                  _period = i == 0
                      ? 'weekly'
                      : i == 1
                      ? 'monthly'
                      : 'alltime';
                });
              },
              children: const [
                Text('Weekly'),
                Text('Monthly'),
                Text('All-time'),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (myId == null)
                  return const Center(
                    child: Text('Sign in to view leaderboard'),
                  );

                final friendRepo = ref.read(friendRepositoryProvider);

                // Stream the user's friends, then fetch scores for that friend set.
                return StreamBuilder<List<dynamic>>(
                  stream: friendRepo.watchFriends(myId),
                  builder: (context, friendSnap) {
                    if (friendSnap.hasError)
                      return Center(child: Text('Failed: ${friendSnap.error}'));
                    if (!friendSnap.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final friends = friendSnap.data!;
                    final friendIds = friends
                        .map((f) => f.friendUserId as String)
                        .toSet();
                    friendIds.add(myId); // include self

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _service.getScoresForUsers(
                        periodId: periodId,
                        userIds: friendIds,
                      ),
                      builder: (context, scoresSnap) {
                        if (scoresSnap.hasError)
                          return Center(
                            child: Text('Failed: ${scoresSnap.error}'),
                          );
                        if (scoresSnap.connectionState ==
                            ConnectionState.waiting)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );

                        final docs =
                            scoresSnap.data ?? <Map<String, dynamic>>[];
                        if (docs.isEmpty)
                          return const Center(
                            child: Text('No leaderboard data yet.'),
                          );

                        final userIds = docs
                            .map((d) => d['userId'] as String)
                            .toList();
                        final repo = ref.read(userProfileRepositoryProvider);

                        return FutureBuilder<List<UserProfile>>(
                          future: repo.getByIds(userIds),
                          builder: (context, profilesSnap) {
                            if (profilesSnap.hasError)
                              return Center(
                                child: Text('Failed: ${profilesSnap.error}'),
                              );
                            if (profilesSnap.connectionState ==
                                ConnectionState.waiting)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );

                            final profiles =
                                profilesSnap.data ?? <UserProfile>[];
                            final profileById = {
                              for (var p in profiles) p.id: p,
                            };

                            // Build ranked list UI
                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = docs[index];
                                final userId = item['userId'] as String;
                                final points = item['points'] as int;
                                final profile = profileById[userId];

                                final title = profile?.displayName ?? userId;
                                final subtitle = profile != null
                                    ? '@${profile.username} • $points pts'
                                    : '$points pts';

                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      profile?.displayName.isNotEmpty == true
                                          ? profile!.displayName[0]
                                                .toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  title: Text(title),
                                  subtitle: Text(subtitle),
                                  trailing: Text('$points'),
                                  selected: myId == userId,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
