import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';

class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.profile,
    this.radius = 20.0,
  });

  final UserProfile? profile;
  final double radius;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  MemoryImage? _cachedImage;
  String? _cachedBase64;

  @override
  void initState() {
    super.initState();
    _updateCache();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.photoBase64 != widget.profile?.photoBase64) {
      _updateCache();
    }
  }

  void _updateCache() {
    final base64 = widget.profile?.photoBase64;
    if (base64 == null) {
      _cachedImage = null;
      _cachedBase64 = null;
    } else if (base64 != _cachedBase64) {
      _cachedBase64 = base64;
      _cachedImage = MemoryImage(base64Decode(base64));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Explicit sizing guarantees HTML layout engine on Web doesn't 
    // collapse unbound nested Stacks/InkWells to 0x0
    return SizedBox(
      width: widget.radius * 2,
      height: widget.radius * 2,
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: _cachedImage,
        child: _cachedImage == null
            ? Text(
                widget.profile?.displayName.isNotEmpty == true
                    ? widget.profile!.displayName[0].toUpperCase()
                    : '?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.radius * 0.8,
                    ),
              )
            : null,
      ),
    );
  }
}
