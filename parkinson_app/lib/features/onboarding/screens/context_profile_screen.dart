import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_context_provider.dart';

/// Monitoring context profile (Stage 1.8). Personalizes the experience;
/// never diagnostic evidence. All health-context fields optional with
/// explicit consent — core typing works without disclosure.
class ContextProfileScreen extends ConsumerStatefulWidget {
  const ContextProfileScreen({super.key});

  @override
  ConsumerState<ContextProfileScreen> createState() =>
      _ContextProfileScreenState();
}

class _ContextProfileScreenState extends ConsumerState<ContextProfileScreen> {
  MonitoringProfileType? _type;
  final _yearController = TextEditingController();
  final _symptoms = <ReportedSymptom>{};
  AffectedSide? _side;

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  void _finish() {
    final notifier = ref.read(profileContextProvider.notifier);
    notifier.setMonitoringProfile(_type);
    if (_type == MonitoringProfileType.diagnosed) {
      notifier.setParkinsonContext(ParkinsonContext(
        diagnosisYear: int.tryParse(_yearController.text.trim()),
        mainReportedSymptoms: Set.of(_symptoms),
        moreAffectedSide: _side,
      ));
    }
    ref.read(hasOnboardedProvider.notifier).state = true;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How are you using this app?')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            RadioGroup<MonitoringProfileType>(
              groupValue: _type,
              onChanged: (v) => setState(() => _type = v),
              child: Column(
                children: [
                  for (final t in MonitoringProfileType.values)
                    RadioListTile<MonitoringProfileType>(
                      title: Text(t.label),
                      value: t,
                    ),
                ],
              ),
            ),
            if (_type == MonitoringProfileType.diagnosed) ...[
              const SizedBox(height: 8),
              const Text(
                'Optional — helps personalize your view. '
                'Never used as diagnostic evidence.',
              ),
              TextField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis year (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              const Text('Main reported symptoms (optional)'),
              for (final s in ReportedSymptom.values)
                CheckboxListTile(
                  title: Text(s.label),
                  value: _symptoms.contains(s),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _symptoms.add(s);
                    } else {
                      _symptoms.remove(s);
                    }
                  }),
                ),
              const Text('More-affected side (optional)'),
              RadioGroup<AffectedSide>(
                groupValue: _side,
                onChanged: (v) => setState(() => _side = v),
                child: Column(
                  children: [
                    for (final side in AffectedSide.values)
                      RadioListTile<AffectedSide>(
                        title: Text(side.name),
                        value: side,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _type == null ? null : _finish,
              child: const Text('Finish setup'),
            ),
          ],
        ),
      ),
    );
  }
}
