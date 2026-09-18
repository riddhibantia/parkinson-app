import 'package:flutter/material.dart';

/// Medical disclaimer (Stage 9.1, plan-exact wording).
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disclaimer')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app is a research and screening tool. It does NOT '
              'diagnose any medical condition. It analyzes typing patterns '
              'to detect unusual or changing motor patterns. Always consult '
              'a qualified healthcare professional for medical advice.',
            ),
            SizedBox(height: 12),
            Text(
              'This is not a medical diagnosis. Results are for '
              'informational purposes only.',
            ),
            SizedBox(height: 12),
            Text(
              'Where the app suggests consulting a doctor: it detects '
              'patterns, it does not diagnose conditions.',
            ),
          ],
        ),
      ),
    );
  }
}
