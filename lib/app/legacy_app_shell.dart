import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/location/location_service.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/customer/data/customer_catalog_repository.dart';
import '../features/customer/presentation/customer_discovery_page.dart';
import '../features/kitchen/data/kitchen_image_repository.dart';
import '../features/kitchen/presentation/kitchen_page.dart';
import '../features/menu/data/menu_image_repository.dart';
import '../features/orders/data/kitchen_order_repository.dart';
import '../features/orders/data/order_repository.dart';
import '../features/orders/presentation/kitchen_orders_page.dart';
import '../features/orders/presentation/my_orders_page.dart';
import '../features/profile/domain/user_role.dart';
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
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      _show('Valid email and a 6+ character password are required.');
      return;
    }
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.restaurant_menu_rounded,
                  size: 86,
                  color: Color(0xffd35400),
                ),
                const SizedBox(height: 20),
                Text(
                  'Cloud Kitchen',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to order, manage food, or deliver.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(_loading ? 'Signing in...' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        ),
                  child: const Text('New here? Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

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
          'phone': _phone.text.trim(),
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
    appBar: AppBar(title: const Text('Create account')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Phone is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'I am a'),
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('Customer')),
                DropdownMenuItem(
                  value: 'kitchen_owner',
                  child: Text('Kitchen Owner'),
                ),
                DropdownMenuItem(value: 'rider', child: Text('Delivery Rider')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (at least 6 characters)',
              ),
              validator: (v) => v == null || v.length < 6
                  ? 'Use at least 6 characters'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _signup,
              child: Text(_loading ? 'Creating account...' : 'Create account'),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.role, required this.client, super.key});
  final UserRole role;
  final SupabaseClient client;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  int _ordersRevision = 0;

  @override
  Widget build(BuildContext context) {
    final orderRepository = SupabaseOrderRepository(widget.client);
    final chatRepository = SupabaseChatRepository(widget.client);
    final riderRepository = SupabaseRiderDeliveryRepository(widget.client);
    final pages = switch (widget.role) {
      UserRole.customer => [
        CustomerDiscoveryPage(
          locationService: const GeolocatorLocationService(),
          catalogRepository: SupabaseCustomerCatalogRepository(widget.client),
          imageRepository: SupabaseMenuImageRepository(widget.client),
          kitchenImageRepository: SupabaseKitchenImageRepository(widget.client),
          walletRepository: SupabaseWalletRepository(widget.client),
          orderRepository: orderRepository,
          onOrderPlaced: () => setState(() {
            _ordersRevision++;
            index = 1;
          }),
        ),
        MyOrdersPage(
          key: ValueKey(_ordersRevision),
          repository: orderRepository,
          chatRepository: chatRepository,
        ),
        const ProfilePage(),
      ],
      UserRole.owner => [
        KitchenPage.supabase(Supabase.instance.client),
        KitchenOrdersPage(
          repository: SupabaseKitchenOrderRepository(widget.client),
          chatRepository: chatRepository,
        ),
        const ProfilePage(),
      ],
      UserRole.rider => [
        RiderDeliveriesPage(repository: riderRepository),
        RiderEarningsPage(repository: riderRepository),
        const ProfilePage(),
      ],
    };
    final labels = switch (widget.role) {
      UserRole.customer => const ['Discover', 'My Orders', 'Profile'],
      UserRole.owner => const ['My Kitchen', 'Orders', 'Profile'],
      UserRole.rider => const ['Deliveries', 'Earnings', 'Profile'],
    };
    return Scaffold(
      appBar: AppBar(title: Text(labels[index])),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          NavigationDestination(
            icon: Icon(
              widget.role == UserRole.rider
                  ? Icons.delivery_dining
                  : Icons.restaurant,
            ),
            label: labels[0],
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long),
            label: labels[1],
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: labels[2],
          ),
        ],
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

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.tonalIcon(
      onPressed: () => Supabase.instance.client.auth.signOut(),
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
    ),
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
