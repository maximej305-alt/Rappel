import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/routine.dart';
import '../providers/providers.dart';
import '../theme/app_typography.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/section_header.dart';
import 'routine_detail_screen.dart';
import 'routine_edit_screen.dart';

/// Liste des routines, chaque carte indiquant le nom, l'icône et le nombre
/// d'activités. L'accueil reste inchangé : les activités concrètes s'y
/// affichent normalement.
class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    final activityMap = ref.watch(routineActivitiesProvider);
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.routines)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        tooltip: s.createRoutine,
        icon: const Icon(Icons.auto_awesome),
        label: Text(s.createRoutine),
        elevation: 4,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      body: routines.isEmpty
          ? AppEmptyState(
              icon: Icons.view_agenda_outlined,
              title: s.noRoutines,
              hint: s.noRoutinesHint,
              centered: true,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                SectionHeader.subtitle(
                  s.routines,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                ),
                for (final routine in routines)
                  _RoutineCard(
                    routine: routine,
                    count: activityMap[routine.id]?.length ?? 0,
                    onTap: () => _open(context, ref, routine),
                  ),
              ],
            ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RoutineEditScreen()),
    );
    if (created == true && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(ref.read(stringsProvider).routineCreated)),
      );
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineDetailScreen(routine: routine),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.count,
    required this.onTap,
  });

  final Routine routine;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    routine.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            s.activitiesLabel(count),
                            style: AppTypography.caption.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                          if (!routine.active) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s.routineInactive,
                                style: AppTypography.labelMicro.copyWith(
                                  color: scheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 20, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

