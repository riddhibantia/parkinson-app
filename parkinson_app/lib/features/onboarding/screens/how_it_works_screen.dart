import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/top_bar.dart';
import '../../../shared/widgets/design_system.dart';
import '../../../shared/widgets/gradient_background.dart';

/// How it works + Privacy & Consent on ONE page (spec 5-6).
/// Heading is dominant, vertical bullets, consent below.
class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  bool _c1 = false; // required
  bool _c2 = false;
  bool _c3 = false;

  bool get _canContinue => _c1;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 80-90% of available width, capped for readability on ultra-wide
    final maxW = (width * 0.88).clamp(320.0, 1100.0);
    return Scaffold(
      appBar: const AppTopBar(title: 'How it works'),
      body: GradientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              children: [
                // Logo consistency
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.keyboard_alt_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'TypeMonitor',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'The app learns the way you type —\nnot what you type.',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 42,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We analyze typing timing patterns such as hold time, flight time and inter-key latency to understand typing behavior.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 20),
                const _Bullet(
                  icon: Icons.check_circle_outline,
                  text: 'We measure how you type, not what you type',
                ),
                const _Bullet(
                  icon: Icons.timer_outlined,
                  text: 'We analyze timing patterns from your keyboard',
                ),
                const _Bullet(
                  icon: Icons.layers_outlined,
                  text:
                      'You can choose a quick Layer 1 analysis or long-term Layer 2 monitoring',
                ),
                const _Bullet(
                  icon: Icons.show_chart_outlined,
                  text:
                      'Layer 2 learns your personal typing baseline over time',
                ),
                const _Bullet(
                  icon: Icons.privacy_tip_outlined,
                  text: 'Your typed content is not the focus of the analysis',
                ),
                const _Bullet(
                  icon: Icons.verified_outlined,
                  text:
                      'Results are for research and monitoring, not diagnosis',
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Privacy & Consent',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                CheckboxListTile(
                  value: _c1,
                  onChanged: (v) => setState(() => _c1 = v ?? false),
                  title: const Text(
                    'I understand how typing data is collected and analyzed.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _c2,
                  onChanged: (v) => setState(() => _c2 = v ?? false),
                  title: const Text(
                    'I understand that this application is not a medical diagnostic tool.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _c3,
                  onChanged: (v) => setState(() => _c3 = v ?? false),
                  title: const Text(
                    'I consent to using the application for research/monitoring purposes.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: _canContinue
                      ? () => context.go('/onboarding/typing-experience')
                      : null,
                ),
                if (!_canContinue)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Please check the required consent to continue.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Your typed words are never stored. Only timing is kept.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Bullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}
