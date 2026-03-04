import 'package:flutter/material.dart';

enum MobileQuickKeyAction {
  escape,
  tab,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  home,
  end,
  pageUp,
  pageDown,
  pipe,
  slash,
  dash,
  underscore,
  ctrlC,
  ctrlD,
  ctrlL,
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  f9,
  f10,
  f11,
  f12,
}

class MobileQuickKeys extends StatelessWidget {
  const MobileQuickKeys({
    super.key,
    required this.ctrlEnabled,
    required this.altEnabled,
    required this.fnEnabled,
    required this.onCtrlChanged,
    required this.onAltChanged,
    required this.onFnChanged,
    required this.onAction,
  });

  final bool ctrlEnabled;
  final bool altEnabled;
  final bool fnEnabled;
  final ValueChanged<bool> onCtrlChanged;
  final ValueChanged<bool> onAltChanged;
  final ValueChanged<bool> onFnChanged;
  final ValueChanged<MobileQuickKeyAction> onAction;

  @override
  Widget build(BuildContext context) {
    final actionButtons = fnEnabled ? _functionKeys : _navigationKeys;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            children: [
              _modifierChip(
                context,
                label: 'Ctrl',
                selected: ctrlEnabled,
                onSelected: onCtrlChanged,
              ),
              const SizedBox(width: 6),
              _modifierChip(
                context,
                label: 'Alt',
                selected: altEnabled,
                onSelected: onAltChanged,
              ),
              const SizedBox(width: 6),
              _modifierChip(
                context,
                label: 'Fn',
                selected: fnEnabled,
                onSelected: onFnChanged,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final config in actionButtons)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _actionButton(
                            context,
                            label: config.label,
                            action: config.action,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modifierChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: onSelected,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color:
            selected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required MobileQuickKeyAction action,
  }) {
    return SizedBox(
      height: 34,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: () => onAction(action),
        child: Text(
          label,
          style: const TextStyle(fontFamily: 'JetBrains Mono'),
        ),
      ),
    );
  }
}

const List<_QuickKeyConfig> _navigationKeys = [
  _QuickKeyConfig('Esc', MobileQuickKeyAction.escape),
  _QuickKeyConfig('Tab', MobileQuickKeyAction.tab),
  _QuickKeyConfig('↑', MobileQuickKeyAction.arrowUp),
  _QuickKeyConfig('↓', MobileQuickKeyAction.arrowDown),
  _QuickKeyConfig('←', MobileQuickKeyAction.arrowLeft),
  _QuickKeyConfig('→', MobileQuickKeyAction.arrowRight),
  _QuickKeyConfig('Home', MobileQuickKeyAction.home),
  _QuickKeyConfig('End', MobileQuickKeyAction.end),
  _QuickKeyConfig('PgUp', MobileQuickKeyAction.pageUp),
  _QuickKeyConfig('PgDn', MobileQuickKeyAction.pageDown),
  _QuickKeyConfig('|', MobileQuickKeyAction.pipe),
  _QuickKeyConfig('/', MobileQuickKeyAction.slash),
  _QuickKeyConfig('-', MobileQuickKeyAction.dash),
  _QuickKeyConfig('_', MobileQuickKeyAction.underscore),
  _QuickKeyConfig('Ctrl+C', MobileQuickKeyAction.ctrlC),
  _QuickKeyConfig('Ctrl+D', MobileQuickKeyAction.ctrlD),
  _QuickKeyConfig('Ctrl+L', MobileQuickKeyAction.ctrlL),
];

const List<_QuickKeyConfig> _functionKeys = [
  _QuickKeyConfig('F1', MobileQuickKeyAction.f1),
  _QuickKeyConfig('F2', MobileQuickKeyAction.f2),
  _QuickKeyConfig('F3', MobileQuickKeyAction.f3),
  _QuickKeyConfig('F4', MobileQuickKeyAction.f4),
  _QuickKeyConfig('F5', MobileQuickKeyAction.f5),
  _QuickKeyConfig('F6', MobileQuickKeyAction.f6),
  _QuickKeyConfig('F7', MobileQuickKeyAction.f7),
  _QuickKeyConfig('F8', MobileQuickKeyAction.f8),
  _QuickKeyConfig('F9', MobileQuickKeyAction.f9),
  _QuickKeyConfig('F10', MobileQuickKeyAction.f10),
  _QuickKeyConfig('F11', MobileQuickKeyAction.f11),
  _QuickKeyConfig('F12', MobileQuickKeyAction.f12),
];

class _QuickKeyConfig {
  const _QuickKeyConfig(this.label, this.action);

  final String label;
  final MobileQuickKeyAction action;
}
