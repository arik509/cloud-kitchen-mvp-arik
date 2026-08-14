import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/location/location_service.dart';
import '../core/presentation/app_ui.dart';
import '../core/validation/bangladesh_phone.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/order_chat_page.dart';
import '../features/customer/data/customer_catalog_repository.dart';
import '../features/customer/presentation/customer_discovery_page.dart';
import '../features/kitchen/data/kitchen_image_repository.dart';
import '../features/kitchen/presentation/kitchen_page.dart';
import '../features/kitchen/presentation/owner_overview_page.dart';
import '../features/kitchen/data/kitchen_repository.dart';
import '../features/menu/data/menu_image_repository.dart';
import '../features/menu/data/menu_repository.dart';
import '../features/notifications/application/push_notification_service.dart';
import '../features/notifications/data/notification_dispatcher.dart';
import '../features/notifications/domain/notification_models.dart';
import '../features/notifications/presentation/notification_settings_card.dart';
import '../features/notifications/presentation/notification_navigation_handler.dart';
import '../features/orders/data/kitchen_order_repository.dart';
import '../features/orders/data/order_repository.dart';
import '../features/orders/presentation/kitchen_orders_page.dart';
import '../features/orders/presentation/my_orders_page.dart';
import '../features/payments/data/payment_repository.dart';
import '../features/ratings/data/rating_repository.dart';
import '../features/profile/domain/user_role.dart';
import '../features/profile/data/account_profile_repository.dart';
import '../features/rider/data/rider_delivery_repository.dart';
import '../features/rider/presentation/rider_deliveries_page.dart';
import '../features/rider/presentation/rider_earnings_page.dart';
import '../features/wallet/data/wallet_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - value)),
                  child: child,
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppBrandMark()),
                    const SizedBox(height: 26),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fresh meals, local kitchens, and reliable delivery—all in one place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            TextFormField(
                              key: const Key('login-email'),
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: validateEmailAddress,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('login-password'),
                              controller: _password,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  key: const Key('toggle-login-password'),
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: validatePassword,
                              onFieldSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              key: const Key('login-submit'),
                              onPressed: _loading ? null : _login,
                              icon: _loading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                _loading ? 'Signing in...' : 'Sign in',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      key: const Key('open-signup'),
                      onPressed: _loading
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            ),
                      child: const Text('New to Cloud Kitchen? Create account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String? validateEmailAddress(String? value) {
  final email = value?.trim() ?? '';
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
      ? null
      : 'Enter a valid email address.';
}

String? validatePassword(String? value) =>
    (value?.length ?? 0) >= 6 ? null : 'Use at least 6 characters.';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'customer';
  bool _loading = false;
  bool _obscurePassword = true;
  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'name': _name.text.trim(),
          'phone': normalizeBangladeshPhone(_phone.text),
          'address': _address.text.trim(),
          'role': _role,
        },
      );
      if (response.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Check email if confirmation is enabled.',
            ),
          ),
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create your account')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Center(child: AppBrandMark(compact: true)),
            const SizedBox(height: 18),
            Text(
              'Join Cloud Kitchen',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how you’ll use the marketplace, then add your details.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            TextFormField(
              key: const Key('signup-name'),
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('signup-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Bangladesh mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
                helperText: 'Use 01XXXXXXXXX or +8801XXXXXXXXX.',
              ),
              validator: validateBangladeshPhone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('signup-address'),
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 12),
            const AppSectionHeader(
              title: 'I want to…',
              subtitle: 'Demo roles are self-selected for this MVP.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RoleChoice(
                  key: const Key('role-customer'),
                  selected: _role == 'customer',
                  icon: Icons.restaurant_menu,
                  label: 'Order food',
                  onTap: () => setState(() => _role = 'customer'),
                ),
                _RoleChoice(
                  key: const Key('role-owner'),
                  selected: _role == 'kitchen_owner',
                  icon: Icons.storefront_outlined,
                  label: 'Run a kitchen',
                  onTap: () => setState(() => _role = 'kitchen_owner'),
                ),
                _RoleChoice(
                  key: const Key('role-rider'),
                  selected: _role == 'rider',
                  icon: Icons.delivery_dining,
                  label: 'Deliver orders',
                  onTap: () => setState(() => _role = 'rider'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('signup-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: validateEmailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('signup-password'),
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password (at least 6 characters)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: validatePassword,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('signup-submit'),
              onPressed: _loading ? null : _signup,
              child: Text(_loading ? 'Creating account...' : 'Create account'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    selected: selected,
    onSelected: (_) => onTap(),
    avatar: Icon(icon, size: 18),
    label: Text(label),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.role,
    required this.client,
    required this.notificationService,
    super.key,
  });
  final UserRole role;
  final SupabaseClient client;
  final PushNotificationService notificationService;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  int _ordersRevision = 0;

  @override
  void initState() {
    super.initState();
    widget.notificationService.syncForCurrentSession();
  }

  void _openNotificationChat(NotificationDestination destination) {
    if (!mounted) return;
    setState(() => index = widget.role == UserRole.owner ? 2 : 1);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderChatPage(
          repository: SupabaseChatRepository(
            widget.client,
            dispatcher: SupabaseNotificationDispatcher(widget.client),
          ),
          orderId: destination.orderId,
          title: widget.role == UserRole.customer
              ? destination.kitchenName ?? 'Kitchen chat'
              : 'Chat with Customer',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderRepository = SupabaseOrderRepository(widget.client);
    final chatRepository = SupabaseChatRepository(
      widget.client,
      dispatcher: SupabaseNotificationDispatcher(widget.client),
    );
    final riderRepository = SupabaseRiderDeliveryRepository(widget.client);
    final paymentRepository = SupabasePaymentRepository(widget.client);
    final ratingRepository = SupabaseRatingRepository(widget.client);
    final notificationDispatcher = SupabaseNotificationDispatcher(
      widget.client,
    );
    final kitchenOrderRepository = SupabaseKitchenOrderRepository(
      widget.client,
    );
    final accountProfileRepository = SupabaseAccountProfileRepository(
      widget.client,
    );
    final pages = switch (widget.role) {
      UserRole.customer => [
        CustomerDiscoveryPage(
          locationService: const GeolocatorLocationService(),
          catalogRepository: SupabaseCustomerCatalogRepository(widget.client),
          imageRepository: SupabaseMenuImageRepository(widget.client),
          kitchenImageRepository: SupabaseKitchenImageRepository(widget.client),
          walletRepository: SupabaseWalletRepository(widget.client),
          orderRepository: orderRepository,
          ratingRepository: ratingRepository,
          notificationDispatcher: notificationDispatcher,
          onOrderPlaced: () => setState(() {
            _ordersRevision++;
            index = 1;
          }),
        ),
        MyOrdersPage(
          key: ValueKey(_ordersRevision),
          repository: orderRepository,
          chatRepository: chatRepository,
          paymentRepository: paymentRepository,
          ratingRepository: ratingRepository,
          notificationDispatcher: notificationDispatcher,
          profilePhoneLoader: () async =>
              (await accountProfileRepository.fetchCurrent()).phone,
        ),
        ProfilePage(
          notificationService: widget.notificationService,
          repository: accountProfileRepository,
        ),
      ],
      UserRole.owner => [
        OwnerOverviewPage(
          ownerId: widget.client.auth.currentUser!.id,
          kitchenRepository: SupabaseKitchenRepository(widget.client),
          menuRepository: SupabaseMenuRepository(widget.client),
          orderRepository: kitchenOrderRepository,
        ),
        KitchenPage.supabase(Supabase.instance.client),
        KitchenOrdersPage(
          repository: kitchenOrderRepository,
          chatRepository: chatRepository,
          paymentRepository: paymentRepository,
          notificationDispatcher: notificationDispatcher,
        ),
        ProfilePage(
          notificationService: widget.notificationService,
          repository: accountProfileRepository,
        ),
      ],
      UserRole.rider => [
        RiderDeliveriesPage(
          repository: riderRepository,
          paymentRepository: paymentRepository,
          notificationDispatcher: notificationDispatcher,
        ),
        RiderEarningsPage(repository: riderRepository),
        ProfilePage(
          notificationService: widget.notificationService,
          repository: accountProfileRepository,
        ),
      ],
    };
    final labels = switch (widget.role) {
      UserRole.customer => const ['Discover', 'My Orders', 'Profile'],
      UserRole.owner => const [
        'Dashboard',
        'Kitchen & Menu',
        'Orders',
        'Profile',
      ],
      UserRole.rider => const ['Deliveries', 'Earnings', 'Profile'],
    };
    return NotificationNavigationHandler(
      service: widget.notificationService,
      chatEnabled: widget.role != UserRole.rider,
      onOpenChat: _openNotificationChat,
      onOpenOrder: (_) => setState(
        () => index = switch (widget.role) {
          UserRole.rider => 0,
          UserRole.owner => 2,
          UserRole.customer => 1,
        },
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(labels[index])),
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          destinations: [
            for (
              var destination = 0;
              destination < labels.length;
              destination++
            )
              NavigationDestination(
                icon: Icon(_navigationIcons(widget.role)[destination]),
                label: labels[destination],
              ),
          ],
        ),
      ),
    );
  }
}

class DeliveriesPage extends StatelessWidget {
  const DeliveriesPage({super.key});
  @override
  Widget build(BuildContext context) => const _InfoPage(
    icon: Icons.delivery_dining,
    title: 'Available deliveries',
    message: 'Ready orders will appear here for you to accept.',
  );
}

class EarningsPage extends StatelessWidget {
  const EarningsPage({super.key});
  @override
  Widget build(BuildContext context) => const _InfoPage(
    icon: Icons.account_balance_wallet,
    title: '৳0.00',
    message: 'Your completed delivery earnings will appear here.',
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.notificationService,
    required this.repository,
    super.key,
  });
  final PushNotificationService notificationService;
  final AccountProfileRepository repository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

List<IconData> _navigationIcons(UserRole role) => switch (role) {
  UserRole.customer => const [
    Icons.explore_outlined,
    Icons.receipt_long_outlined,
    Icons.person_outline,
  ],
  UserRole.owner => const [
    Icons.space_dashboard_outlined,
    Icons.storefront_outlined,
    Icons.receipt_long_outlined,
    Icons.person_outline,
  ],
  UserRole.rider => const [
    Icons.delivery_dining,
    Icons.payments_outlined,
    Icons.person_outline,
  ],
};

class _ProfilePageState extends State<ProfilePage> {
  late Future<AccountProfile> _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.fetchCurrent();
  }

  void _retry() => setState(() {
    _profile = widget.repository.fetchCurrent();
  });

  Future<void> _editPhone(AccountProfile profile) async {
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => _PhoneEditDialog(initialPhone: profile.phone),
    );
    if (phone == null || !mounted) return;
    try {
      final updated = await widget.repository.updatePhone(phone);
      if (!mounted) return;
      setState(() {
        _profile = Future.value(updated);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number updated.')));
    } on AccountProfileException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AccountProfile>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          key: Key('profile-loading'),
          child: CircularProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return AppStateView(
          key: const Key('profile-error'),
          icon: Icons.person_off_outlined,
          title: 'Could not load profile',
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: _retry,
        );
      }
      final profile = snapshot.data!;
      return ListView(
        key: const Key('profile-content'),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      profile.name.trim().isEmpty
                          ? '?'
                          : profile.name.trim()[0].toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  AppStatusBadge(
                    label: userRoleLabel(profile.role),
                    icon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(height: 14),
                  _ProfileDetail(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: profile.email,
                  ),
                  _ProfileDetail(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: profile.address,
                  ),
                  _ProfileDetail(
                    key: const Key('profile-phone'),
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: profile.phone,
                    trailing: IconButton(
                      tooltip: 'Edit phone',
                      onPressed: () => _editPhone(profile),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                  if (profile.role == UserRole.customer)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'This number may be used for manual bKash refund processing.',
                        key: Key('refund-phone-helper'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          NotificationSettingsCard(service: widget.notificationService),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              await widget.notificationService.unregisterCurrentDevice();
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      );
    },
  );
}

class _PhoneEditDialog extends StatefulWidget {
  const _PhoneEditDialog({required this.initialPhone});

  final String? initialPhone;

  @override
  State<_PhoneEditDialog> createState() => _PhoneEditDialogState();
}

class _PhoneEditDialogState extends State<_PhoneEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Update phone number'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        key: const Key('profile-phone-field'),
        controller: _controller,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Bangladesh mobile number',
          helperText:
              'Used for manual bKash refund processing when applicable.',
        ),
        validator: validateBangladeshPhone,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save-profile-phone'),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _controller.text);
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value.isEmpty ? 'Not provided' : value),
    trailing: trailing,
  );
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
