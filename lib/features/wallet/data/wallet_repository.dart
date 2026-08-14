import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/rpc_response.dart';
import '../domain/wallet_models.dart';

abstract interface class WalletRepository {
  Future<WalletBalance> fetchCurrentBalance();

  Future<AddDemoBalanceResult> addDemoBalance();
}

abstract interface class WalletRemoteDataSource {
  Future<Map<String, dynamic>> fetchCurrentBalance();

  Future<Object?> addDemoBalance();
}

class SupabaseWalletRepository implements WalletRepository {
  SupabaseWalletRepository(SupabaseClient client)
    : this.withDataSource(SupabaseWalletRemoteDataSource(client));

  SupabaseWalletRepository.withDataSource(this._dataSource);

  final WalletRemoteDataSource _dataSource;

  @override
  Future<WalletBalance> fetchCurrentBalance() async {
    try {
      return WalletBalance.fromMap(await _dataSource.fetchCurrentBalance());
    } on WalletRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw WalletRepositoryException.fromBackend(
        message: error.message,
        backendCode: error.code,
      );
    } catch (_) {
      throw const WalletRepositoryException(
        WalletFailureCode.invalidResponse,
        'The wallet response could not be read.',
      );
    }
  }

  @override
  Future<AddDemoBalanceResult> addDemoBalance() async {
    try {
      final row = singleRpcRow(await _dataSource.addDemoBalance());
      return AddDemoBalanceResult.fromRpc(row);
    } on WalletRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw WalletRepositoryException.fromBackend(
        message: error.message,
        backendCode: error.code,
      );
    } on FormatException {
      throw const WalletRepositoryException(
        WalletFailureCode.invalidResponse,
        'The wallet response could not be read.',
      );
    }
  }
}

class SupabaseWalletRemoteDataSource implements WalletRemoteDataSource {
  SupabaseWalletRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> fetchCurrentBalance() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const WalletRepositoryException(
        WalletFailureCode.unauthenticated,
        'Sign in to view your wallet.',
      );
    }
    return _client
        .from('profiles')
        .select('wallet_balance')
        .eq('id', userId)
        .single();
  }

  @override
  Future<Object?> addDemoBalance() {
    if (_client.auth.currentUser == null) {
      throw const WalletRepositoryException(
        WalletFailureCode.unauthenticated,
        'Sign in again to use your wallet.',
      );
    }
    return _client.rpc('add_demo_balance');
  }
}

enum WalletFailureCode {
  unauthenticated,
  customerRoleRequired,
  cooldown,
  capReached,
  invalidResponse,
  unavailable,
}

class WalletRepositoryException implements Exception {
  const WalletRepositoryException(this.code, this.message, {this.backendCode});

  factory WalletRepositoryException.fromBackend({
    required String message,
    String? backendCode,
  }) {
    final normalized = message.toLowerCase();
    if (normalized.contains('authentication_required') ||
        normalized.contains('profile_not_found') ||
        normalized.contains('jwt expired') ||
        normalized.contains('not authenticated')) {
      return WalletRepositoryException(
        WalletFailureCode.unauthenticated,
        'Sign in again to use your wallet.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('customer_role_required')) {
      return WalletRepositoryException(
        WalletFailureCode.customerRoleRequired,
        'Only customer accounts can receive demo balance.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('demo_credit_cooldown')) {
      return WalletRepositoryException(
        WalletFailureCode.cooldown,
        'Demo balance can be added only once per hour.',
        backendCode: backendCode,
      );
    }
    if (normalized.contains('demo_wallet_cap_reached')) {
      return WalletRepositoryException(
        WalletFailureCode.capReached,
        'The demo wallet balance cap has been reached.',
        backendCode: backendCode,
      );
    }
    return WalletRepositoryException(
      WalletFailureCode.unavailable,
      'The wallet service is unavailable. Try again.',
      backendCode: backendCode,
    );
  }

  final WalletFailureCode code;
  final String message;
  final String? backendCode;

  @override
  String toString() => message;
}
