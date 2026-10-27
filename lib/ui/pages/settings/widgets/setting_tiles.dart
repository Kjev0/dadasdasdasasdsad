import 'package:flutter/material.dart';

import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/controls/segmented_tabs.dart';

/// A titled card that groups related settings rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, this.description, required this.children});

  final String? title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = children.whereType<Widget>().toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Semantics(header: true, child: Text(title!, style: context.type.label.copyWith(color: c.textSecondary))),
            ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(description!, style: context.type.bodySmall),
            ),
          // A Material (not a DecoratedBox) so ListTile ink stays visible.
          Material(
            color: c.surface,
            shape: RoundedRectangleBorder(borderRadius: context.radii.mdAll, side: BorderSide(color: c.outlineSubtle)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: c.outlineSubtle, indent: 16, endIndent: 16),
                  visible[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Title + optional description column used by every settings row.
class _RowText extends StatelessWidget {
  const _RowText({required this.title, this.subtitle, this.enabled = true});

  final String title;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.type.body.copyWith(color: enabled ? c.textPrimary : c.textTertiary)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: context.type.bodySmall.copyWith(color: enabled ? c.textSecondary : c.textTertiary)),
        ],
      ],
    );
  }
}

/// On/off setting. When [onChanged] is null the row is disabled and
/// [disabledReason] (if any) replaces the subtitle so the user knows why.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabledReason,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? disabledReason;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final sub = !enabled && disabledReason != null ? disabledReason : subtitle;
    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 22, color: context.colors.textSecondary), const SizedBox(width: 14)],
              Expanded(child: _RowText(title: title, subtitle: sub, enabled: enabled)),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slider setting. The value is previewed while dragging ([onPreview]) and
/// committed once ([onChanged]) when the drag ends, so a drag does not
/// write the settings file dozens of times.
class SettingSlider extends StatefulWidget {
  const SettingSlider({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.format,
    required this.onChanged,
    this.onPreview,
    this.disabledReason,
    this.semanticFormat,
  });

  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double value) format;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double?>? onPreview;
  final String? disabledReason;
  final String Function(double value)? semanticFormat;

  @override
  State<SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<SettingSlider> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final value = (_drag ?? widget.value).clamp(widget.min, widget.max);
    final sub = !enabled && widget.disabledReason != null ? widget.disabledReason : widget.subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _RowText(title: widget.title, subtitle: sub, enabled: enabled)),
              const SizedBox(width: 12),
              Text(widget.format(value), style: context.type.label.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          Slider(
            value: value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: widget.format(value),
            semanticFormatterCallback: widget.semanticFormat ?? widget.format,
            onChangeStart: enabled ? (v) => setState(() => _drag = v) : null,
            onChanged: enabled
                ? (v) {
                    setState(() => _drag = v);
                    widget.onPreview?.call(v);
                  }
                : null,
            onChangeEnd: enabled
                ? (v) {
                    setState(() => _drag = null);
                    widget.onPreview?.call(null);
                    widget.onChanged!(v);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// One option of a [SettingChoice].
class SettingOption<T> {
  const SettingOption(this.value, this.label, {this.description});

  final T value;
  final String label;
  final String? description;
}

/// Pick one of a few values. Three or fewer short options render as a
/// segmented control, otherwise as a dropdown.
class SettingChoice<T> extends StatelessWidget {
  const SettingChoice({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
    this.disabledReason,
    this.forceDropdown = false,
  });

  final String title;
  final String? subtitle;
  final T value;
  final List<SettingOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String? disabledReason;
  final bool forceDropdown;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final sub = !enabled && disabledReason != null ? disabledReason : subtitle;
    final segmented = !forceDropdown && options.length <= 3 && options.every((o) => o.label.length <= 14);
    final selected = options.where((o) => o.value == value).firstOrNull;
    final control = segmented
        ? IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: SegmentedTabs<T>(
                tabs: [for (final o in options) SegmentedTab(o.value, o.label)],
                selected: value,
                onChanged: (v) => onChanged?.call(v),
              ),
            ),
          )
        : DropdownButton<T>(
            value: selected?.value,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            borderRadius: context.radii.mdAll,
            onChanged: enabled
                ? (v) {
                    if (v != null) onChanged!(v);
                  }
                : null,
            items: [
              for (final o in options)
                DropdownMenuItem(value: o.value, child: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = _RowText(title: title, subtitle: selected?.description ?? sub, enabled: enabled);
        final narrow = constraints.maxWidth < 520;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [text, const SizedBox(height: 10), segmented ? control : SizedBox(width: double.infinity, child: control)],
                )
              : Row(children: [
                  Expanded(child: text),
                  const SizedBox(width: 16),
                  if (segmented) control else SizedBox(width: 240, child: control),
                ]),
        );
      },
    );
  }
}

/// A row that runs an action (button on the right, or the whole row).
class SettingAction extends StatelessWidget {
  const SettingAction({
    super.key,
    required this.title,
    this.subtitle,
    required this.actionLabel,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final button = FermataButton(
        label: actionLabel,
        icon: icon,
        busy: busy,
        variant: destructive ? FermataButtonVariant.danger : FermataButtonVariant.secondary,
        onPressed: onPressed,
      );
      final text = _RowText(title: title, subtitle: subtitle);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: constraints.maxWidth < 420
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 10), button])
            : Row(children: [Expanded(child: text), const SizedBox(width: 16), button]),
      );
    });
  }
}

/// Read-only row: a label and a value (selectable text).
class SettingInfo extends StatelessWidget {
  const SettingInfo({super.key, required this.title, required this.value, this.trailing});

  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type.body),
                const SizedBox(height: 2),
                SelectableText(value, style: context.type.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

enum NoteTone { info, warning, success }

/// Explanatory note inside or between groups.
class SettingNote extends StatelessWidget {
  const SettingNote({super.key, required this.text, this.tone = NoteTone.info, this.icon, this.action, this.inGroup = false});

  final String text;
  final NoteTone tone;
  final IconData? icon;
  final Widget? action;

  /// Rendered as a row inside a [SettingsGroup] (no own card).
  final bool inGroup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (tone) {
      NoteTone.info => c.textSecondary,
      NoteTone.warning => c.warning,
      NoteTone.success => c.success,
    };
    final iconData = icon ??
        switch (tone) {
          NoteTone.info => Icons.info_outline_rounded,
          NoteTone.warning => Icons.warning_amber_rounded,
          NoteTone.success => Icons.check_circle_outline_rounded,
        };
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(iconData, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: context.type.bodySmall.copyWith(color: c.textSecondary)),
              if (action != null) ...[const SizedBox(height: 8), action!],
            ],
          ),
        ),
      ],
    );
    if (inGroup) return Padding(padding: const EdgeInsets.all(16), child: body);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tone == NoteTone.info ? c.surfaceHigh.withValues(alpha: 0.5) : color.withValues(alpha: 0.10),
          borderRadius: context.radii.mdAll,
          border: Border.all(color: tone == NoteTone.info ? c.outlineSubtle : color.withValues(alpha: 0.4)),
        ),
        child: body,
      ),
    );
  }
}
