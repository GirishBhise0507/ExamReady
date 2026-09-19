import 'package:flutter_test/flutter_test.dart';
import 'package:exam_ready/app/exam_ready_app.dart';

void main() {
  testWidgets('renders onboarding screen', (tester) async {
    await tester.pumpWidget(const ExamReadyApp());

    expect(find.text('Stay Ahead of Every Exam'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
