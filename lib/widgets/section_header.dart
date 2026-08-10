import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// Style de titre de section.
enum SectionHeaderStyle { label, subtitle }

/// En-tête de section, dans l'un des deux styles du système.
///
/// [SectionHeader.label] : libellé primaire en capitales (Répétition, Icône…).
/// [SectionHeader.subtitle] : sous-titre discret (Progression, Historique…).
class SectionHeader extends StatelessWidget {
  const SectionHeader.label(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(left: AppSpacing.xs),
  }) : style = SectionHeaderStyle.label;

  const SectionHeader.subtitle(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
  }) : style = SectionHeaderStyle.subtitle;

  final String text;
  final EdgeInsetsGeometry padding;
  final SectionHeaderStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLabel = style == SectionHeaderStyle.label;

    return Padding(
      padding: padding,
      child: Text(
        isLabel ? text.toUpperCase() : text,
        style: isLabel
            ? TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: scheme.primary,
              )
            : TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}
