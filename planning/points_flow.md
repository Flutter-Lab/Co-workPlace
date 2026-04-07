# Coworkplace — Points System Flow

================================================

## Storage

- Firestore: `users/{userId}/scores/{periodId}` → `{ periodId, points, updatedAtUtc }`
- Period IDs: `week_YYYY_WNN`, `month_YYYY_MM`, `alltime`
- Idempotency: each award event writes a dedup marker doc; transaction checks existence first

## Current Point Rules

| Action                       | Points | Dedup Key                                    |
| ---------------------------- | ------ | -------------------------------------------- |
| App open (per 2-hour window) | +2     | `users/{id}/appOpenSlots/{YYYY-MM-DD-openN}` |
| Activity hour                | +1     | `users/{id}/activityHours/{YYYY-MM-DD-HH}`   |
| Create a task                | +2     | None (fires once at creation)                |
| Complete a task              | +3     | Controlled by completion doc                 |
| Receive a vote on task       | +1     | `tasks/{owner}/tasks/{task}/votes/{liker}`   |

## ScoreService Methods (score_service.dart)

- `awardAppOpen(userId)` — +2 pts, idempotent per 2-hour slot
- `awardActivityHour(userId)` — +1 pt, idempotent per hour
- `awardTaskCreate(ownerId)` — +2 pts (default)
- `awardCompletion(userId)` — +3 pts (default)
- `awardVote(ownerId, taskId, likerId)` — +1 pt, idempotent per liker per task
- `revokeVote(ownerId, taskId, likerId)` — −1 pt
- `getPointsForUser(userId)` — returns all-time points (int)
- `getScoresForUsers(periodId, userIds)` — leaderboard batch fetch
- `streamTopScores(periodId)` — real-time leaderboard stream

## Where Points Are Shown

- **Profile screen** → `_PointsCard`: shows all-time pts with "+2 pts / 2 hrs" hint
- **Home feed** → `_FriendFeedTile`: ⭐ pts badge below task bar, for all users
- **Leaderboard screen** → weekly ranked list with pts

## Suggested Future Point Rules

| Idea                                         | Points | Notes                                       |
| -------------------------------------------- | ------ | ------------------------------------------- |
| Complete all daily tasks in one day (streak) | +5     | Bonus on perfect day                        |
| 7-day consecutive completion streak          | +20    | Weekly consistency bonus                    |
| Friend accepts friendship request            | +3     | Social growth reward                        |
| Share a goal that gets 5+ views              | +10    | Future: goal links feature                  |
| First task of the day (before noon)          | +1     | Early-bird bonus                            |
| Vote on 3+ friends in one day                | +2     | Engagement bonus (needs daily vote tracker) |
| Set a current mode (daily)                   | +1     | Encourage daily check-in                    |

## Architecture Notes

- All point writes are Firestore transactions — no double-counting risk
- `periodId` drives leaderboard resets automatically (weekly / monthly)
- `alltime` period never resets — used for profile total display
- Adding a new rule = add one `awardXxx` method, call it from the right place
