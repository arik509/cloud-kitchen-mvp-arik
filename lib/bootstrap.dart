import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';

typedef AppBuilder = Widget Function(SupabaseClient client);

Future<void> bootstrap({required AppBuilder appBuilder}) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final config = SupabaseConfig.fromEnvironment();
    await Supabase.initialize(
      url: config.url.toString(),
      publishableKey: config.publishableKey,
    );
    runApp(appBuilder(Supabase.instance.client));
  } on ConfigurationException catch (error) {
    runApp(
      StartupFailureApp(
        title: 'Configuration required',
        message: error.message,
      ),
    );
  } catch (_) {
    runApp(
      const StartupFailureApp(
        title: 'Unable to start Cloud Kitchen',
        message:
            'Supabase could not be initialized. Check the configuration '
            'and network connection, then restart the app.',
      ),
    );
  }
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Cloud Kitchen',
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_outlined, size: 72),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
