import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/rpc_response.dart';
import '../../payments/domain/payment_models.dart';

abstract interface class RatingRepository {
  Future<Map<String, KitchenRatingSummary>> fetchSummaries();
  Future<void> submitKitchenRating(String orderId, int stars, String? review);
}

class SupabaseRatingRepository implements RatingRepository {
  SupabaseRatingRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, KitchenRatingSummary>> fetchSummaries() async {
    try {
      final response = await _client.rpc('list_kitchen_rating_summaries');
      if (response is! List) throw const FormatException();
      return {
        for (final raw in response)
          if (raw is Map)
            raw['kitchen_id'] as String: KitchenRatingSummary(
              kitchenId: raw['kitchen_id'] as String,
              average: (raw['average_rating'] as num).toDouble(),
              count: (raw['rating_count'] as num).toInt(),
            ),
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> submitKitchenRating(
    String orderId,
    int stars,
    String? review,
  ) async {
    try {
      singleRpcRow(
        await _client.rpc(
          'submit_kitchen_rating',
          params: {
            'p_order_id': orderId,
            'p_stars': stars,
            'p_review_text': review?.trim().isEmpty ?? true
                ? null
                : review!.trim(),
          },
        ),
      );
    } on PostgrestException catch (error) {
      throw RatingException.fromBackend(error.message);
    }
  }
}

class RatingException implements Exception {
  const RatingException(this.message);
  factory RatingException.fromBackend(String message) {
    final value = message.toLowerCase();
    if (value.contains('delivered_order_required')) {
      return const RatingException('Only delivered orders can be rated.');
    }
    if (value.contains('order_already_rated')) {
      return const RatingException('This order has already been rated.');
    }
    if (value.contains('access_denied')) {
      return const RatingException('You can rate only your own orders.');
    }
    return const RatingException('Could not submit rating. Please retry.');
  }
  final String message;
  @override
  String toString() => message;
}
