import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:track_pepper/app.dart';

void main() {
  testWidgets('App shows config message when Supabase not configured', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TrackPepperApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Supabase is not configured'), findsOneWidget);
  });
}
