import "package:flutter_test/flutter_test.dart";
import "package:timetable_app/main.dart";

void main() {
  testWidgets("renders the bootstrap shell", (tester) async {
    await tester.pumpWidget(const TimetableApp());

    expect(find.text("Timetable bootstrap"), findsOneWidget);
    expect(find.text("Flutter shell ready"), findsOneWidget);
  });
}
