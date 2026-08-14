import 'package:cloud_kitchen_mvp/features/payments/domain/payment_models.dart';
import 'package:cloud_kitchen_mvp/features/ratings/data/rating_repository.dart';
import 'package:cloud_kitchen_mvp/features/ratings/presentation/rating_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submits one 1–5 star rating with optional review', (
    tester,
  ) async {
    final repository = FakeRatingRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingDialog(repository: repository, orderId: 'order-1'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('rating-star-5')));
    await tester.enterText(find.byType(TextField), 'Excellent meal');
    await tester.tap(find.byKey(const Key('submit-rating')));
    await tester.pumpAndSettle();
    expect(repository.orderId, 'order-1');
    expect(repository.stars, 5);
    expect(repository.review, 'Excellent meal');
  });
}

class FakeRatingRepository implements RatingRepository {
  String? orderId;
  int? stars;
  String? review;
  @override
  Future<Map<String, KitchenRatingSummary>> fetchSummaries() async => const {};
  @override
  Future<void> submitKitchenRating(
    String orderId,
    int stars,
    String? review,
  ) async {
    this.orderId = orderId;
    this.stars = stars;
    this.review = review;
  }
}
