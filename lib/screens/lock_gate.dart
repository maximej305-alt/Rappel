import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'lock_screen.dart';

/// Enveloppe l'application : affiche l'écran de verrouillage tant que
/// le verrou est actif (au lancement, et au retour d'arrière-plan).
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Le verrou est actif dès le départ si la sécurité est activée.
    _unlocked = !ref.read(lockSettingsProvider).enabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Relance le verrou quand l'app revient au premier plan.
    if (state == AppLifecycleState.resumed && mounted) {
      final lock = ref.read(lockSettingsProvider);
      if (lock.enabled) {
        setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockSettingsProvider);

    // Pas de sécurité activée, ou déjà déverrouillée → contenu normal.
    if (!lock.enabled || _unlocked) {
      return widget.child;
    }

    return LockScreen(
      onUnlocked: () => setState(() => _unlocked = true),
    );
  }
}
