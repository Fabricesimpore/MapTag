import 'package:flutter_test/flutter_test.dart';
import 'package:maptag_bf/main.dart';

void main() {
  testWidgets('App launches test', (WidgetTester tester) async {
    // Build our app
    await tester.pumpWidget(const MapTagBFApp());
    
    // Verify app title exists
    expect(find.text('MapTag BF'), findsOneWidget);
  });
}