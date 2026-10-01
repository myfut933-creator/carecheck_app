import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/visit.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import '../services/incident_service.dart';
import '../utils/app_exception.dart';
import '../utils/validators.dart';

/// Screen 5: Report Incident (camera evidence + optional human-approved AI draft).
class IncidentScreen extends StatefulWidget {
  const IncidentScreen({super.key, required this.visit});
  final Visit visit;

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  static const categories = [
    'Trip / fall hazard',
    'Injury',
    'Equipment damage',
    'Change in condition',
    'Medication concern',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _aiText = TextEditingController();

  String _category = categories.first;
  String _severity = 'Medium';
  XFile? _photo;
  String? _uploadedUrl;
  double? _progress;
  bool _busy = false;
  bool _aiBusy = false;
  bool _usedAi = false;
  AiDraft? _draft;

  @override
  void dispose() {
    _description.dispose();
    _aiText.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Camera sensor ----
  Future<void> _takePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (photo != null && mounted) {
        setState(() {
          _photo = photo;
          _uploadedUrl = null; // a new photo needs uploading
        });
      }
    } on PlatformException {
      if (mounted) {
        _snack(
            'Camera is not available or permission was denied. Check phone settings.');
      }
    }
  }

  // ---- AI draft (human-in-the-loop) ----
  Future<void> _improve() async {
    final problem = Validators.incident(_description.text);
    if (problem != null) {
      _snack('Write a short description first. $problem');
      return;
    }
    final ai = context.read<AiService>();
    setState(() => _aiBusy = true);
    try {
      final draft = await ai.improve(
        category: _category,
        severity: _severity,
        clientAlias: widget.visit.clientAlias, // alias only, never name/address
        text: _description.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _aiText.text = draft.draft;
      });
    } on AppException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  void _acceptDraft() {
    setState(() {
      _description.text = _aiText.text.trim();
      _usedAi = true;
      _draft = null;
    });
  }

  // ---- Submit ----
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) {
      _snack('Please sign in again.');
      return;
    }
    final service = context.read<IncidentService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    try {
      var url = _uploadedUrl;
      if (_photo != null && url == null) {
        url = await service.uploadPhoto(uid, _photo!, onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        });
        _uploadedUrl = url; // avoid re-uploading if the next step fails
      }
      final synced = await service.submit(
        uid: uid,
        visitId: widget.visit.id,
        clientAlias: widget.visit.clientAlias,
        category: _category,
        severity: _severity,
        description: _description.text,
        aiAssisted: _usedAi,
        photoUrl: url,
      );
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(synced
            ? 'Incident reported.'
            : 'Incident saved on this device and will upload when you are online.'),
      ));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          action: SnackBarAction(label: 'Retry', onPressed: _submit),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiAvailable = context.read<AiService>().isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Report incident')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Client: ${widget.visit.clientAlias}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Text('Category',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Severity',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Low', label: Text('Low')),
                  ButtonSegment(value: 'Medium', label: Text('Medium')),
                  ButtonSegment(value: 'High', label: Text('High')),
                ],
                selected: {_severity},
                onSelectionChanged: (s) => setState(() => _severity = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'What happened?',
                  helperText: 'Do not type the client\'s full name.',
                  alignLabelWithHint: true,
                ),
                validator: Validators.incident,
              ),
              const SizedBox(height: 8),
              if (aiAvailable)
                OutlinedButton.icon(
                  onPressed: (_busy || _aiBusy) ? null : _improve,
                  icon: _aiBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high),
                  label: const Text('Improve wording (AI suggestion)'),
                )
              else
                const Text(
                  'AI wording help is not configured in this build.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              if (_draft != null) _aiCard(_draft!),
              const SizedBox(height: 16),
              const Text('Photo evidence (optional)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (_photo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_photo!.path),
                      height: 180, fit: BoxFit.cover),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _takePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_photo == null ? 'Take photo' : 'Retake'),
                    ),
                  ),
                  if (_photo != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _photo = null;
                                _uploadedUrl = null;
                              }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
              if (_progress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 4),
                Text('Uploading photo... ${(_progress! * 100).round()}%'),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aiCard(AiDraft draft) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI suggestion - please check before using',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _aiText,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            if (draft.missingDetails.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Consider adding:'),
              for (final m in draft.missingDetails) Text('\u2022 $m'),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                    onPressed: _acceptDraft,
                    child: const Text('Use this text'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44)),
                    onPressed: () => setState(() => _draft = null),
                    child: const Text('Discard'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
