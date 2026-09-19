import 'package:flutter/material.dart';

class ConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        const Expanded(
          child: Text(
            'I understand this app is a research and screening tool. '
            'It does NOT diagnose any medical condition. It analyzes typing '
            'patterns to detect unusual or changing motor patterns.',
          ),
        ),
      ],
    );
  }
}
