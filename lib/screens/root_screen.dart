import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_sizes.dart';
import 'calendar_screen.dart';
import 'hebdo_screen.dart';
import 'home_screen.dart';
import 'routines_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    HebdoScreen(),
    CalendarScreen(),
    RoutinesScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(stringsProvider);
    final tabs = [
      _TabData(s.homeTab, Icons.home_outlined, Icons.home_rounded),
      _TabData(s.weeklyTab, Icons.calendar_view_week_outlined, Icons.calendar_view_week_rounded),
      _TabData(s.calendar, Icons.calendar_month_outlined, Icons.calendar_month_rounded),
      _TabData(s.routines, Icons.view_agenda_outlined, Icons.view_agenda_rounded),
      _TabData(s.stats, Icons.insights_outlined, Icons.insights_rounded),
      _TabData(s.settings, Icons.settings_outlined, Icons.settings_rounded),
    ];

    return Scaffold(
      body: _LazyIndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppSizes.bottomNavHeight,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      data: tabs[i],
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabData {
  const _TabData(this.label, this.outlinedIcon, this.filledIcon);

  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;
}

/// IndexedStack paresseux : l'onglet courant est construit à sa première
/// visite, puis conservé (état préservé par la suite). Les onglets jamais
/// ouverts ne sont ni instanciés ni réparés.
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  List<Widget?> _built = const [];

  @override
  Widget build(BuildContext context) {
    if (_built.length != widget.children.length) {
      _built = List<Widget?>.filled(widget.children.length, null);
    }
    final index = widget.index;
    _built[index] ??= widget.children[index];

    return Stack(
      children: [
        for (var i = 0; i < _built.length; i++)
          if (_built[i] case final Widget child)
            Offstage(
              offstage: i != index,
              child: TickerMode(
                enabled: i == index,
                child: child,
              ),
            ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _TabData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 46,
            height: 34,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              selected ? data.filledIcon : data.outlinedIcon,
              size: 22,
              color: selected ? scheme.onPrimary : scheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? scheme.primary : scheme.outline,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.label,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
