/// Priorité d'une activité, utilisée pour l'ordonnancement
/// (secondaire après l'heure) et pour un léger indicateur visuel.
enum Priority { normal, important, urgent }

extension PriorityX on Priority {
  static Priority fromName(String? name) {
    return Priority.values.firstWhere(
      (p) => p.name == name,
      orElse: () => Priority.normal,
    );
  }
}
