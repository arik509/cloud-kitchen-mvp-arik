class KitchenInputValidator {
  const KitchenInputValidator._();

  static String? name(String? value) =>
      value == null || value.trim().isEmpty ? 'Kitchen name is required' : null;

  static String? address(String? value) => value == null || value.trim().isEmpty
      ? 'Kitchen address is required'
      : null;

  static String? latitude(String? value) =>
      _coordinate(value, minimum: -90, maximum: 90, label: 'Latitude');

  static String? longitude(String? value) =>
      _coordinate(value, minimum: -180, maximum: 180, label: 'Longitude');

  static String? _coordinate(
    String? value, {
    required double minimum,
    required double maximum,
    required String label,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null || !number.isFinite) {
      return '$label must be a valid number';
    }
    if (number < minimum || number > maximum) {
      return '$label must be between $minimum and $maximum';
    }
    return null;
  }
}
