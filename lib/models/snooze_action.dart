/// Actions rapides proposées sur les notifications.
///
/// Chaque action est identifiée par un [id] stable embarqué dans le payload
/// et dans les boutons Android ([AndroidNotificationAction]).
enum QuickAction {
  done('done'),
  snooze5('snooze5'),
  snooze10('snooze10'),
  snooze30('snooze30'),
  tomorrow('tomorrow');

  const QuickAction(this.id);

  /// Identifiant transmis au callback de notification (Android).
  final String id;

  /// Nombre de minutes de report pour les actions de snooze, sinon `null`.
  int? get snoozeMinutes => switch (this) {
        QuickAction.snooze5 => 5,
        QuickAction.snooze10 => 10,
        QuickAction.snooze30 => 30,
        _ => null,
      };

  static QuickAction? fromId(String? id) {
    for (final action in QuickAction.values) {
      if (action.id == id) return action;
    }
    return null;
  }
}
