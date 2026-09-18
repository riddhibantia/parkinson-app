import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/user_profile.dart';
import '../../profile/providers/profile_context_provider.dart';

/// Demographic context collection (Stage 1.7). Optional fields, plain
/// explanation, never blocks the typing pipeline.
class DemographicsScreen extends ConsumerStatefulWidget {
  const DemographicsScreen({super.key});

  @override
  ConsumerState<DemographicsScreen> createState() =>
      _DemographicsScreenState();
}

class _DemographicsScreenState extends ConsumerState<DemographicsScreen> {
  final _ageController = TextEditingController();
  SexGender? _sexGender;

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _continue() {
    final raw = _ageController.text.trim();
    final age = raw.isEmpty ? null : int.tryParse(raw);
    ref.read(profileContextProvider.notifier).setDemographics(
          DemographicContext(ageYears: age, sexGender: _sexGender),
        );
    context.go('/onboarding/context-profile');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About you')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These details are used only to adjust/reference the research '
              'model and evaluate whether performance differs across groups. '
              'They are not typing features and are never used to diagnose you.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age in years (optional)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SexGender>(
              initialValue: _sexGender,
              decoration:
                  const InputDecoration(labelText: 'Sex / gender (optional)'),
              items: SexGender.values
                  .map((v) =>
                      DropdownMenuItem(value: v, child: Text(v.label)))
                  .toList(),
              onChanged: (v) => setState(() => _sexGender = v),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () =>
                      context.go('/onboarding/context-profile'),
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: _continue,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
