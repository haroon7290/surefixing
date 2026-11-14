import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../kit.dart';
import 'job_detail_screen.dart';
import 'job_widgets.dart';

/// Post a job. As the customer types, the AI suggests the trade and
/// urgency and shows what such jobs usually cost. With [technician] set it
/// becomes a direct request to that technician.
class PostJobScreen extends StatefulWidget {
  final String? category;
  final String? description;
  final User? technician;
  const PostJobScreen({super.key, this.category, this.description, this.technician});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _form = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.description ?? '');
  final _title = TextEditingController();
  final _budget = TextEditingController();
  late final _location = TextEditingController(text: Session.instance.user?.address ?? '');

  late String? _category = widget.category;
  String _urgency = 'normal';
  late String? _city = cities.contains(Session.instance.user?.city) ? Session.instance.user!.city : null;
  DateTime? _date;
  List<XFile> _photos = [];

  bool _categoryChosen = false; // the customer picked one by hand
  bool _urgencyChosen = false;
  Analysis? _analysis;
  Estimate _estimate = const Estimate();
  bool _thinking = false;
  bool _busy = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _categoryChosen = widget.category != null;
    if (_description.text.trim().length >= 12) {
      _analyze();
    } else if (_category != null) {
      _refreshEstimate();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_description, _title, _budget, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onDescriptionChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 12) return;
    _debounce = Timer(const Duration(milliseconds: 900), _analyze);
  }

  Future<void> _analyze() async {
    final text = _description.text.trim();
    if (text.length < 12) return;
    setState(() => _thinking = true);
    try {
      final a = Analysis.fromJson(await Api.post('/api/ai/analyze', {'text': text}));
      if (!mounted) return;
      setState(() {
        _analysis = a;
        if (!_categoryChosen && a.confident) _category = a.category;
        if (!_urgencyChosen) _urgency = a.urgency;
        if (_category == a.category && _urgency == a.urgency) _estimate = a.estimate;
      });
      if (_category != a.category || _urgency != a.urgency) _refreshEstimate();
    } catch (_) {
      // The AI hint is a bonus; the form works without it.
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<void> _refreshEstimate() async {
    final category = _category;
    if (category == null) return;
    try {
      final e = Estimate.fromJson(await Api.map('/api/ai/estimate', query: {'category': category, 'urgency': _urgency}));
      if (mounted && _category == category) setState(() => _estimate = e);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    if (_category == null) {
      toast('Choose the type of work');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.upload('/api/jobs', fields: {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category!,
        'urgency': _urgency,
        if (_budget.text.isNotEmpty) 'budget': _budget.text,
        'location': _location.text.trim(),
        'city': _city ?? '',
        if (_date != null) 'preferredDate': _date!.toIso8601String(),
        if (widget.technician != null) 'requestedTechnician': widget.technician!.id,
      }, files: {
        'images': _photos
      });
      final job = Job.fromJson(asJson(res));
      toastOk(widget.technician == null ? 'Job posted — quotes will arrive soon' : 'Request sent to ${widget.technician!.firstName}');
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id), settings: RouteSettings(name: '/jobs/${job.id}')));
      }
    } catch (e) {
      toastError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tech = widget.technician;
    final a = _analysis;
    final suggested = a != null && a.confident ? a.category : null;

    final details = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (tech != null) ...[
        Panel(
          color: c.brandSoft,
          border: Colors.transparent,
          child: PersonRow(name: tech.name, image: tech.avatar, verified: tech.verified, subtitle: 'This request goes only to them. You can open it to everyone later.'),
        ),
        Gap.h16,
      ],
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Field(
            label: 'What is the problem?',
            hint: 'e.g. The kitchen tap has been dripping for two days and there is water under the sink.',
            controller: _description,
            maxLines: 5,
            minLines: 4,
            maxLength: 3000,
            capitalization: TextCapitalization.sentences,
            onChanged: _onDescriptionChanged,
            validator: minLength(10, 'Describe the problem in at least 10 characters'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topLeft,
            child: _thinking || a != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Icon(AppIcons.sparkleFill, size: 16, color: c.brand),
                      Gap.w8,
                      Expanded(
                        child: Text(
                          _thinking
                              ? 'Reading your description…'
                              : (a!.confident
                                  ? 'Looks like ${serviceCategory(a.category).label.toLowerCase()} · ${urgencyLabel(a.urgency).toLowerCase()}'
                                  : 'Add a little more detail and we will suggest the right trade'),
                          style: context.text.bodySmall!.copyWith(color: c.brandDeep, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Gap.h16,
          Field(
            label: 'Give it a short title',
            hint: 'e.g. Fix leaking kitchen tap',
            controller: _title,
            maxLength: 120,
            capitalization: TextCapitalization.sentences,
            validator: minLength(3, 'Add a short title'),
          ),
        ]),
      ),
      Gap.h16,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const FieldLabel('Type of work'),
          Pills<CatalogItem>(
            values: serviceCategories,
            label: (cat) => cat.key == suggested && cat.key != _category ? '${cat.label} ✦' : cat.label,
            icon: (cat) => cat.icon,
            selected: _category == null ? null : serviceCategory(_category!),
            onTap: (cat) {
              setState(() {
                _category = cat.key;
                _categoryChosen = true;
              });
              _refreshEstimate();
            },
          ),
          Gap.h20,
          const FieldLabel('How soon?'),
          Pills<String>(
            values: urgencyLevels,
            label: urgencyLabel,
            selected: _urgency,
            onTap: (u) {
              setState(() {
                _urgency = u;
                _urgencyChosen = true;
              });
              _refreshEstimate();
            },
          ),
        ]),
      ),
      Gap.h16,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const FieldLabel('Photos', optional: true),
          PhotoPicker(picked: _photos, onChanged: (v) => setState(() => _photos = v), max: 5),
          Gap.h8,
          Text('A photo of the problem helps technicians quote accurately.', style: context.text.bodySmall),
        ]),
      ),
    ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (_estimate.exists) ...[EstimateBox(_estimate), Gap.h16],
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Field(
            label: 'Your budget',
            hint: _estimate.exists ? '${_estimate.typical.round()}' : '3000',
            prefixText: 'Rs  ',
            controller: _budget,
            optional: true,
            keyboardType: TextInputType.number,
            formatters: Field.digits,
            helper: 'Leave empty to let technicians suggest a price.',
          ),
          Gap.h16,
          DateField(label: 'Preferred date', value: _date, optional: true, hint: 'Any time', onChanged: (d) => setState(() => _date = d)),
          Gap.h16,
          SelectField<String>(label: 'City', hint: 'Choose your city', value: _city, icon: AppIcons.city, items: {for (final c in cities) c: c}, onChanged: (v) => setState(() => _city = v)),
          Gap.h16,
          Field(
              label: 'Address', hint: 'House, street, area', controller: _location, icon: AppIcons.pin, optional: true, maxLength: 200, helper: 'Shared with the technician only after you hire them.'),
        ]),
      ),
      if (context.isWide) ...[
        Gap.h16,
        Btn(tech == null ? 'Post job' : 'Send request', size: BtnSize.lg, expand: true, loading: _busy, onPressed: _submit),
        Gap.h8,
        Text('Free to post. You only pay when you hire.', textAlign: TextAlign.center, style: context.text.bodySmall),
      ],
    ]);

    return AppPage(
      title: tech == null ? 'Post a job' : 'Request ${tech.firstName}',
      subtitle: context.isWide ? 'Describe it once. Verified technicians reply with quotes.' : null,
      bottom: context.isWide ? null : Btn(tech == null ? 'Post job' : 'Send request', size: BtnSize.lg, expand: true, loading: _busy, onPressed: _submit),
      body: Form(key: _form, child: PageList(children: [TwoCol(main: details, side: side)])),
    );
  }
}
