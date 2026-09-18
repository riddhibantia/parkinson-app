import 'package:flutter_test/flutter_test.dart';
import 'package:parkinson_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:parkinson_app/features/dashboard/screens/detailed_metrics_screen.dart';

Map<String, dynamic> _dual({String confidence = 'established'}) => {
      'layer1': {'status': 'watch', 'message': 'Slightly outside range.'},
      'layer2': {
        'status': 'attention',
        'message': 'Changed pattern.',
        'confidence': confidence,
      },
      'primary_focus': confidence == 'established' ? 'layer2' : 'layer1',
    };

void main() {
  test('null result yields no cards (readiness shells)', () {
    expect(resultCardsFor(null), isNull);
  });

  test('dual result maps both cards with focus order', () {
    final cards = resultCardsFor(_dual())!;
    expect(cards.layer1.status, 'watch');
    expect(cards.layer2.status, 'attention');
    expect(cards.layer2.building, isFalse);
    expect(cards.primaryFocus, 'layer2');
  });

  test('building confidence softens the Layer 2 message', () {
    final cards = resultCardsFor(_dual(confidence: 'building'))!;
    expect(cards.layer2.building, isTrue);
    expect(cards.layer2.message, contains('Still learning'));
    expect(cards.primaryFocus, 'layer1');
  });

  test('collecting shape shows Layer 1 with building Layer 2', () {
    final cards = resultCardsFor({
      'status': 'collecting',
      'layer1': {'status': 'normal', 'message': 'Typical range.'},
    })!;
    expect(cards.layer1.status, 'normal');
    expect(cards.layer2.building, isTrue);
  });

  test('unknown shapes never invent a status', () {
    expect(resultCardsFor({'status': 'practice_recorded'}), isNull);
    expect(resultCardsFor({'layer2': 'oops'}), isNull);
  });

  test('robust-z range labels follow the 2/3 bands', () {
    expect(DetailedMetricsScreen.rangeLabel(0.5), 'within usual range');
    expect(DetailedMetricsScreen.rangeLabel(2.0), 'unusual');
    expect(DetailedMetricsScreen.rangeLabel(-3.5), 'strongly unusual');
  });
}
