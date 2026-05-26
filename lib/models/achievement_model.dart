import 'package:flutter/material.dart';

/// A pure-derived (not persisted) badge a child can earn. Achievement state is
/// recomputed from transactions and savings progress on demand. To "save" them
/// to Firestore later, persist `{ id, earnedAt }` per user.
class Achievement {
  final String id;
  final String titleKey; // l10n key
  final String descriptionKey;
  final IconData icon;
  final Color color;
  final bool earned;
  final double progress; // 0..1
  final String? progressLabel;

  const Achievement({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.color,
    required this.earned,
    this.progress = 0,
    this.progressLabel,
  });

  Achievement copyWith({bool? earned, double? progress, String? progressLabel}) =>
      Achievement(
        id: id,
        titleKey: titleKey,
        descriptionKey: descriptionKey,
        icon: icon,
        color: color,
        earned: earned ?? this.earned,
        progress: progress ?? this.progress,
        progressLabel: progressLabel ?? this.progressLabel,
      );
}
