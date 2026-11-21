import 'package:flutter_test/flutter_test.dart';
import 'package:wolvy_spike/main.dart';

void main() {
  testWidgets('shows the URL field and the mode switch', (tester) async {
    await tester.pumpWidget(const SpikeApp());
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Hybrid composition'), findsOneWidget);
  });
}
