enum UserRole { customer, owner, rider }

UserRole parseUserRole(Object? value) => switch (value) {
  'customer' => UserRole.customer,
  'kitchen_owner' => UserRole.owner,
  'rider' => UserRole.rider,
  _ => throw UnsupportedUserRoleException(value?.toString()),
};

class UnsupportedUserRoleException implements Exception {
  const UnsupportedUserRoleException(this.value);

  final String? value;

  @override
  String toString() {
    if (value == null || value!.isEmpty) {
      return 'The profile has no supported role.';
    }
    return 'Unsupported profile role: $value';
  }
}
