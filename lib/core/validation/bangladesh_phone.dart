String normalizeBangladeshPhone(String value) {
  final compact = value.trim().replaceAll(RegExp(r'[\s-]+'), '');
  if (compact.startsWith('+880')) return '0${compact.substring(4)}';
  if (compact.startsWith('880')) return '0${compact.substring(3)}';
  return compact;
}

bool isValidBangladeshPhone(String? value) => RegExp(
  r'^01[3-9][0-9]{8}$',
).hasMatch(normalizeBangladeshPhone(value ?? ''));

String? validateBangladeshPhone(String? value, {bool required = true}) {
  final normalized = normalizeBangladeshPhone(value ?? '');
  if (normalized.isEmpty && !required) return null;
  return isValidBangladeshPhone(normalized)
      ? null
      : 'Enter a valid Bangladeshi mobile number.';
}
