import 'package:flutter/material.dart';

import '../../design/context_ext.dart';
import '../controls/fermata_button.dart';

/// Yes/no confirmation. Use [ConfirmDialog.show].
///
/// With [typedConfirmation] the user must type that word before the confirm
/// button enables (e.g. "Delete all data").
class ConfirmDialog extends StatefulWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
    this.typedConfirmation,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String? cancelLabel;
  final bool destructive;
  final String? typedConfirmation;

  /// Returns true when confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    required String confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    String? typedConfirmation,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        typedConfirmation: typedConfirmation,
      ),
    );
    return result ?? false;
  }

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _canConfirm => widget.typedConfirmation == null || _typed.text.trim() == widget.typedConfirmation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) Text(widget.message!),
            if (widget.typedConfirmation != null) ...[
              const SizedBox(height: 16),
              Text(l10n.shellTypeToConfirm(widget.typedConfirmation!), style: context.type.bodySmall),
              const SizedBox(height: 8),
              TextField(controller: _typed, autofocus: true, onChanged: (_) => setState(() {})),
            ],
          ],
        ),
      ),
      actions: [
        FermataButton(
          label: widget.cancelLabel ?? l10n.actionCancel,
          variant: FermataButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        FermataButton(
          label: widget.confirmLabel,
          variant: widget.destructive ? FermataButtonVariant.danger : FermataButtonVariant.primary,
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}

/// Single-line text prompt (rename, new playlist). Use [TextInputDialog.show].
class TextInputDialog extends StatefulWidget {
  const TextInputDialog({
    super.key,
    required this.title,
    this.initialValue = '',
    this.hint,
    required this.confirmLabel,
    this.validator,
    this.maxLength = 200,
  });

  final String title;
  final String initialValue;
  final String? hint;
  final String confirmLabel;

  /// Returns an error message for invalid input, or null.
  final String? Function(String value)? validator;
  final int maxLength;

  /// Returns the trimmed text, or null when canceled / empty.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String initialValue = '',
    String? hint,
    required String confirmLabel,
    String? Function(String value)? validator,
  }) =>
      showDialog<String>(
        context: context,
        builder: (_) => TextInputDialog(
          title: title,
          initialValue: initialValue,
          hint: hint,
          confirmLabel: confirmLabel,
          validator: validator,
        ),
      );

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initialValue.length);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          decoration: InputDecoration(hintText: widget.hint, errorText: _error, counterText: ''),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        FermataButton(
          label: l10n.actionCancel,
          variant: FermataButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => FermataButton(
            label: widget.confirmLabel,
            onPressed: value.text.trim().isEmpty ? null : _submit,
          ),
        ),
      ],
    );
  }
}
