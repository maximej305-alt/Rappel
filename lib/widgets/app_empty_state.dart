import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/dimens.dart';

/// État vide réutilisable : icône, titre, texte d'aide optionnel.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.centered = false,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(icon, size: 56, color: scheme.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: AppTypography.w600,
              color: scheme.onSurface,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xsm),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: scheme.outline),
            ),
          ],
        ],
      ),
    );

    return centered ? Center(child: content) : content;
  }
}
