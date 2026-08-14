Map<String, dynamic> singleRpcRow(Object? response) {
  if (response is Map) {
    return Map<String, dynamic>.from(response);
  }
  if (response is List && response.length == 1 && response.single is Map) {
    return Map<String, dynamic>.from(response.single as Map);
  }
  throw const FormatException('Expected exactly one RPC result row.');
}
