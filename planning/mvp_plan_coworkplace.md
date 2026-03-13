# Accountability: Daily Tasks & Accountability App — MVP Plan

> Lean MVP for a small friend group (4–6 people). Focus: simple, reliable, timezone-aware sharing of daily tasks for accountability, self-reflection, and personal growth.

---

## Elevator pitch
A lightweight app where a small group of friends share daily tasks and short progress updates. Each user sets a day-start time and sees their own tasks and friends' tasks adjusted to their local timezone. The app supports daily and one-time tasks, timers, simple ratings, and short weekly/monthly meeting summaries.

### MVP goals
- Make it trivial for 4–6 friends to join a private group and share/see tasks.
- Ensure correct local-day handling across time zones (day-start time per user).
- Provide an easy way to mark tasks complete, rate performance, and run a short meeting summary (weekly/monthly).
- Offline-friendly basic behavior with fast sync when online.

### Non-goals for MVP
- Complex gamification, public leaderboards, or wide-scale auth.
- Long-form notes, attachments, or rich media sharing.
- AI-driven suggestions (can be added later).

---

## Core features (MVP)
1. User auth (email/password or anonymous) + profile (display name, timezone, dayStartHour).
2. Private group creation + invite (share a short group code).
3. Tasks: `daily` and `one-time` task types.
4. Day start time: each user sets local hour (e.g., 04:00) — all views adjust accordingly.
5. See friends' tasks (group-only visibility).
6. Simple task modification (title, description, scheduled time, repeat flag).
7. Mark complete/skip; record completion timestamp (UTC).
8. Timer per task (start / pause / stop) and simple elapsed tracking.
9. Ratings: self-rating per day (0–5) and friends rating per day (0–5); store ratings per (user, date).
10. History & meeting summary generator for weekly/monthly meeting (aggregates and highlights).
11. Local notifications for upcoming tasks (scheduled using user's timezone).

---

## High-level user stories
- As a user, I can join/create a private group and invite my friends.
- As a user, I can add daily or one-time tasks, set a scheduled time, and choose whether it repeats.
- As a user in a different timezone, I can still view friends' tasks and see them converted to my local day view.
- As a user, I can start a timer for a task and mark it complete when finished.
- As a group, we can run a weekly summary showing completion rates and top discussion points.

---

## Data model (JSON-like)

```json
User {
  id: string,
  displayName: string,
  email?: string,
  timezone: string,        // IANA tz, e.g. "America/New_York"
  dayStartHour: number,    // 0-23 local hour when user's day begins
  groupIds: [string]
}

Group {
  id: string,
  name: string,
  members: [userId],
  code: string             // short invite code for MVP
}

Task {
  id: string,
  groupId: string,
  createdBy: userId,
  title: string,
  description?: string,
  type: "daily" | "one_time",
  scheduledTimeUTC?: string, // ISO timestamp when the task is scheduled (UTC)
  daysOfWeek?: [0..6],        // optional for repeats
  active: boolean,
  createdAtUTC: string,
  modifiedAtUTC: string
}

Completion {
  id: string,
  taskId: string,
  userId: string,
  completedAtUTC: string,
  durationSeconds?: number,  // optional if timer used
  notes?: string
}

Rating {
  id: string,
  dateUTC: string,           // store date key in UTC e.g. 2026-03-13
  userId: string,
  selfRating: number,       // 0-5
  friendsRating?: number    // optional aggregated or left to meetings
}

MeetingSummary {
  id: string,
  groupId: string,
  periodStartUTC: string,
  periodEndUTC: string,
  generatedAtUTC: string,
  membersSummary: [
    { userId, completionRate, avgSelfRating, avgFriendsRating }
  ],
  talkingPoints: [string]
}
```

---

## Timezone & day-start design (critical)
**Principle:** store all timestamps in UTC. Record each user's timezone (IANA string) and a `dayStartHour` (0–23). When displaying tasks or computing "today" for a user:

1. Convert UTC timestamp to user's timezone using the IANA tz.
2. Compute user's local date relative to `dayStartHour`:
   - If `dayStartHour = 4` then the user's day starts at 04:00 local time.
   - To decide whether a UTC timestamp belongs to 'today' for that user: convert timestamp to local time and check whether it's in `[dayStartHour(local), dayStartHour(local) + 24h)`.

**Recurring/daily tasks:** store recurrence by day-of-week or simple `daily` flag. When generating occurrences for a user, compute occurrence timestamps in UTC by converting user's local intended time to UTC.

**Notifications & timers:** use `flutter_local_notifications` + `timezone` plugin. Schedule notifications in local timezone, but persist scheduling metadata (UTC) in DB so other devices can see changes.

---

## Backend & sync (MVP recommendation)
**Recommended quick path:** Firebase Authentication + Firestore.
- Pros: realtime updates, offline persistence, auth, easy rules for group-only visibility.
- Cons: vendor lock-in; be mindful of security rules.

**Alternative:** Supabase / Postgres with realtime or a tiny Node/Express server. For 4–6 users, Firestore reduces backend overhead.

**Offline-first:** Use Firestore's offline cache. For local-only first approach, combine a local DB (Hive / Isar / Drift) and sync with cloud later.

**Security rules (concept):** groups/{groupId} read/write only if `request.auth.uid` is in `groups/{groupId}.members`.

---

## Firestore collection structure (example)
- `/users/{userId}`
- `/groups/{groupId}`
- `/groups/{groupId}/tasks/{taskId}`
- `/groups/{groupId}/completions/{completionId}`
- `/groups/{groupId}/ratings/{ratingId}`
- `/groups/{groupId}/meetingSummaries/{summaryId}`

---

## Flutter architecture & packages (recommendations)
- State management: **Riverpod** (you already use it — great).
- Immutable models: `freezed` + `json_serializable`.
- Local DB (optional): `hive` or `isar` for small objects; `drift` if you want SQL power.
- Timezone & scheduling: `timezone` + `flutter_local_notifications`.
- Auth + backend: `firebase_auth`, `cloud_firestore`, `firebase_core` (if using Firebase).
- Others: `intl` for formatting, `flutter_slidable` for swipe actions, `charts_flutter` or light custom charts for meeting summaries.

Project layout suggestion (small):
```
/lib
  /models      // freezed generated models
  /providers   // Riverpod providers
  /services    // firestore sync, notification service, timezone helpers
  /screens     // Home, TaskDetail, AddTask, Friends, MeetingSummary, Settings
  /widgets     // TaskCard, TimerChip, RatingStars
  /utils       // date helpers
```

---

## UI plan (text wireframes)

### Onboarding / Group setup
- Simple flow: Sign in -> Create group OR Join group (enter code)
- Group screen: list members + group code + quick "Invite" button

### Home (default view)
- Top bar: Group name, quick switch to choose day-range (Today / Week / Month)
- Today's timeline: list of TaskCards
- Floating action button: + Add Task
- Bottom nav: Home | Friends | History | Settings

**TaskCard**: title, time (local), repeat badge, timer start button, completion checkbox, friends' avatars who also have this task (if shared), short progress indicator.

### Task Add / Edit (modal)
- Title (required)
- Type: Daily / One-time
- Scheduled time (optional) -> pick local time
- Repeat days (if daily weekly)
- Share with group toggle (default on)
- Save

### Friends screen
- List of members with today's completion rate and small progress ring
- Tap member -> see their tasks for "their day" converted into your view with local-times annotated

### History / Meeting Summary
- Select period (Last 7 days / Last month)
- Summary cards: group completion rate, per-member completion rate, average ratings, suggested talking points (low performers, missed high-priority tasks)
- Button: "Generate meeting notes" (create MeetingSummary doc)

### Settings
- Display name, timezone (auto-detected but editable), day start hour, notification prefs

---

## Simple meeting summary generation (algorithm)
Input: periodStartUTC, periodEndUTC, groupId
Outputs:
- For each member: expectedTasks = count of assigned daily occurrences in period; completed = count of Completion records in period for that member; completionRate = completed / expectedTasks.
- Top missed tasks (sorted by missed count).
- Average selfRating and friendsRating per member.
- Talking points: members with completionRate < 60%, tasks missed by > 50% of group, tasks with conflicting schedules.

Format output as a compact list to discuss in a 10–15 minute meeting.

---

## Example Riverpod + model snippet (Dart, simplified)
```dart
@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String groupId,
    required String createdBy,
    required String title,
    String? description,
    required String type, // "daily" | "one_time"
    DateTime? scheduledTimeUtc,
    @Default(true) bool active,
    required DateTime createdAtUtc,
  }) = _Task;
}

final tasksProvider = StreamProvider.autoDispose.family<List<Task>, String>((ref, groupId) {
  final service = ref.watch(taskServiceProvider);
  return service.watchTasks(groupId);
});
```

---

## MVP scope & priorities (recommended order)
**Phase 0 — scaffolding**
- Project skeleton, Firebase config, auth, user profile + timezone/dayStart.
- Group creation + join flow.

**Phase 1 — core task features**
- Add/edit tasks, mark complete, local display of tasks per user's dayStart.
- Show friends' tasks (read-only view).
- Notifications and timer (local device scheduling).

**Phase 2 — history & meetings**
- Completions collection, ratings, and simple meeting summary generator.
- UI for weekly/monthly meeting summary.

**Phase 3 — polish**
- Offline sync fixes, small animations, better error handling, small cosmetic UI improvements.

---

## Quick QA & testing checklist
- Timezone correctness: create users with different timezones and dayStart; verify "today" grouping.
- Repeating tasks: verify daily occurrences created and completion counted correctly.
- Race conditions: simultaneous completions from multiple devices for same user/task.
- Notifications: scheduled and fired at correct local times.
- Security: group visibility rules enforced.

---

## Next steps I can take for you (pick one)
- Implement the **Home screen** in Flutter (Riverpod + TaskCard + providers). `// includes UI + provider wiring`
- Build the **Task model + Riverpod providers + Firestore service** (data layer).
- Implement **timezone helpers and dayStart logic** with unit tests.
- Create **Meeting Summary generator** logic and an example output for a sample dataset.

---

## Final notes & trade-offs
- For a 4–6 user private MVP, Firestore will save large dev time. If you want absolute control and on-prem privacy, go Supabase or custom Postgres.
- Correct timezone handling and a clear dayStart mental model are the trickiest bits — invest time writing unit tests for date computations.
- Keep UI minimal: focus on clarity for the "today" timeline and quick completion actions.

---

*If you want, I can now generate the Flutter code for the Home screen (Riverpod + TaskCard) or the Task data layer. Tell me which one and I’ll produce ready-to-use Dart files.*

