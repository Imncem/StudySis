import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/muffin.dart';
import '../services/muffin_service.dart';

class QuickTranslateScreen extends StatefulWidget {
  const QuickTranslateScreen({this.muffinService, super.key});

  final MuffinService? muffinService;

  @override
  State<QuickTranslateScreen> createState() => _QuickTranslateScreenState();
}

class _QuickTranslateScreenState extends State<QuickTranslateScreen> {
  static const _languages = [
    'Auto-detect source language',
    'Bahasa Melayu',
    'English',
  ];
  static const _maxInputLength = 700;

  final _controller = TextEditingController();
  late final MuffinService _service;
  String _source = _languages.first;
  String _target = 'Bahasa Melayu';
  MuffinResponse? _response;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.muffinService ?? MuffinServiceFactory.create();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    if (_loading) return;
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Type or paste a word or sentence first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final safeInput = input.length > _maxInputLength
        ? '${input.substring(0, _maxInputLength).trimRight()}...'
        : input;
    final response = await _service.ask(
      MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.translate,
        context: MuffinContext(
          mode: MuffinMode.learn,
          currentScreen: 'quick_translate',
          originalScreenContent: safeInput,
          currentMuffinContent: safeInput,
          targetLanguage: _target,
          relevantNotes: ['Source language: $_source'],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (response.responseType == MuffinResponseType.error) {
        _error = response.message;
      } else {
        _response = response;
      }
    });
  }

  void _swapLanguages() {
    if (_source == _languages.first) return;
    setState(() {
      final oldSource = _source;
      _source = _target;
      _target = oldSource;
    });
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _response = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final translatedText = _response?.translatedText ?? _response?.message;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Quick Translate'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              'Translate a difficult word or sentence.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: _maxInputLength,
              decoration: const InputDecoration(
                hintText: 'Type or paste a word or sentence.',
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _LanguageSelector(
              label: 'From',
              value: _source,
              items: _languages,
              onChanged: (value) => setState(() => _source = value),
            ),
            const SizedBox(height: 10),
            Center(
              child: IconButton(
                tooltip: 'Swap languages',
                onPressed: _source == _languages.first ? null : _swapLanguages,
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ),
            _LanguageSelector(
              label: 'To',
              value: _target,
              items: const ['Bahasa Melayu', 'English'],
              onChanged: (value) => setState(() => _target = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _translate,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Translate'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _clear,
              child: const Text('Clear'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ResultCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _loading ? null : _translate,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
            if (translatedText != null && _error == null) ...[
              const SizedBox(height: 16),
              _ResultCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(_controller.text.trim()),
                    const SizedBox(height: 14),
                    Text(
                      'Translation',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(translatedText),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: translatedText)),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}
