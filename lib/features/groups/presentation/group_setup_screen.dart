import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/groups/providers/group_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupSetupScreen extends ConsumerStatefulWidget {
  const GroupSetupScreen({super.key});

  @override
  ConsumerState<GroupSetupScreen> createState() => _GroupSetupScreenState();
}

class _GroupSetupScreenState extends ConsumerState<GroupSetupScreen> {
  final _groupNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  bool _isCreating = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final userId = session?.userId;
    if (userId == null) {
      _showSnack('Session is not ready yet.');
      return;
    }

    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      _showSnack('Please enter a group name.');
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final repository = ref.read(groupRepositoryProvider);
      final group = await repository.createGroup(name: groupName, userId: userId);
      ref.invalidate(appSessionProvider);

      if (!mounted) {
        return;
      }
      _showSnack('Group created. Invite code: ${group.code}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Failed to create group: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _joinGroup() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final userId = session?.userId;
    if (userId == null) {
      _showSnack('Session is not ready yet.');
      return;
    }

    final inviteCode = _inviteCodeController.text.trim();
    if (inviteCode.isEmpty) {
      _showSnack('Please enter an invite code.');
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final repository = ref.read(groupRepositoryProvider);
      final group = await repository.joinGroupByCode(
        inviteCode: inviteCode,
        userId: userId,
      );
      ref.invalidate(appSessionProvider);

      if (!mounted) {
        return;
      }
      _showSnack('Joined ${group.name}.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Failed to join group: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Group', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Create a private group and share the generated invite code.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _groupNameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isCreating || _isJoining ? null : _createGroup,
                    child: Text(_isCreating ? 'Creating...' : 'Create Group'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join Group', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Enter a 6-character invite code from your friend.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteCodeController,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Invite Code',
                      hintText: 'Example: AB12CD',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _isCreating || _isJoining ? null : _joinGroup,
                    child: Text(_isJoining ? 'Joining...' : 'Join Group'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
