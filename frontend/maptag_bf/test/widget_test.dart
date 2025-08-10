import 'package:flutter_test/flutter_test.dart';
import 'package:maptag_bf/main.dart';

void main() {
  testWidgets('App launches test', (WidgetTester tester) async {
    // Build our app
    await tester.pumpWidget(const MapTagApp());
    
    // Verify app can build without errors
    expect(find.byType(MapTagApp), findsOneWidget);
  });
}