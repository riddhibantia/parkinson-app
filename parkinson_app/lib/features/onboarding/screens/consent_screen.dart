import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/consent_checkbox.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _consented = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & consent')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Only timing data is collected — key press and release moments '
              'plus derived hand position. The text you type is never stored '
              'or sent anywhere.',
            ),
            const SizedBox(height: 16),
            ConsentCheckbox(
              value: _consented,
              onChanged: (v) => setState(() => _consented = v ?? false),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _consented
                  ? () => context.go('/onboarding/typing-experience')
                  : null,
              child: const Text('I agree — continue'),
            ),
          ],
        ),
      ),
    );
  }
}
