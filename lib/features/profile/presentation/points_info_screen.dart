import 'package:flutter/material.dart';

class PointsInfoScreen extends StatelessWidget {
  const PointsInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to Earn Points')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Current Ways to Earn'),
          const SizedBox(height: 8),
          ..._rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: rule.color.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(rule.icon, color: rule.color, size: 20),
                  ),
                  title: Text(
                    rule.action,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(rule.detail),
                  trailing: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        rule.pts,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Things to Know'),
          const SizedBox(height: 8),
          _InfoNote(
            icon: Icons.shield_outlined,
            text:
                'All point awards use Firestore transactions — no double-counting.',
          ),
          _InfoNote(
            icon: Icons.refresh,
            text:
                'Weekly and monthly scores reset automatically each period. Only "All-time" never resets.',
          ),
          _InfoNote(
            icon: Icons.timer_outlined,
            text:
                'App open bonus is limited to once per 2-hour window. Goal update bonus is once per hour.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Rule {
  const _Rule({
    required this.action,
    required this.detail,
    required this.pts,
    required this.icon,
    required this.color,
  });
  final String action;
  final String detail;
  final String pts;
  final IconData icon;
  final Color color;
}

const _rules = [
  _Rule(
    action: 'Open the app',
    detail: 'Once per 2-hour window',
    pts: '+2 pts',
    icon: Icons.open_in_new_rounded,
    color: Color(0xFF6366F1),
  ),
  _Rule(
    action: 'Stay active',
    detail: 'Once per hour of activity',
    pts: '+1 pt',
    icon: Icons.bolt_rounded,
    color: Color(0xFF0EA5E9),
  ),
  _Rule(
    action: 'Complete a task',
    detail: 'Each task marked done',
    pts: '+3 pts',
    icon: Icons.check_circle_outline_rounded,
    color: Color(0xFF22C55E),
  ),
  _Rule(
    action: 'Create a task',
    detail: 'When you add a new task',
    pts: '+2 pts',
    icon: Icons.add_task_rounded,
    color: Color(0xFF8B5CF6),
  ),
  _Rule(
    action: 'Create or update a goal',
    detail: 'Once per hour',
    pts: '+1 pt',
    icon: Icons.flag_rounded,
    color: Color(0xFFF97316),
  ),
  _Rule(
    action: 'Receive a vote on a task',
    detail: 'A friend votes on your task',
    pts: '+1 pt',
    icon: Icons.thumb_up_alt_outlined,
    color: Color(0xFFEC4899),
  ),
];
