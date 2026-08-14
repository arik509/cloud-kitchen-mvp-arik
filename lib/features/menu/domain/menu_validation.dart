class MenuInputValidator {
  const MenuInputValidator._();

  static String? name(String? value) =>
      value == null || value.trim().isEmpty ? 'Item name is required' : null;

  static String? price(String? value) {
    final price = double.tryParse(value?.trim() ?? '');
    if (price == null || !price.isFinite || price <= 0) {
      return 'Price must be greater than zero';
    }
    return null;
  }
}
