import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'icons.dart';

/// Caption shown above an input.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool optional;
  const FieldLabel(this.text, {super.key, this.optional = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Flexible(child: Text(text, style: context.text.titleSmall!.copyWith(fontSize: 13.5))),
          if (optional) Text('  Optional', style: context.text.bodySmall),
        ]),
      );
}

/// Text input with its label above.
class Field extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helper;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? action;
  final bool obscure;
  final bool optional;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final IconData? icon;
  final String? prefixText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? formatters;
  final Iterable<String>? autofill;
  final FocusNode? focusNode;
  final TextCapitalization capitalization;

  const Field({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.controller,
    this.validator,
    this.keyboardType,
    this.action,
    this.obscure = false,
    this.optional = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.icon,
    this.prefixText,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.formatters,
    this.autofill,
    this.focusNode,
    this.capitalization = TextCapitalization.none,
  });

  /// Whole-number input (prices, days).
  static List<TextInputFormatter> get digits => [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (label != null) FieldLabel(label!, optional: optional),
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : null),
        textInputAction: action ?? (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
        obscureText: obscure,
        enabled: enabled,
        autofocus: autofocus,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        inputFormatters: formatters,
        autofillHints: autofill,
        focusNode: focusNode,
        textCapitalization: capitalization,
        style: context.text.bodyLarge!.copyWith(color: c.ink, fontSize: 15.5, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          helperText: helper,
          counterText: maxLength != null && maxLines == 1 ? '' : null,
          prefixIcon: icon == null ? null : Icon(icon, size: 20),
          prefixText: prefixText,
          prefixStyle: context.text.bodyLarge!.copyWith(color: c.muted, fontSize: 15.5, fontWeight: FontWeight.w600),
          suffixIcon: suffix,
        ),
      ),
    ]);
  }
}

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? action;
  final bool isNew;
  const PasswordField({super.key, this.label = 'Password', this.hint, required this.controller, this.validator, this.onSubmitted, this.action, this.isNew = false});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => Field(
        label: widget.label,
        hint: widget.hint,
        controller: widget.controller,
        validator: widget.validator,
        obscure: _hidden,
        icon: AppIcons.lock,
        action: widget.action,
        onSubmitted: widget.onSubmitted,
        autofill: [widget.isNew ? AutofillHints.newPassword : AutofillHints.password],
        suffix: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          icon: Icon(_hidden ? AppIcons.eye : AppIcons.eyeOff, size: 20),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      );
}

/// Search input with a clear button.
class SearchBox extends StatefulWidget {
  final String hint;
  final String initial;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  const SearchBox({super.key, required this.hint, required this.onChanged, this.onSubmitted, this.initial = ''});

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
      onSubmitted: widget.onSubmitted,
      style: context.text.bodyLarge!.copyWith(color: c.ink, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(AppIcons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(AppIcons.close, size: 16),
                onPressed: () {
                  _controller.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
      ),
    );
  }
}

/// Selectable pills. Single-select by default; pass [isSelected]/[onTap]
/// semantics through [selected] (one value) or [selectedSet] (several).
class Pills<T> extends StatelessWidget {
  final List<T> values;
  final String Function(T) label;
  final IconData? Function(T)? icon;
  final T? selected;
  final Set<T>? selectedSet;
  final ValueChanged<T> onTap;
  final bool scroll;
  final EdgeInsets scrollPadding;

  const Pills({
    super.key,
    required this.values,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected,
    this.selectedSet,
    this.scroll = false,
    this.scrollPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pills = [
      for (final v in values)
        _Pill(
          label: label(v),
          icon: icon?.call(v),
          on: selectedSet?.contains(v) ?? (selected == v),
          colors: c,
          onTap: () => onTap(v),
        ),
    ];
    if (!scroll) return Wrap(spacing: 8, runSpacing: 8, children: pills);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: scrollPadding,
        itemCount: pills.length,
        separatorBuilder: (_, __) => Gap.w8,
        itemBuilder: (_, i) => pills[i],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool on;
  final AppColors colors;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.icon, required this.on, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = on ? colors.canvas : colors.ink;
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? colors.ink : colors.surface,
        shape: StadiumBorder(side: BorderSide(color: on ? colors.ink : colors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), Gap.w6],
              Text(label, style: TextStyle(fontFamily: kBodyFont, fontSize: 13.5, fontWeight: FontWeight.w700, color: fg, height: 1.2)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Two-to-four way switch (e.g. Pickup / Delivery).
class Segmented<T> extends StatelessWidget {
  final Map<T, String> options;
  final Map<T, IconData>? icons;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.icons});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.md)),
      child: Row(children: [
        for (final e in options.entries)
          Expanded(
            child: Semantics(
              button: true,
              selected: e.key == value,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e.key == value ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(R.sm),
                    boxShadow: e.key == value ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 1))] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icons?[e.key] != null) ...[Icon(icons![e.key], size: 17, color: e.key == value ? c.ink : c.muted), Gap.w6],
                    Flexible(
                      child: Text(e.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall!.copyWith(fontSize: 13.5, color: e.key == value ? c.ink : c.muted)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Dropdown with its label above.
class SelectField<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  const SelectField({super.key, this.label, this.hint, required this.value, required this.items, required this.onChanged, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (label != null) FieldLabel(label!),
      DropdownButtonFormField<T>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        icon: Icon(AppIcons.chevronDown, size: 14, color: c.muted),
        dropdownColor: c.surface,
        borderRadius: BorderRadius.circular(R.md),
        style: context.text.bodyLarge!.copyWith(color: c.ink, fontSize: 15.5, fontWeight: FontWeight.w600),
        decoration: InputDecoration(hintText: hint, prefixIcon: icon == null ? null : Icon(icon, size: 20)),
        items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      ),
    ]);
  }
}

/// Read-only field that opens a date picker.
class DateField extends StatelessWidget {
  final String label;
  final String hint;
  final DateTime? value;
  final DateTime? first;
  final DateTime? last;
  final bool optional;
  final ValueChanged<DateTime?> onChanged;
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.hint = 'Pick a date', this.first, this.last, this.optional = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      FieldLabel(label, optional: optional),
      Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(R.md),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? first ?? now,
              firstDate: first ?? now,
              lastDate: last ?? now.add(const Duration(days: 365)),
            );
            if (picked != null) onChanged(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.calendar, size: 20),
              suffixIcon: value == null || !optional
                  ? null
                  : IconButton(tooltip: 'Clear date', icon: const Icon(AppIcons.close, size: 16), onPressed: () => onChanged(null)),
            ),
            child: Text(
              value == null ? hint : longDate(value),
              style: context.text.bodyLarge!.copyWith(color: value == null ? c.muted : c.ink, fontSize: 15.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// − n + counter (rental days, stock).
class Counter extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String Function(int)? format;
  final ValueChanged<int> onChanged;
  const Counter({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 90, this.format});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget step(IconData icon, String tip, int delta) {
      final next = value + delta;
      final ok = next >= min && next <= max;
      return Semantics(
        button: true,
        label: tip,
        excludeSemantics: true,
        child: Material(
          color: ok ? c.sunken : c.sunken.withValues(alpha: 0.5),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: ok ? () => onChanged(next) : null,
            child: SizedBox.square(dimension: 40, child: Icon(icon, size: 16, color: ok ? c.ink : c.muted)),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      step(AppIcons.minus, 'Decrease', -1),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 84),
        child: Text(format?.call(value) ?? '$value', textAlign: TextAlign.center, style: context.text.titleLarge),
      ),
      step(AppIcons.add, 'Increase', 1),
    ]);
  }
}

// ------------------------------------------------------------ validators

String? Function(String?) requiredField([String message = 'This field is required']) => (v) => (v == null || v.trim().isEmpty) ? message : null;

String? validEmail(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'Enter your email address';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) ? null : 'Enter a valid email address';
}

String? validPassword(String? v) => (v == null || v.length < 6) ? 'Use at least 6 characters' : null;

String? Function(String?) minLength(int n, String message) => (v) => (v == null || v.trim().length < n) ? message : null;

String? Function(String?) positiveNumber(String message, {bool allowEmpty = false}) => (v) {
      final s = v?.trim() ?? '';
      if (s.isEmpty) return allowEmpty ? null : message;
      final n = num.tryParse(s);
      return n == null || n <= 0 ? message : null;
    };
