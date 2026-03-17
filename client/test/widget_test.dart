import 'package:flutter_test/flutter_test.dart';
import 'package:client/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const CloudNoteApp());
    expect(find.text('CloudNote'), findsOneWidget);
  });
}
