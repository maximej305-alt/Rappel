import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/sound_option.dart';
import '../services/sound_preview_service.dart';

/// Ouvre la feuille de choix de son avec aperçu immédiat au tap.
///
/// - Toucher un son joue immédiatement son aperçu (le précédent est arrêté).
/// - La sélection est confirmée avec le bouton « OK ».
/// - Fermer la feuille (sans confirmer) stoppe l'aperçu.
/// Retourne l'option choisie, ou `null` si annulé.
Future<SoundOption?> showSoundPickerSheet(
  BuildContext context, {
  required String currentId,
  Future<SoundOption?> Function()? importCustom,
}) {
  return showModalBottomSheet<SoundOption>(
    context: context,
    showDragHandle: true,
    builder: (context) => _SoundPickerSheet(
      currentId: currentId,
      importCustom: importCustom,
    ),
  );
}

class _SoundPickerSheet extends StatefulWidget {
  const _SoundPickerSheet({required this.currentId, this.importCustom});

  final String currentId;
  final Future<SoundOption?> Function()? importCustom;

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  late String _candidateId = widget.currentId;
  String? _previewingId;
  bool _importing = false;

  @override
  void dispose() {
    SoundPreviewService.instance.stop();
    super.dispose();
  }

  Future<void> _play(String soundId) async {
    await SoundPreviewService.instance.play(soundId);
    if (mounted) {
      setState(() {
        _candidateId = soundId;
        _previewingId = soundId;
      });
    }
  }

  Future<void> _stop() async {
    await SoundPreviewService.instance.stop();
    if (mounted) setState(() => _previewingId = null);
  }

  Future<void> _import() async {
    final import = widget.importCustom;
    if (import == null) return;
    setState(() => _importing = true);
    await SoundPreviewService.instance.stop();
    final custom = await import();
    if (!mounted) return;
    if (custom != null) {
      Navigator.of(context).pop(custom);
    } else {
      setState(() {
        _importing = false;
        _previewingId = null;
      });
    }
  }

  void _confirm() {
    final option = SoundOption.fromId(_candidateId);
    Navigator.of(context).pop(option);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;

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
                  s.notificationSound,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.audiotrack, color: scheme.primary),
                title: Text(s.chooseCustomSound),
                subtitle: Text(s.chooseCustomSoundHint),
                trailing: _importing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: scheme.primary),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _importing ? null : _import,
              ),
              const Divider(height: 1),
              for (final option in SoundOption.all)
                ListTile(
                  leading: Icon(option.icon, color: scheme.primary),
                  title: Text(soundLabel(option, s)),
                  trailing: option.id == _previewingId
                      ? IconButton(
                          tooltip: s.previewStop,
                          onPressed: _stop,
                          icon: const Icon(Icons.stop_circle_outlined),
                          color: scheme.error,
                        )
                      : option.id == _candidateId
                          ? Icon(Icons.check_circle, color: scheme.primary)
                          : IconButton(
                              tooltip: s.previewPlay,
                              onPressed: () => _play(option.id),
                              icon: const Icon(Icons.play_circle_outline),
                              color: scheme.outline,
                            ),
                  onTap: () => _play(option.id),
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
