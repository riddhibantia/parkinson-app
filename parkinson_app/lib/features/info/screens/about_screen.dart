import 'package:flutter/material.dart';

/// What this app does (Stage 9.1 language: research/screening tool).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app studies typing timing and a short tapping task to '
              'build a personal picture of your motor patterns over time. '
              'It compares new sessions against your own history and, '
              'separately, against timing ranges from Parkinson\'s typing '
              'research data.',
            ),
            SizedBox(height: 12),
            Text(
              'This app is a research and screening tool. It does NOT '
              'diagnose any medical condition. Always consult a qualified '
              'healthcare professional for medical advice.',
            ),
          ],
        ),
      ),
    );
  }
}
