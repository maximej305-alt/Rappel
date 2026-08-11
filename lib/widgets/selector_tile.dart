import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/dimens.dart';

/// Tuile de sélection (Heure, Date, Son…) : icône, libellé, valeur, chevron.
///
/// [dense] réduit la tuile pour un usage dans une feuille modale.
class SelectorTile extends StatelessWidget {
  const SelectorTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(dense ? AppRadius.lg : AppRadius.xl),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSpacing.md : AppSpacing.md2 - 2,
            vertical: dense ? AppSpacing.md : AppSpacing.md2 - 2,
          ),
          child: Row(
            children: [
              if (dense)
                Icon(icon, size: 18, color: scheme.primary)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    icon,
                    color: scheme.onPrimaryContainer,
                    size: 21,
                  ),
                ),
              SizedBox(width: dense ? 10 : AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.fieldLabel.copyWith(
                        fontSize:
                            dense ? AppTypography.sizeXs : AppTypography.sizeSm,
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.fieldValue.copyWith(
                        fontSize: dense
                            ? AppTypography.sizeBase
                            : AppTypography.sizeLg,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xsm),
              Icon(
                Icons.chevron_right,
                size: dense ? 18 : 20,
                color: scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
