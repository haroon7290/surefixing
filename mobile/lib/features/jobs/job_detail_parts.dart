import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../kit.dart';

/// The technician's quote form on an open job.
class QuoteForm extends StatefulWidget {
  final Job job;
  final Estimate estimate;
  final Future<void> Function(Json body) onSubmit;
  const QuoteForm({super.key, required this.job, required this.estimate, required this.onSubmit});

  @override
  State<QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends State<QuoteForm> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.job.budget > 0 ? '${widget.job.budget.round()}' : '');
  final _message = TextEditingController();
  int _eta = 1;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amount = double.tryParse(_amount.text) ?? 0;
    final fee = (amount * 0.1).roundToDouble();
    return Panel(
      border: c.ink,
      borderWidth: 1.4,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Send your quote', style: context.text.titleLarge),
          Gap.h4,
          Text(
            widget.estimate.exists
                ? 'Jobs like this usually go for ${money(widget.estimate.low)} – ${money(widget.estimate.high)}.'
                : 'Price the whole job, including materials you will bring.',
            style: context.text.bodySmall,
          ),
          Gap.h16,
          Field(
            label: 'Your price',
            hint: widget.estimate.exists ? '${widget.estimate.typical.round()}' : '2500',
            prefixText: 'Rs  ',
            controller: _amount,
            keyboardType: TextInputType.number,
            formatters: Field.digits,
            onChanged: (_) => setState(() {}),
            validator: positiveNumber('Enter your price'),
            helper: amount > 0 ? 'Paid by wallet you receive ${money(amount - fee)} after the 10% fee. Cash has no fee.' : null,
          ),
          Gap.h16,
          const FieldLabel('When can you start?'),
          Pills<int>(
            values: const [0, 1, 2, 3, 7],
            label: (d) => d == 0 ? 'Today' : (d == 1 ? 'Tomorrow' : (d == 7 ? 'Within a week' : 'In $d days')),
            selected: _eta,
            onTap: (d) => setState(() => _eta = d),
          ),
          Gap.h16,
          Field(
            label: 'Message to the client',
            hint: 'What you will do, what is included, any questions…',
            controller: _message,
            maxLines: 3,
            minLines: 3,
            maxLength: 500,
            optional: true,
            capitalization: TextCapitalization.sentences,
          ),
          Gap.h8,
          Btn('Send quote', icon: AppIcons.send, size: BtnSize.lg, expand: true, loading: _busy, onPressed: () async {
            if (!(_form.currentState?.validate() ?? false)) return;
            setState(() => _busy = true);
            await widget.onSubmit({'amount': double.parse(_amount.text), 'etaDays': _eta, 'message': _message.text.trim()});
            if (mounted) setState(() => _busy = false);
          }),
        ]),
      ),
    );
  }
}

/// Asks the client for a star rating and an optional review.
Future<Json?> showRateSheet(BuildContext context, {required String name}) {
  var stars = 0;
  final review = TextEditingController();
  return showAppSheet<Json>(
    context,
    title: 'Rate $name',
    subtitle: 'Your review helps other customers choose.',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Stars(stars.toDouble(), size: 40, onChanged: (v) => setState(() => stars = v))),
        Gap.h8,
        Center(
          child: Text(const ['Tap a star', 'Poor', 'Below average', 'Okay', 'Good', 'Excellent'][stars], style: context.text.titleSmall),
        ),
        Gap.h20,
        Field(label: 'Write a review', hint: 'How did it go? Was the work good, on time, fairly priced?', controller: review, maxLines: 4, minLines: 3, maxLength: 1000, optional: true, capitalization: TextCapitalization.sentences),
        Gap.h8,
        Btn('Submit review', size: BtnSize.lg, expand: true, onPressed: stars == 0 ? null : () => Navigator.of(context).pop({'rating': stars, 'review': review.text.trim()})),
      ]),
    ),
  );
}

/// What the technician attaches when marking the work finished.
class DoneReport {
  final String note;
  final List<XFile> photos;
  const DoneReport(this.note, this.photos);
}

Future<DoneReport?> showDoneSheet(BuildContext context) {
  final note = TextEditingController();
  var photos = <XFile>[];
  return showAppSheet<DoneReport>(
    context,
    title: 'Mark work as finished',
    subtitle: 'Tell the client what you did. Photos of the result help them confirm quickly.',
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field(label: 'What was done', hint: 'e.g. Replaced the tap cartridge and sealed the joint. Tested for leaks.', controller: note, maxLines: 4, minLines: 3, maxLength: 500, optional: true, capitalization: TextCapitalization.sentences),
        Gap.h8,
        const FieldLabel('Photos of the finished work', optional: true),
        PhotoPicker(picked: photos, onChanged: (v) => setState(() => photos = v), max: 4),
        Gap.h20,
        Btn('Finish & ask client to confirm', icon: AppIcons.check, size: BtnSize.lg, expand: true, onPressed: () => Navigator.of(context).pop(DoneReport(note.text.trim(), photos))),
      ]),
    ),
  );
}

/// The job's activity log, newest last.
class JobTimeline extends StatelessWidget {
  final List<JobEvent> events;
  const JobTimeline(this.events, {super.key});

  static (String, IconData, Tone) _look(String event) => switch (event) {
        'posted' => ('Job posted', AppIcons.note, Tone.neutral),
        'bid' => ('Quote received', AppIcons.tag, Tone.info),
        'bid_withdrawn' => ('Quote withdrawn', AppIcons.close, Tone.neutral),
        'request_declined' => ('Request declined', AppIcons.blocked, Tone.danger),
        'opened' => ('Opened to all technicians', AppIcons.megaphone, Tone.info),
        'hired' => ('Technician hired', AppIcons.handshake, Tone.brand),
        'on_the_way' => ('On the way', AppIcons.route, Tone.brand),
        'working' => ('Work started', AppIcons.wrench, Tone.brand),
        'done' => ('Work finished', AppIcons.check, Tone.warning),
        'completed' => ('Completed and paid', AppIcons.success, Tone.success),
        'cancelled' => ('Cancelled', AppIcons.close, Tone.danger),
        'technician_withdrew' => ('Technician withdrew', AppIcons.swap, Tone.warning),
        'rated' => ('Review left', AppIcons.starFill, Tone.warning),
        _ => (humanize(event), AppIcons.circle, Tone.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < events.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              IconTile(_look(events[i].event).$2, tone: _look(events[i].event).$3, size: 30, round: true),
              if (i < events.length - 1) Expanded(child: Container(width: 2, color: c.line, margin: const EdgeInsets.symmetric(vertical: 2))),
            ]),
            Gap.w12,
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < events.length - 1 ? 16 : 0, top: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: Text(_look(events[i].event).$1, style: context.text.titleSmall)),
                    Text(timeAgo(events[i].at), style: context.text.bodySmall!.copyWith(fontSize: 11.5)),
                  ]),
                  if (events[i].note.isNotEmpty && events[i].event != 'posted')
                    Padding(padding: const EdgeInsets.only(top: 2), child: Text(events[i].note, style: context.text.bodySmall!.copyWith(color: c.body))),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
