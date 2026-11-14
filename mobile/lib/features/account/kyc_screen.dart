import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../kit.dart';

/// Identity verification: submit an ID and a selfie for an admin to review.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _view = GlobalKey<AsyncViewState<Kyc?>>();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: Session.instance.user?.name ?? '');
  final _number = TextEditingController();
  String _idType = 'cnic';
  XFile? _front;
  XFile? _back;
  XFile? _selfie;
  bool _busy = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<Kyc?> _load() async {
    final res = await Api.get('/api/kyc/me');
    final kyc = res is Map ? Kyc.fromJson(asJson(res)) : null;
    if (kyc != null && !_prefilled) {
      _prefilled = true;
      _name.text = kyc.fullName;
      _number.text = kyc.idNumber;
      _idType = kyc.idType;
    }
    return kyc;
  }

  Future<void> _submit(Kyc? existing) async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    if ((_front == null && (existing?.idFrontImage.isEmpty ?? true)) || (_selfie == null && (existing?.selfieImage.isEmpty ?? true))) {
      toast('Add a photo of the front of your ID and a selfie');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.upload('/api/kyc', fields: {
        'fullName': _name.text.trim(),
        'idType': _idType,
        'idNumber': _number.text.trim(),
      }, files: {
        if (_front != null) 'idFront': [_front!],
        if (_back != null) 'idBack': [_back!],
        if (_selfie != null) 'selfie': [_selfie!],
      });
      await Session.instance.refresh();
      toastOk('Submitted — we will notify you once it is reviewed');
      setState(() => _front = _back = _selfie = null);
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _photo(String label, String hint, XFile? picked, String existing, ValueChanged<XFile> onPicked, {bool camera = false, bool optional = false}) {
    final c = context.colors;
    final has = picked != null || existing.isNotEmpty;
    return Semantics(
      button: true,
      label: '$label. ${has ? 'Tap to replace' : hint}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(R.md),
        onTap: () async {
          final file = await pickPhoto(context, preferCamera: camera);
          if (file != null) onPicked(file);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.md), border: Border.all(color: has ? c.success : c.line)),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(R.sm),
              child: SizedBox(
                width: 72,
                height: 56,
                child: picked != null
                    ? LocalImage(picked)
                    : (existing.isNotEmpty ? NetImage(existing) : Container(color: c.surface, child: Icon(camera ? AppIcons.user : AppIcons.verify, color: c.muted))),
              ),
            ),
            Gap.w12,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [Text(label, style: context.text.titleSmall), if (optional) Text('  Optional', style: context.text.bodySmall)]),
                Text(has ? 'Added — tap to replace' : hint, style: context.text.bodySmall),
              ]),
            ),
            Icon(has ? AppIcons.success : AppIcons.camera, size: 20, color: has ? c.success : c.body),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Verify your identity',
        maxWidth: 720,
        body: AsyncView<Kyc?>(
          key: _view,
          // A wrapper list keeps "no record yet" (null) distinct from "failed".
          load: _load,
          builder: (context, kyc) => _body(context, kyc),
        ),
      );

  Widget _body(BuildContext context, Kyc? kyc) {
    final status = kyc?.status ?? 'none';
    final locked = status == 'approved' || status == 'pending';
    return Form(
      key: _form,
      child: PageList(children: [
        switch (status) {
          'approved' => const Notice('Your profile shows the blue verified seal. Clients see it on your quotes and profile.', title: 'You are verified', tone: Tone.success, icon: AppIcons.verified),
          'pending' => const Notice('An admin is checking your documents. This usually takes less than a day.', title: 'Under review', tone: Tone.info, icon: AppIcons.hourglass),
          'rejected' => Notice(kyc!.rejectionReason.isEmpty ? 'Please check your details and submit again.' : '${kyc.rejectionReason} Please fix this and submit again.',
              title: 'Verification was not approved', tone: Tone.danger),
          _ => const Notice('Verified members rank higher in search and AI matching, and customers trust them more. Your documents are only ever seen by SureFix admins.',
              title: 'Earn the verified seal', tone: Tone.brand, icon: AppIcons.verified),
        },
        Gap.h16,
        if (status != 'approved')
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Field(
                  label: 'Full legal name',
                  hint: 'As written on your ID',
                  controller: _name,
                  enabled: !locked,
                  capitalization: TextCapitalization.words,
                  validator: minLength(3, 'Enter your full legal name')),
              Gap.h16,
              const FieldLabel('ID type'),
              IgnorePointer(
                ignoring: locked,
                child: Pills<String>(values: idTypes.keys.toList(), label: (k) => idTypes[k]!, selected: _idType, onTap: (k) => setState(() => _idType = k)),
              ),
              Gap.h16,
              Field(label: 'ID number', hint: _idType == 'cnic' ? '35202-1234567-1' : 'Document number', controller: _number, enabled: !locked, validator: minLength(4, 'Enter a valid ID number')),
              Gap.h20,
              const FieldLabel('Photos'),
              IgnorePointer(
                ignoring: locked,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _photo('Front of ID', 'Clear, all four corners visible', _front, kyc?.idFrontImage ?? '', (f) => setState(() => _front = f)),
                  Gap.h8,
                  _photo('Back of ID', 'If your ID has a back side', _back, kyc?.idBackImage ?? '', (f) => setState(() => _back = f), optional: true),
                  Gap.h8,
                  _photo('Selfie', 'Your face, well lit, no sunglasses', _selfie, kyc?.selfieImage ?? '', (f) => setState(() => _selfie = f), camera: true),
                ]),
              ),
              if (!locked) ...[
                Gap.h20,
                Btn(status == 'rejected' ? 'Submit again' : 'Submit for review', size: BtnSize.lg, expand: true, loading: _busy, onPressed: () => _submit(kyc)),
              ],
            ]),
          ),
      ]),
    );
  }
}
