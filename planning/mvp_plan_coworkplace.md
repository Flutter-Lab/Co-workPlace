# Accountability: Daily Tasks & Accountability App — Finalized MVP Plan

> Lean MVP for a small friend group (4–6 people). Focus: simple, reliable, timezone-aware sharing of daily tasks for accountability and lightweight daily check-ins.

---

## Elevator pitch

A lightweight app where a small group of friends share daily tasks and a simple current status. Each user sets a day-start time and sees their own tasks and friends' tasks adjusted to their local timezone. The first version supports daily tasks, one-time tasks, group visibility, and a lightweight “current mode” check-in.

### MVP goals

- Make it trivial for 4–6 friends to join a private group and share/see tasks.
- Ensure correct local-day handling across time zones (day-start time per user).
- Provide an easy way to mark tasks complete and share a simple current status.
- Keep the first version small enough to implement and test quickly.

### Non-goals for MVP

- Complex gamification, public leaderboards, or wide-scale auth.
- Long-form notes, attachments, or rich media sharing.
- AI-driven suggestions, ratings, timers, notifications, and meeting summaries.

---

## Finalized MVP scope

This is the version to build first.

### Included in MVP

1. Anonymous authentication for fast onboarding.
2. User profile with display name, timezone, and dayStartHour.
3. Create group and join private group with invite code.
4. Create `daily` and `one-time` tasks.
5. Only the task owner can add, edit, delete, complete, or skip their own tasks.
6. Group members can view each other’s task lists in read-only mode.
7. Correct multi-timezone handling based on each task owner’s timezone and day start.
8. Current mode: user selects a current feeling/status from a preset list or enters a custom value manually.
9. Settings screen for display name, timezone, day start, and current mode presets.

### Deferred until later

- Email/password auth
- Timers
- Ratings
- Notifications
- Weekly/monthly summaries
- Advanced offline sync beyond Firestore defaults
- Shared editing or assignment of other members’ tasks

---

## Core features (MVP)

1. Anonymous auth + profile (display name, timezone, dayStartHour).
2. Private group creation + invite (share a short group code).
3. Tasks: `daily` and `one-time` task types.
4. Day start time: each user sets local hour (e.g., 04:00) — all views adjust accordingly.
5. See friends' tasks (group-only visibility, read-only).
6. Simple task modification by owner only (title, description, scheduled time, repeat flag).
7. Mark complete/skip; record completion timestamp (UTC).
8. Current mode per user: preset choice or custom text.

---

## High-level user stories

- As a user, I can sign in anonymously and set my display name, timezone, and day start hour.
- As a user, I can join/create a private group and invite my friends.
- As a user, I can add daily or one-time tasks, set a scheduled time, and choose whether it repeats.
- As a user, I can edit or delete only my own tasks.
- As a user in a different timezone, I can still view friends' tasks and see them converted to my local day view.
- As a user, I can set my current mode from a list or write a custom status manually.

---

## Data model (JSON-like)

```json
User {
  id: string,
  displayName: string,
  timezone: string,        // IANA tz, e.g. "America/New_York"
  dayStartHour: number,    // 0-23 local hour when user's day begins
  groupIds: [string],
  activeGroupId?: string,
  currentMode?: {
    presetId?: string,
    label: string,
    updatedAtUTC: string
  }
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
  ownerId: userId,
  title: string,
  description?: string,
  type: "daily" | "one_time",
  localTimeMinutes?: number,   // e.g. 08:30 => 510, for daily tasks
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
  localDateKey: string,       // owner's logical date, e.g. 2026-03-13
  completedAtUTC: string,
  notes?: string
}

CurrentModePreset {
  id: string,
  label: string,
  icon?: string,
  sortOrder: number
}
```

---

## Timezone & day-start design (critical)

**Principle:** store all timestamps in UTC. Record each user's timezone (IANA string) and a `dayStartHour` (0–23). When displaying tasks or computing "today" for a user:

1. Convert UTC timestamp to user's timezone using the IANA tz.
2. Compute user's local date relative to `dayStartHour`:
   - If `dayStartHour = 4` then the user's day starts at 04:00 local time.
   - To decide whether a UTC timestamp belongs to 'today' for that user: convert timestamp to local time and check whether it's in `[dayStartHour(local), dayStartHour(local) + 24h)`.

**Recurring/daily tasks:** store daily tasks as templates. Do not pre-generate task rows for every day. Instead, generate the logical occurrence for the owner's current day and track completion separately using `localDateKey`.

**Viewing members' tasks:** compute a member’s task list using the member’s timezone and day-start rules, then render the result in the viewer’s UI. The important rule is that “today” is defined by the task owner, not the viewer.

**Current mode:** treat this as a lightweight profile status with timestamp, not a historical journal entry in MVP.

---

## Backend & sync (MVP recommendation)

**Recommended quick path:** Firebase Anonymous Authentication + Firestore.

- Pros: realtime updates, offline persistence, auth, easy rules for group-only visibility.
- Cons: vendor lock-in; be mindful of security rules.

**Alternative:** Supabase / Postgres with realtime or a tiny Node/Express server. For 4–6 users, Firestore reduces backend overhead.

**Offline-first:** Use Firestore's offline cache. For local-only first approach, combine a local DB (Hive / Isar / Drift) and sync with cloud later.

**Security rules (concept):**

- group documents readable only if `request.auth.uid` is in `groups/{groupId}.members`
- task documents readable only for group members
- task create/update/delete allowed only when `request.auth.uid == resource.data.ownerId` or `request.resource.data.ownerId`
- completion documents allowed only for the task owner

---

## Firestore collection structure (example)

- `/users/{userId}`
- `/groups/{groupId}`
- `/groups/{groupId}/tasks/{taskId}`
- `/groups/{groupId}/completions/{completionId}`
- `/groups/{groupId}/modePresets/{presetId}`

---

## Flutter architecture & packages (recommendations)

- State management: **Riverpod**.
- Immutable models: `freezed` + `json_serializable`.
- Timezone: `timezone`.
- Auth + backend: `firebase_auth`, `cloud_firestore`, `firebase_core`.
- Others: `intl` for formatting, `flutter_slidable` for swipe actions.

Project layout suggestion (small):

```
/lib
  /models      // freezed generated models
  /providers   // Riverpod providers
  /services    // firestore sync, notification service, timezone helpers
  /screens     // Home, AddTask, Members, Settings, GroupSetup
  /widgets     // TaskCard, CurrentModeChip
  /utils       // date helpers
```

---

## UI plan (text wireframes)

### Onboarding / Group setup

- Simple flow: Anonymous sign in -> Profile setup -> Create group OR Join group (enter code)
- Group screen: list members + group code + quick "Invite" button

### Home (default view)

- Top bar: Group name, current mode chip, and quick switch between My Tasks / Members
- Today's timeline: list of TaskCards
- Floating action button: + Add Task
- Bottom nav: Home | Members | Settings

**TaskCard**: title, time (local), repeat badge, owner label if viewing another member, completion checkbox for own tasks only.

### Task Add / Edit (modal)

- Title (required)
- Type: Daily / One-time
- Scheduled time (optional) -> pick local time
- Repeat days (if daily weekly)
- Save

### Members screen

- List of members with today's completion rate and small progress ring
- Tap member -> see their tasks for "their day" converted into your view with local-times annotated

### Settings

- Display name, timezone (auto-detected but editable), day start hour, current mode presets

### Current mode picker

- Preset list such as Focused, Tired, Motivated, Overwhelmed, Resting
- Optional custom text input
- Selected mode shown on home screen and member list

---

## Example Riverpod + model snippet (Dart, simplified)

```dart
@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String groupId,
    required String ownerId,
    required String title,
    String? description,
    required String type, // "daily" | "one_time"
    int? localTimeMinutes,
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

- Project skeleton, Firebase config, anonymous auth, user profile + timezone/dayStart.
- Group creation + join flow.

**Phase 1 — core task features**

- Add/edit tasks, mark complete, local display of tasks per user's dayStart.
- Show friends' tasks (read-only view).
- Current mode create/select/update.

**Phase 2 — hardening**

- Firestore security rules.
- Timezone/dayStart tests.
- Better empty/error/loading states.

**Phase 3 — later additions**

- Notifications, timers, ratings, summaries, and polish.

---

## Quick QA & testing checklist

- Timezone correctness: create users with different timezones and dayStart; verify "today" grouping.
- Repeating tasks: verify daily occurrences created and completion counted correctly.
- Task ownership: verify one member cannot edit or delete another member's tasks.
- Current mode: preset and custom status both save and display correctly.
- Security: group visibility rules enforced.

---

## Next steps for implementation

1. Set up app foundation: Riverpod, Firebase Core/Auth/Firestore, routing, base theme, and folder structure.
2. Build domain models first: `UserProfile`, `Group`, `Task`, `Completion`, and `CurrentModePreset`.
3. Implement timezone/dayStart helpers with unit tests before building task filtering UI.
4. Build profile setup and anonymous onboarding flow.
5. Build create group / join group flow.
6. Build task creation, editing, deletion, and completion for task owners only.
7. Build member list and read-only member task view.
8. Build current mode selector and display it on home and member list.
9. Add Firestore security rules and test ownership constraints.

---

## Final notes & trade-offs

- For a 4–6 user private MVP, Firestore will save large dev time.
- Correct timezone handling and a clear dayStart mental model are the trickiest bits, so timezone helpers should be treated as core domain logic, not UI helpers.
- Anonymous auth is the right tradeoff for speed, but plan a future upgrade path if users later need account recovery.
- Keep UI minimal: clarity of the "today" list and ownership boundaries matter more than extra features.

---

_If you want, I can now generate the Flutter code for the Home screen (Riverpod + TaskCard) or the Task data layer. Tell me which one and I’ll produce ready-to-use Dart files._
