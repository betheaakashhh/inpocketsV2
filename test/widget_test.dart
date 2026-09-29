import 'package:flutter_test/flutter_test.dart';

import 'package:inpockets/app.dart';

void main() {
  testWidgets('InPockets starts on the splash screen', (tester) async {
    await tester.pumpWidget(const InPocketsApp());

    expect(find.text('InPockets'), findsOneWidget);
    expect(find.text('Lending, done right.'), findsOneWidget);
  });
}
