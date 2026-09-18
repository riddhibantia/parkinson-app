import 'package:flutter/material.dart';

/// Common questions (Stage 9.1/9.4 language rules apply throughout).
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _items = [
    (
      'What data does the app collect?',
      'Only key-press timing (press/release moments), derived hand position, '
          'tapping-task mechanics, session metadata, and details you choose '
          'to provide (practice answers, check-ins). The text you type is '
          'never stored or sent.'
    ),
    (
      'Why does the app need keyboard access?',
      'On desktop, timing your typing needs OS key-event access. Capture runs '
          'only inside the typing field during an active session — never in '
          'other apps, and it stops the moment you leave the typing screen.'
    ),
    (
      'Does the app diagnose Parkinson\'s?',
      'No. It flags unusual or changing timing patterns and recommends '
          'discussing persistent changes with a healthcare professional.'
    ),
    (
      'What do practice sessions do?',
      'Practice helps you get comfortable with the typing task so typing '
          'skill is not mistaken for a motor-pattern difference. Practice is '
          'never scored and never enters your baseline.'
    ),
    (
      'Can I delete my data?',
      'Yes — Settings offers full local data deletion at any time, plus a '
          'JSON export of what this device holds.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (q, a) in _items)
            Card(
              child: ExpansionTile(
                title: Text(q),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(a),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
