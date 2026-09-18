import 'package:flutter/material.dart';
import '../../../shared/widgets/design_system.dart';

class OnboardingScaffold extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final String continueLabel;
  final bool canContinue;

  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    this.subtitle,
    required this.child,
    this.onBack,
    this.onContinue,
    this.continueLabel = 'Continue',
    this.canContinue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack) : null,
        title: Text('Step $step of $totalSteps'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: step / totalSteps),
                  const SizedBox(height: 24),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 24),
                  Expanded(child: SingleChildScrollView(child: child)),
                  const SizedBox(height: 16),
                  if (onContinue != null)
                    PrimaryButton(label: continueLabel, onPressed: canContinue ? onContinue : null),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
