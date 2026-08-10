import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

/// Données saisies dans l'éditeur de catégorie.
class CategoryEditorData {
  const CategoryEditorData({
    required this.name,
    required this.icon,
    required this.colorIndex,
  });

  final String name;
  final String icon;
  final int colorIndex;
}

/// Ouvre la boîte de dialogue de création / édition d'une catégorie.
/// Retourne les données saisies, ou `null` si annulé.
Future<CategoryEditorData?> showCategoryEditorDialog(
  BuildContext context, {
  String initialName = '',
  String initialIcon = '📦',
  int initialColorIndex = 0,
  String? title,
}) {
  return showDialog<CategoryEditorData>(
    context: context,
    builder: (context) => _CategoryEditorDialog(
      initialName: initialName,
      initialIcon: initialIcon,
      initialColorIndex: initialColorIndex,
      title: title,
    ),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({
    required this.initialName,
    required this.initialIcon,
    required this.initialColorIndex,
    this.title,
  });

  final String initialName;
  final String initialIcon;
  final int initialColorIndex;
  final String? title;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late String _icon = widget.initialIcon;
  late int _colorIndex = widget.initialColorIndex;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CategoryEditorData(
        name: _nameController.text.trim(),
        icon: _icon,
        colorIndex: _colorIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title ?? s.newCategory),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: s.categoryName,
                  hintText: s.categoryNameHint,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.categoryNameError : null,
              ),
              const SizedBox(height: 16),
              Text(
                s.categoryIcon,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final icon in CategoryPresets.icons)
                    InkWell(
                      onTap: () => setState(() => _icon = icon),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _icon == icon
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                s.categoryColor,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (var i = 0; i < AppTheme.categoryPalette.length; i++)
                    InkWell(
                      onTap: () => setState(() => _colorIndex = i),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.categoryColor(i),
                          border: _colorIndex == i
                              ? Border.all(color: scheme.onSurface, width: 2.5)
                              : null,
                        ),
                        child: _colorIndex == i
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _save,
          child: Text(s.save),
        ),
      ],
    );
  }
}
