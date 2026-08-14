import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/settlement_models.dart';

abstract interface class SettlementRepository {
  Future<RiderEarningsSummary> fetchRiderEarnings();
  Future<OwnerRevenueSummary> fetchOwnerRevenue();
}

abstract interface class SettlementRemoteDataSource {
  Future<Object?> riderEarnings();
  Future<Object?> ownerRevenue();
  Future<Object?> fallbackRiderDeliveries();
}

class SupabaseSettlementRepository implements SettlementRepository {
  SupabaseSettlementRepository(SupabaseClient client)
    : this.withDataSource(SupabaseSettlementRemoteDataSource(client));
  SupabaseSettlementRepository.withDataSource(this._source);

  final SettlementRemoteDataSource _source;

  @override
  Future<RiderEarningsSummary> fetchRiderEarnings() async {
    try {
      final rows = await _rows(_source.riderEarnings());
      return RiderEarningsSummary(
        entries: rows.map(RiderEarningEntry.fromMap).toList(growable: false),
      );
    } on SettlementException {
      rethrow;
    } on PostgrestException catch (error) {
      // If the RPC doesn't exist yet or the rider has no settlements,
      // return an empty summary instead of showing an error screen.
      final msg = error.message.toLowerCase();
      if (msg.contains('does not exist') ||
          msg.contains('could not find')) {
        try {
          final fallbackRows = await _rows(_source.fallbackRiderDeliveries());
          return RiderEarningsSummary(
            entries: fallbackRows
                .where((row) => row['status'] == 'delivered')
                .map((row) {
                  final gross = (row['final_price'] as num).toDouble();
                  return RiderEarningEntry(
                    orderId: row['order_id'] as String,
                    grossAmount: gross,
                    riderEarning: gross * 0.10,
                    createdAt: DateTime.parse(row['created_at'] as String),
                  );
                })
                .toList(growable: false),
          );
        } catch (_) {
          return const RiderEarningsSummary(entries: []);
        }
      }
      if (msg.contains('rider_role_required')) {
        return const RiderEarningsSummary(entries: []);
      }
      throw SettlementException.fromBackend(error.message);
    } on FormatException {
      // Null / empty response — no settlements yet.
      return const RiderEarningsSummary(entries: []);
    } catch (_) {
      throw const SettlementException(
        'The rider earnings response could not be read.',
      );
    }
  }

  @override
  Future<OwnerRevenueSummary> fetchOwnerRevenue() async {
    try {
      final rows = await _rows(_source.ownerRevenue());
      return OwnerRevenueSummary(
        entries: rows.map(OwnerSettlementEntry.fromMap).toList(growable: false),
      );
    } on SettlementException {
      rethrow;
    } on PostgrestException catch (error) {
      throw SettlementException.fromBackend(error.message);
    } catch (_) {
      throw const SettlementException(
        'The owner revenue response could not be read.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _rows(Future<Object?> call) async {
    final response = await call;
    if (response is! List) throw const FormatException();
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }
}

class SupabaseSettlementRemoteDataSource implements SettlementRemoteDataSource {
  SupabaseSettlementRemoteDataSource(this._client);

  final SupabaseClient _client;

  void _requireSession() {
    if (_client.auth.currentUser == null) {
      throw const SettlementException('Sign in again to view earnings.');
    }
  }

  @override
  Future<Object?> riderEarnings() {
    _requireSession();
    return _client.rpc('list_my_rider_earnings');
  }

  @override
  Future<Object?> ownerRevenue() {
    _requireSession();
    return _client.rpc('list_my_owner_settlements');
  }

  @override
  Future<Object?> fallbackRiderDeliveries() {
    _requireSession();
    return _client.rpc('list_my_rider_deliveries_v3');
  }
}

class SettlementException implements Exception {
  const SettlementException(this.message);

  factory SettlementException.fromBackend(String message) {
    final value = message.toLowerCase();
    if (value.contains('authentication_required') ||
        value.contains('jwt expired')) {
      return const SettlementException('Your session expired. Sign in again.');
    }
    if (value.contains('role_required')) {
      return const SettlementException(
        'This earnings view is not available for your account role.',
      );
    }
    return const SettlementException(
      'Earnings are unavailable. Check your connection and retry.',
    );
  }

  final String message;

  @override
  String toString() => message;
}
