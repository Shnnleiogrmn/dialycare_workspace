import 'package:flutter/material.dart';

/// Uses explicit stored gender only. Custom images take priority.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, this.gender, this.image, this.size = 40});
  final String? gender;
  final ImageProvider? image;
  final double size;
  static String? assetFor(String? gender) =>
      switch (gender?.trim().toLowerCase()) {
        'male' => 'assets/patient-avatar-male.png',
        'female' => 'assets/patient-avatar-female.png',
        _ => null,
      };
  @override
  Widget build(BuildContext context) {
    final asset = assetFor(gender);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFE1F0F4),
      foregroundImage:
          image ??
          (asset == null ? null : AssetImage(asset, package: 'core_shared')),
      child: Icon(
        Icons.person_outline,
        size: size * .65,
        color: const Color(0xFF123F68),
      ),
    );
  }
}

class PersonLabel extends StatelessWidget {
  const PersonLabel({
    super.key,
    required this.name,
    this.gender,
    this.subtitle,
  });
  final String name;
  final String? gender, subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      PersonAvatar(gender: gender, size: 32),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          subtitle == null ? name : '$name\n$subtitle',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
