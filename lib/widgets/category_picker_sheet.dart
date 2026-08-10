import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/category.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'category_editor_dialog.dart';

/// Ouvre la feuille de choix de catégorie.
///
/// - Toucher une catégorie la sélectionne (confirmée avec « OK »).
/// - « Nouvelle catégorie » crée immédiatement une catégorie et la sélectionne.
/// Retourne la catégorie choisie, ou `null` si annulé.
Future<Category?> showCategoryPickerSheet(
  BuildContext context, {
  required String currentId,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    showDragHandle: true,
    builder: (context) => _CategoryPickerSheet(currentId: currentId),
  );
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  const _CategoryPickerSheet({required this.currentId});

  final String currentId;

  @override
  ConsumerState<_CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  late String _candidateId = widget.currentId;
  bool _creating = false;

  Future<void> _create() async {
    final data = await showCategoryEditorDialog(context, title: context.l10n.newCategory);
    if (data == null || !mounted) return;
    setState(() => _creating = true);
    final category = Category.create(
      name: data.name,
      icon: data.icon,
      colorIndex: data.colorIndex,
    );
    await ref.read(categoriesProvider.notifier).create(category);
    if (!mounted) return;
    Navigator.of(context).pop(category);
  }

  void _confirm() {
    final categories = ref.read(categoriesProvider);
    final chosen = categories.where((c) => c.id == _candidateId).firstOrNull;
    if (chosen != null) Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  s.category,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: scheme.primary),
                title: Text(s.newCategory),
                subtitle: Text(s.createCategory),
                trailing: _creating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _creating ? null : _create,
              ),
              const Divider(height: 1),
              for (final c in categories)
                ListTile(
                  leading: _CategoryAvatar(category: c),
                  title: Text(
                    c.displayName(s),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: c.id == _candidateId
                      ? Icon(Icons.check_circle, color: scheme.primary)
                      : null,
                  onTap: () => setState(() => _candidateId = c.id),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check),
                label: Text(s.save),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille colorée avec l'émoji de la catégorie.
class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final color =
        AppTheme.categoryColor(category.colorIndex);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(category.icon, style: const TextStyle(fontSize: 16)),
    );
  }
}
