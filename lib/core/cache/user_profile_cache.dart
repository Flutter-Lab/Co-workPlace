import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coworkplace/features/profile/data/user_profile_repository.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';

class UserProfileCache {
  UserProfileCache(this._box, this._repo);

  final Box _box;
  final UserProfileRepository _repo;

  // TTL for cached profiles before background refresh
  static const Duration _ttl = Duration(minutes: 15);

  Future<List<UserProfile>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return <UserProfile>[];

    final cached = <String, UserProfile>{};
    final toFetch = <String>[];

    for (final id in ids) {
      final raw = _box.get(id);
      if (raw is Map<String, dynamic>) {
        try {
          // if cached map contains _cachedAt, check TTL
          final cachedAtRaw = raw['_cachedAt'] as String?;
          if (cachedAtRaw != null) {
            final cachedAt = DateTime.tryParse(cachedAtRaw)?.toUtc();
            if (cachedAt != null) {
              final age = DateTime.now().toUtc().difference(cachedAt);
              if (age <= _ttl) {
                cached[id] = UserProfile.fromMap(raw);
                continue;
              } else {
                // stale: include cached now but trigger background refresh
                cached[id] = UserProfile.fromMap(raw);
                toFetch.add(id);
                continue;
              }
            }
          }

          // no cachedAt or parse failed -> treat as missing
          cached[id] = UserProfile.fromMap(raw);
          toFetch.add(id);
          continue;
        } catch (_) {
          // fall through to fetch
        }
      }
      toFetch.add(id);
    }

    // If nothing to fetch, return cached in requested order
    if (toFetch.isEmpty) {
      return ids.map((i) => cached[i]!).toList();
    }

    // Fetch missing/stale in background, but return cached results immediately when available
    // Use a detached future to refresh without awaiting.
    _refreshAndStore(toFetch);

    return ids.map((i) => cached[i] ?? _fallbackProfile(i)).toList();
  }

  Future<void> _refreshAndStore(List<String> ids) async {
    try {
      final fetched = await _repo.getByIds(ids);
      for (final p in fetched) {
        final map = p.toMap();
        map['_cachedAt'] = DateTime.now().toUtc().toIso8601String();
        try {
          _box.put(p.id, map);
        } catch (_) {}
      }
    } catch (_) {
      // ignore background refresh errors
    }
  }

  UserProfile _fallbackProfile(String id) {
    return UserProfile.fromMap({
      'id': id,
      'displayName': id,
      'username': id,
      'timezone': 'UTC',
      'dayStartHour': 4,
      'groupIds': <String>[],
      'feedViewMode': 'list',
    });
  }

  /// Store profiles into the cache with a `_cachedAt` timestamp.
  Future<void> storeProfiles(List<UserProfile> profiles) async {
    for (final p in profiles) {
      final map = p.toMap();
      map['_cachedAt'] = DateTime.now().toUtc().toIso8601String();
      try {
        await _box.put(p.id, map);
      } catch (_) {}
    }
  }
}

final userProfileCacheProvider = Provider<UserProfileCache>((ref) {
  final repo = ref.read(userProfileRepositoryProvider);
  final box = Hive.box('user_profiles');
  return UserProfileCache(box, repo);
});
