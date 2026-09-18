import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_profile.dart';
import '../../profile/providers/profile_context_provider.dart';
import '../providers/checkin_provider.dart';

/// Brief daily motor & symptom check-in (Stage 1.9, ~20-30 seconds).
/// Stored as its own contextual time series — never converted into a
/// diagnostic score, never fed to Layer 1/Layer 2, never called
/// UPDRS/MDS-UPDRS.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  double _tremor = 0;
  double _stiffness = 0;
  double _slowness = 0;
  double _balance = 0;
  double _fatigue = 0;
  double _sleep = 5;
  final _noteController = TextEditingController();
  MedicationState? _medication;
  final _hoursController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toInt()}'),
        Slider(
          value: value,
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _save() {
    final note = _noteController.text.trim();
    ref.read(checkInProvider.notifier).add(SymptomCheckIn(
          date: DateTime.now(),
          tremor: _tremor.toInt(),
          stiffness: _stiffness.toInt(),
          slowness: _slowness.toInt(),
          balanceWalking: _balance.toInt(),
          fatigue: _fatigue.toInt(),
          sleepQuality: _sleep.toInt(),
          note: note.isEmpty ? null : note,
          medicationState: _medication,
          hoursSinceMedication: double.tryParse(_hoursController.text.trim()),
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-in saved.')),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        ref.watch(profileContextProvider).monitoringProfileType;
    final isDiagnosed = profile == MonitoringProfileType.diagnosed;
    return Scaffold(
      appBar: AppBar(
        title: Text(isDiagnosed
            ? 'Daily check-in'
            : 'Daily motor and wellness check-in'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              'Self-reported context only — kept separate from typing '
              'measurements and never scored as a diagnosis.',
            ),
            _slider('Tremor today', _tremor, (v) => setState(() => _tremor = v)),
            _slider('Stiffness / rigidity today', _stiffness,
                (v) => setState(() => _stiffness = v)),
            _slider('Slowness today', _slowness,
                (v) => setState(() => _slowness = v)),
            _slider('Balance / walking difficulty today', _balance,
                (v) => setState(() => _balance = v)),
            _slider('Fatigue today', _fatigue,
                (v) => setState(() => _fatigue = v)),
            _slider('Sleep quality last night', _sleep,
                (v) => setState(() => _sleep = v)),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional, never analyzed)',
              ),
              maxLines: 2,
            ),
            if (isDiagnosed) ...[
              const SizedBox(height: 16),
              const Text('Medication context (optional)'),
              DropdownButtonFormField<MedicationState>(
                initialValue: _medication,
                decoration: const InputDecoration(labelText: 'ON / OFF state'),
                items: MedicationState.values
                    .map((v) =>
                        DropdownMenuItem(value: v, child: Text(v.name)))
                    .toList(),
                onChanged: (v) => setState(() => _medication = v),
              ),
              TextField(
                controller: _hoursController,
                decoration: const InputDecoration(
                  labelText: 'Hours since last medication (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
