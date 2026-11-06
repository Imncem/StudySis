import 'package:flutter/material.dart';

import '../models/review_item.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    required this.title,
    required this.itemsFuture,
    this.onComplete,
    this.moduleNavigation,
    this.moduleMetadata,
    super.key,
  });

  final String title;
  final Future<List<ReviewItem>> itemsFuture;
  final Future<void> Function()? onComplete;
  final Widget? moduleNavigation;
  final Widget? moduleMetadata;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _saving = false;
  bool _completed = false;

  Future<void> _complete() async {
    if (_saving || _completed) return;
    setState(() => _saving = true);
    try {
      await widget.onComplete?.call();
      if (mounted) setState(() => _completed = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: widget.moduleMetadata == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(66),
                child: widget.moduleMetadata!,
              ),
      ),
      bottomNavigationBar: widget.moduleNavigation,
      body: FutureBuilder<List<ReviewItem>>(
        future: widget.itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Review could not be loaded.'));
          }
          final items = snapshot.data ?? const <ReviewItem>[];
          if (items.isEmpty) {
            return const Center(child: Text('Review items are coming soon.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text('Review', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(widget.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              for (final item in items) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.heading,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Text(item.body),
                        if (item.keyPoint.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text('Key point',
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text(item.keyPoint),
                        ],
                        if (item.prompt.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(item.prompt,
                              style:
                                  const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('complete-review-button'),
                onPressed: _saving || _completed ? null : _complete,
                icon: Icon(
                    _completed ? Icons.check_rounded : Icons.done_all_rounded),
                label: Text(
                    _completed ? 'Review complete' : 'Mark Review complete'),
              ),
            ],
          );
        },
      ),
    );
  }
}
