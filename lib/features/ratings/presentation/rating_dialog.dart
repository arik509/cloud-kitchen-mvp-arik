import 'package:flutter/material.dart';

import '../data/rating_repository.dart';

class RatingDialog extends StatefulWidget {
  const RatingDialog({
    required this.repository,
    required this.orderId,
    super.key,
  });
  final RatingRepository repository;
  final String orderId;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  final _review = TextEditingController();
  int _stars = 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0 || _saving) {
      if (_stars == 0) setState(() => _error = 'Choose 1–5 stars.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.submitKitchenRating(
        widget.orderId,
        _stars,
        _review.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on RatingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rate your order'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (index) => IconButton(
              key: Key('rating-star-${index + 1}'),
              onPressed: _saving
                  ? null
                  : () => setState(() => _stars = index + 1),
              icon: Icon(
                index < _stars ? Icons.star_rounded : Icons.star_border_rounded,
              ),
              color: Colors.amber.shade700,
            ),
          ),
        ),
        TextField(
          controller: _review,
          enabled: !_saving,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Review (optional)'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('submit-rating'),
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Submitting...' : 'Submit'),
      ),
    ],
  );
}
