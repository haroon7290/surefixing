import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'rating_stars.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirm = 'Confirm',
  String cancel = 'Cancel',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message, style: TextStyle(color: ctx.palette.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: ctx.palette.danger, minimumSize: const Size(0, 44))
              : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Asks for a short piece of text (e.g. a cancellation reason). Returns
/// null when dismissed.
Future<String?> promptDialog(
  BuildContext context, {
  required String title,
  String? message,
  String hint = '',
  String confirm = 'Submit',
  bool required = false,
  bool destructive = false,
  int maxLines = 3,
}) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(message, style: TextStyle(color: ctx.palette.muted)),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: ctl,
              autofocus: true,
              maxLines: maxLines,
              minLines: 1,
              decoration: InputDecoration(hintText: hint),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: destructive ? ctx.palette.danger : null,
            ),
            onPressed: required && ctl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, ctl.text.trim()),
            child: Text(confirm),
          ),
        ],
      ),
    ),
  );
}

class RatingResult {
  final int rating;
  final String review;
  RatingResult(this.rating, this.review);
}

/// Bottom sheet with 5 tappable stars and an optional review.
Future<RatingResult?> showRatingSheet(BuildContext context, {required String title, String? subtitle}) {
  int rating = 5;
  final ctl = TextEditingController();
  const labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];
  return showModalBottomSheet<RatingResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: ctx.text.titleLarge, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: ctx.palette.muted), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            RatingInput(value: rating, size: 44, onChanged: (v) => setState(() => rating = v)),
            const SizedBox(height: 6),
            Text(labels[rating], style: ctx.text.titleSmall?.copyWith(color: ctx.palette.star)),
            const SizedBox(height: 18),
            TextField(
              controller: ctl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Share a few words about your experience (optional)'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, RatingResult(rating, ctl.text.trim())),
                child: const Text('Submit review'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
