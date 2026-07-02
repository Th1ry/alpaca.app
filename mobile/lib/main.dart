import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import 'app.dart';

import 'providers/alpaca_connection_provider.dart';
import 'providers/app_settings_provider.dart';



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();



  final container = ProviderContainer();

  await container.read(appSettingsProvider.notifier).load();

  // Bootstrap global API connection before UI mounts.
  container.read(alpacaConnectionProvider);



  runApp(

    UncontrolledProviderScope(

      container: container,

      child: const AlpacaOptionsApp(),

    ),

  );

}

