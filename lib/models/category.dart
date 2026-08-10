import 'package:uuid/uuid.dart';

import '../l10n/app_strings.dart';

/// Catégorie d'une activité.
///
/// Les catégories intégrées ([builtin]) possèdent un [nameKey] traduit via
/// [AppStrings.tr] ; les catégories personnalisées utilisent directement
/// [name]. [isFallback] marque la catégorie de repli « Autre » ([CategoryPresets.otherId]),
/// qui n'est jamais supprimable.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.nameKey,
    this.icon = '📦',
    this.colorIndex = 0,
    this.builtin = false,
    this.isFallback = false,
  });

  final String id;
  final String name;

  /// Clé de traduction (uniquement pour les catégories intégrées).
  final String? nameKey;

  /// Émoji affiché à côté du nom.
  final String icon;

  /// Index dans [AppTheme.categoryPalette].
  final int colorIndex;

  final bool builtin;

  /// Vrai pour la catégorie de repli « Autre » (jamais supprimable).
  final bool isFallback;

  static const _uuid = Uuid();

  String displayName(AppStrings s) => nameKey != null ? s.tr(nameKey!) : name;

  factory Category.create({
    required String name,
    String icon = '📦',
    int colorIndex = 0,
  }) {
    return Category(id: _uuid.v4(), name: name, icon: icon, colorIndex: colorIndex);
  }

  Category copyWith({
    String? name,
    String? icon,
    int? colorIndex,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      nameKey: nameKey,
      icon: icon ?? this.icon,
      colorIndex: colorIndex ?? this.colorIndex,
      builtin: builtin,
      isFallback: isFallback,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'nameKey': nameKey,
        'icon': icon,
        'colorIndex': colorIndex,
        'builtin': builtin,
        'isFallback': isFallback,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        nameKey: map['nameKey'] as String?,
        icon: (map['icon'] as String?) ?? '📦',
        colorIndex: (map['colorIndex'] as int?) ?? 0,
        builtin: (map['builtin'] as bool?) ?? false,
        isFallback: (map['isFallback'] as bool?) ?? false,
      );
}

/// Catégories intégrées et constantes associées.
abstract final class CategoryPresets {
  /// Identifiant stable de la catégorie de repli.
  static const String otherId = 'builtin_other';

  /// Émojis proposés pour les catégories personnalisées.
  static const List<String> icons = [
    '👤', '💼', '📚', '🏃', '🏠', '🍎', '💪', '🎯',
    '🎵', '✈️', '💊', '🛒', '🧘', '🎮', '📷', '🚗',
    '🐶', '☕', '💡', '💰',
  ];

  /// Cinq catégories intégrées, avec des identifiants stables.
  static const List<Category> builtins = [
    Category(
      id: 'builtin_perso',
      name: 'Personnel',
      nameKey: 'categoryPersonal',
      icon: '👤',
      colorIndex: 0,
      builtin: true,
    ),
    Category(
      id: 'builtin_work',
      name: 'Travail',
      nameKey: 'categoryWork',
      icon: '💼',
      colorIndex: 1,
      builtin: true,
    ),
    Category(
      id: 'builtin_study',
      name: 'Études',
      nameKey: 'categoryStudy',
      icon: '📚',
      colorIndex: 2,
      builtin: true,
    ),
    Category(
      id: 'builtin_sport',
      name: 'Sport',
      nameKey: 'categorySport',
      icon: '🏃',
      colorIndex: 3,
      builtin: true,
    ),
    Category(
      id: otherId,
      name: 'Autre',
      nameKey: 'categoryOther',
      icon: '📦',
      colorIndex: 4,
      builtin: true,
      isFallback: true,
    ),
  ];
}
