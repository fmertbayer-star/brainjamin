import 'package:flutter_test/flutter_test.dart';

import 'package:brainjamin/main.dart';

void main() {
  testWidgets('Smoke screen shows Brainjamin title text', (WidgetTester tester) async {
    await tester.pumpWidget(const BrainjaminApp());
    expect(find.textContaining('Brainjamin'), findsWidgets);
    expect(find.textContaining('Firebase ready'), findsOneWidget);
  });
}
