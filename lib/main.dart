import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'providers/transactions_provider.dart';
import 'providers/config_provider.dart';
import 'providers/budget_provider.dart';
import 'widgets/main_layout.dart';
import 'features/auth/login_screen.dart';
import 'config/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FinanzApp());
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class FinanzApp extends StatelessWidget {
  const FinanzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinanzApp 🚀',
      locale: const Locale('es'),
      scrollBehavior: MyCustomScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // While checking auth status, show a loading indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF111827),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            // User is logged in -> Inject Providers & Show App
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => TransactionsProvider()), // Loads data on create
                ChangeNotifierProvider(create: (_) => ConfigProvider()), // Loads data on create
                ChangeNotifierProvider(create: (_) => BudgetProvider()), // Loads data on create
              ],
              child: const MainLayout(),
            );
          } else {
            // User is not logged in -> Show Login
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
