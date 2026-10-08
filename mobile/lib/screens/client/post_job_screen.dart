import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/recommendation.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/media.dart';
import 'job_detail_client.dart';

const _maxImages = 5;

/// Post a job to the marketplace, or send it as a direct request to one
/// technician ([requestedTechnician]). The description is analysed live
/// so the category and urgency can be suggested by the AI.
class PostJobScreen extends StatefulWidget {
  final String? initialDescription;
  final String? initialCategory;
  final String? initialUrgency;
  final UserLite? requestedTechnician;

  const PostJobScreen({super.key, this.initialDescription, this.initialCategory, this.initialUrgency, this.requestedTechnician});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController();
  late final _desc = TextEditingController(text: widget.initialDescription ?? '');
  final _budget = TextEditingController();
  late final _city = TextEditingController(text: AuthService.instance.user?.city ?? '');
  final _location = TextEditingController();
  late String? _category = widget.initialCategory;
  late String _urgency = widget.initialUrgency ?? 'normal';
  bool _categoryTouched = false;
  DateTime? _preferredDate;
  final List<XFile> _images = [];
  bool _saving = false;

  Analysis? _suggestion;
  bool _analyzing = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _categoryTouched = widget.initialCategory != null;
    _desc.addListener(_onDescriptionChanged);
    if ((widget.initialDescription ?? '').isNotEmpty) {
      _title.text = _suggestTitle(widget.initialDescription!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_title, _desc, _budget, _city, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  String _suggestTitle(String text) {
    final first = text.split(RegExp(r'[.!?\n]')).first.trim();
    if (first.length <= 60) return first.isEmpty ? '' : first[0].toUpperCase() + first.substring(1);
    return '${first.substring(0, 57).trim()}…';
  }

  void _onDescriptionChanged() {
    _debounce?.cancel();
    final text = _desc.text.trim();
    if (text.length < 12) return;
    _debounce = Timer(const Duration(milliseconds: 700), () => _analyze(text));
  }

  Future<void> _analyze(String text) async {
    setState(() => _analyzing = true);
    try {
      final res = await ApiClient.post('/api/ai/analyze', {'text': '${_title.text} $text'.trim()});
      final a = Analysis.fromJson(Map<String, dynamic>.from(res));
      if (!mounted) return;
      setState(() {
        _suggestion = a;
        // Auto-apply until the user picks something themselves.
        if (!_categoryTouched && a.isConfident) _category = a.category;
        if (widget.initialUrgency == null && (a.urgency == 'high' || a.urgency == 'emergency') && _urgency == 'normal') {
          _urgency = a.urgency;
        }
      });
    } catch (_) {
      // Suggestions are optional.
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _addImage() async {
    final file = await pickImage(context);
    if (file != null && mounted) setState(() => _images.add(file));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _preferredDate = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_category == null) {
      toast('Pick a category so the right technicians see your job', kind: ToastKind.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await ApiClient.multipart(
        '/api/jobs',
        {
          'title': _title.text.trim(),
          'description': _desc.text.trim(),
          'category': _category!,
          'urgency': _urgency,
          if (_budget.text.trim().isNotEmpty) 'budget': _budget.text.trim(),
          'city': _city.text.trim(),
          'location': _location.text.trim(),
          if (_preferredDate != null) 'preferredDate': _preferredDate!.toIso8601String(),
          if (widget.requestedTechnician != null) 'requestedTechnician': widget.requestedTechnician!.id,
        },
        multiFiles: {'images': _images},
      );
      if (!mounted) return;
      toast(
          widget.requestedTechnician != null
              ? 'Request sent to ${widget.requestedTechnician!.name}'
              : 'Job posted — quotes will arrive soon',
          kind: ToastKind.success);
      final id = (res['_id'] ?? '').toString();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => JobDetailClient(jobId: id)), result: true);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tech = widget.requestedTechnician;
    return Scaffold(
      appBar: AppBar(title: Text(tech != null ? 'Request service' : 'Post a job')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            if (tech != null)
              Card(
                color: context.colors.primary.withValues(alpha: 0.06),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: AppAvatar(name: tech.name, url: tech.avatar, size: 44),
                  title: Text('Requesting ${tech.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Only they will see this job. If they decline, you can open it to everyone.'),
                ),
              ),
            const SizedBox(height: 12),
            _section(context, 'Describe the job'),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Fix leaking kitchen sink'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Add a short title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What\'s wrong?',
                alignLabelWithHint: true,
                hintText: 'What happened, where in the house, anything you\'ve already tried…',
              ),
              validator: (v) => (v ?? '').trim().length < 10 ? 'Describe the problem in at least 10 characters' : null,
            ),
            _aiSuggestion(context),
            _section(context, 'Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in Catalog.services)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18, color: c.color),
                    label: Text(c.label),
                    selected: _category == c.key,
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      _category = c.key;
                      _categoryTouched = true;
                    }),
                  ),
              ],
            ),
            _section(context, 'How urgent is it?'),
            LayoutBuilder(
              builder: (_, box) {
                final w = (box.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final u in UrgencyInfo.all)
                      SizedBox(
                        width: w,
                        child: _UrgencyOption(info: u, selected: _urgency == u.key, onTap: () => setState(() => _urgency = u.key)),
                      ),
                  ],
                );
              },
            ),
            _section(context, 'Budget & schedule'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _budget,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Budget (optional)', prefixText: '${Fmt.currency} '),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return null;
                      final n = double.tryParse(v!.trim());
                      return n == null || n < 0 ? 'Enter a number' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Preferred date',
                        suffixIcon: _preferredDate == null
                            ? const Icon(Icons.event_outlined)
                            : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _preferredDate = null)),
                      ),
                      child: Text(_preferredDate == null ? 'Any time' : Fmt.weekday(_preferredDate)),
                    ),
                  ),
                ),
              ],
            ),
            _section(context, 'Location'),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Area / address',
                helperText: 'Your full address is only shared with the technician you hire.',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            _section(context, 'Photos'),
            PhotoPickerGrid(
              picked: _images,
              max: _maxImages,
              onAdd: _addImage,
              onRemovePicked: (i) => setState(() => _images.removeAt(i)),
            ),
            const SizedBox(height: 6),
            Text('Photos help technicians understand the job and quote accurately.',
                style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : Icon(tech != null ? Icons.send_rounded : Icons.campaign_rounded),
            label: Text(tech != null ? 'Send request to ${tech.name.split(' ').first}' : 'Post job'),
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 0, 10),
        child: Text(title, style: context.text.titleSmall?.copyWith(fontSize: 15)),
      );

  Widget _aiSuggestion(BuildContext context) {
    final s = _suggestion;
    if (_analyzing && s == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('Analysing your description…', style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
        ]),
      );
    }
    if (s == null) return const SizedBox.shrink();
    final cat = Catalog.service(s.category);
    final u = UrgencyInfo.of(s.urgency);
    final applied = _category == s.category;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF7A5AF8).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF7A5AF8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'AI suggests '),
                  TextSpan(text: cat.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (s.urgency != 'normal') TextSpan(text: ' · ${u.label}', style: TextStyle(fontWeight: FontWeight.w700, color: u.color)),
                  TextSpan(text: '  ${((s.confidence * 100).round().clamp(1, 99))}% sure', style: TextStyle(color: context.palette.muted, fontSize: 12)),
                ]),
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            if (!applied)
              TextButton(
                onPressed: () => setState(() {
                  _category = s.category;
                  if (s.urgency != 'normal') _urgency = s.urgency;
                }),
                child: const Text('Apply'),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.check_circle_rounded, size: 20, color: context.palette.success),
              ),
          ],
        ),
      ),
    );
  }
}

class _UrgencyOption extends StatelessWidget {
  final UrgencyInfo info;
  final bool selected;
  final VoidCallback onTap;
  const _UrgencyOption({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? info.color.withValues(alpha: 0.1) : context.palette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? info.color : context.palette.border, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(info.icon, color: info.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(info.hint,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: context.palette.muted)),
                ]),
              ),
            ]),
          ),
        ),
      );
}
