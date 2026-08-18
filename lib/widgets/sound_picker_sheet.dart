import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/sound_option.dart';
import '../services/sound_preview_service.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';

/// Ouvre la feuille de choix de son avec aperçu immédiat au tap.
///
/// - Toucher un son le **sélectionne immédiatement** ET joue son aperçu.
/// - L'indicateur de lecture animé signale le son en cours d'écoute.
/// - La sélection reste visible (pastille cochée) même pendant la lecture.
/// - La sélection est confirmée avec le bouton « Enregistrer ».
/// Retourne l'option choisie, ou `null` si annulé.
Future<SoundOption?> showSoundPickerSheet(
  BuildContext context, {
  required String currentId,
  Future<SoundOption?> Function()? importCustom,
}) {
  return showModalBottomSheet<SoundOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
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

class _SoundPickerSheetState extends State<_SoundPickerSheet>
    with SingleTickerProviderStateMixin {
  late String _candidateId = widget.currentId;
  String? _previewingId;
  bool _importing = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    lowerBound: 0.6,
    upperBound: 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.currentId.isNotEmpty) _pulse.value = 1.0;
  }

  @override
  void dispose() {
    _pulse.dispose();
    SoundPreviewService.instance.stop();
    super.dispose();
  }

  void _flash() {
    _pulse.forward(from: 0.6);
  }

  void _beginPlaying() {
    if (_pulse.isAnimating) return;
    _pulse.repeat(min: 0.6);
  }

  void _endPlaying() {
    _pulse.stop();
    _pulse.value = 1.0;
  }

  Future<void> _play(String soundId) async {
    // Sélection immédiate : l'aperçu peut échouer (son système, fichier
    // supprimé) sans pour autant perdre le choix de l'utilisateur.
    if (mounted) {
      setState(() => _candidateId = soundId);
      _flash();
    }
    try {
      await SoundPreviewService.instance.play(soundId);
      if (!mounted) return;
      setState(() {
        _previewingId = soundId;
        _beginPlaying();
      });
      // Quand l'aperçu finit tout seul, on revient à l'état « sélectionné »
      // (coche visible) au lieu de rester figé sur l'indicateur de lecture.
      SoundPreviewService.instance.onComplete = () {
        if (!mounted) return;
        setState(() {
          _previewingId = null;
          _endPlaying();
        });
      };
    } catch (_) {
      // Aperçu indisponible : la sélection reste valide.
      if (mounted) {
        setState(() {
          _previewingId = null;
          _endPlaying();
        });
      }
    }
  }

  Future<void> _stop() async {
    SoundPreviewService.instance.onComplete = null;
    await SoundPreviewService.instance.stop();
    if (mounted) {
      setState(() {
        _previewingId = null;
        _endPlaying();
      });
    }
  }

  Future<void> _import() async {
    final import = widget.importCustom;
    if (import == null) return;
    setState(() => _importing = true);
    SoundPreviewService.instance.onComplete = null;
    await SoundPreviewService.instance.stop();
    try {
      final custom = await import();
      if (!mounted) return;
      if (custom != null) {
        Navigator.of(context).pop(custom);
      } else {
        setState(() {
          _importing = false;
          _previewingId = null;
          _endPlaying();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _endPlaying();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.notificationSound,
                        style: AppTypography.sectionTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.chooseCustomSoundHint,
                        style: AppTypography.captionMd.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_previewingId != null)
                  _PreviewChip(
                    icon: Icons.stop_circle_outlined,
                    label: s.previewStop,
                    color: scheme.error,
                    onPressed: _stop,
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: [
                if (widget.importCustom != null)
                  _SoundTile(
                    key: const Key('sound-custom'),
                    leadingIcon: Icons.audiotrack,
                    title: s.chooseCustomSound,
                    subtitle: s.chooseCustomSoundHint,
                    selected: false,
                    busy: _importing,
                    onTap: _importing ? null : _import,
                  ),
                if (widget.importCustom != null) const SizedBox(height: 8),
                for (final option in SoundOption.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SoundTile(
                      key: Key('sound-${option.id}'),
                      leadingIcon: option.icon,
                      title: soundLabel(option, s),
                      subtitle: option.isAlarm ? s.soundAlarm : null,
                      selected: option.id == _candidateId,
                      playing: option.id == _previewingId,
                      pulse: _pulse,
                      onTap: () => _play(option.id),
                      onPlayPause: option.id == _previewingId
                          ? _stop
                          : () => _play(option.id),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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

/// Pastille « en cours de lecture » affichée dans l'en-tête de la feuille.
class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      onPressed: onPressed,
      labelStyle: AppTypography.captionMd.copyWith(color: color),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Tuile de son : pastille cochée quand sélectionné, indicateur de lecture
/// animé quand il joue. La sélection reste visible pendant l'écoute.
class _SoundTile extends StatelessWidget {
  const _SoundTile({
    super.key,
    required this.leadingIcon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.playing = false,
    this.pulse,
    this.onPlayPause,
    this.busy = false,
  });

  final IconData leadingIcon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool playing;
  final Animation<double>? pulse;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPause;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerLow;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: selected
            ? BorderSide(color: scheme.primary, width: 1.5)
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md2,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Badge icône : la coche de sélection est TOUJOURS affichée ici,
              // même pendant la lecture (elle ne disparaît jamais).
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          leadingIcon,
                          size: 22,
                          color: selected ? scheme.onPrimary : scheme.primary,
                        ),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.surface,
                              width: 1.4,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 11,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: AppTypography.w600,
                        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMd.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer.withValues(alpha: 0.7)
                              : scheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (playing && pulse != null)
                _PlayingBars(
                  animation: pulse!,
                  color: scheme.error,
                )
              else if (selected)
                ScaleTransition(
                  scale: pulse ?? kAlwaysCompleteAnimation,
                  child: Icon(
                    Icons.check_circle,
                    color: scheme.primary,
                    size: 26,
                  ),
                )
              else
                IconButton(
                  tooltip: null,
                  onPressed: onPlayPause,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.play_circle_outline,
                    color: scheme.outline,
                    size: 30,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barres d'égaliseur animées pendant la lecture de l'aperçu.
class _PlayingBars extends StatelessWidget {
  const _PlayingBars({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return SizedBox(
          width: 26,
          height: 26,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Bar(heightFactor: 0.5 + 0.5 * _wave(0, t), color: color),
              _Bar(heightFactor: 0.5 + 0.5 * _wave(1, t), color: color),
              _Bar(heightFactor: 0.5 + 0.5 * _wave(2, t), color: color),
            ],
          ),
        );
      },
    );
  }

  double _wave(int index, double t) {
    final phase = (t + index * 0.33);
    return (phase - phase.floorToDouble()).abs() < 0.5 ? 1.0 : 0.3;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.heightFactor, required this.color});

  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      height: 22 * (0.35 + 0.65 * heightFactor),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}