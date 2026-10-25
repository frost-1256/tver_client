import 'package:flutter_test/flutter_test.dart';

import 'package:tver_client/main.dart';

void main() {
  testWidgets('App renders the home screen app bar', (tester) async {
    await tester.pumpWidget(const TverApp());
    await tester.pump();
    expect(find.text('TVer'), findsWidgets);
  });
}
