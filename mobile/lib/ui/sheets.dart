import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import 'buttons.dart';
import 'cards.dart';
import 'icons.dart';
import 'inputs.dart';

/// Opens a panel for a short task: a bottom sheet on phones, a centred
/// dialog on wide windows. [builder] returns the content under the title.
Future<T?> showAppSheet<T>(BuildContext context, {required String title, String? subtitle, required WidgetBuilder builder}) {
  Widget frame(BuildContext context, {required bool dialog}) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!dialog)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: context.text.headlineSmall),
                  if (subtitle != null) ...[Gap.h4, Text(subtitle, style: context.text.bodyMedium)],
                ]),
              ),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: Icon(AppIcons.close, size: 18, color: c.body)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), child: builder(context)),
          ),
        ]),
      ),
    );
  }

  if (context.isWide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: frame(context, dialog: true)),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => frame(context, dialog: false),
  );
}

/// Asks "are you sure?". Returns true when confirmed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = false,
  IconData? icon,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconTile(icon ?? (danger ? AppIcons.warning : AppIcons.question), tone: danger ? Tone.danger : Tone.brand, size: 48),
            Gap.h16,
            Text(title, style: context.text.headlineSmall),
            if (message != null) ...[Gap.h8, Text(message, style: context.text.bodyMedium)],
            Gap.h24,
            Row(children: [
              Expanded(child: Btn(cancelLabel, kind: BtnKind.outline, expand: true, onPressed: () => Navigator.of(context).pop(false))),
              Gap.w12,
              Expanded(
                child: Btn(confirmLabel, kind: danger ? BtnKind.danger : BtnKind.primary, expand: true, onPressed: () => Navigator.of(context).pop(true)),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// Asks for a line or two of text (a reason, a note). Returns null when
/// cancelled; an empty string is allowed unless [mandatory].
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? message,
  String? label,
  String? hint,
  String confirmLabel = 'Send',
  bool mandatory = false,
  bool danger = false,
  int maxLength = 300,
}) {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  return showAppSheet<String>(
    context,
    title: title,
    subtitle: message,
    builder: (context) => Form(
      key: form,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field(
          label: label,
          hint: hint,
          controller: controller,
          maxLines: 3,
          minLines: 3,
          maxLength: maxLength,
          autofocus: true,
          optional: !mandatory && label != null,
          capitalization: TextCapitalization.sentences,
          validator: mandatory ? requiredField('Please add a few words') : null,
        ),
        Gap.h16,
        Btn(
          confirmLabel,
          kind: danger ? BtnKind.danger : BtnKind.primary,
          size: BtnSize.lg,
          expand: true,
          onPressed: () {
            if (form.currentState?.validate() ?? true) Navigator.of(context).pop(controller.text.trim());
          },
        ),
      ]),
    ),
  );
}
