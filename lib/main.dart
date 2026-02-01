import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'providers/transactions_provider.dart';
import 'providers/config_provider.dart';
import 'providers/budget_provider.dart';
import 'features/auth/login_screen.dart';
import 'widgets/main_layout.dart';
import 'services/auth_service.dart';
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionsProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
      ],
      child: const FinanzApp(),
    ),
  );
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
      title: 'FinanzApp',
      locale: const Locale('es'),
      scrollBehavior: MyCustomScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(
              backgroundColor: Color(0xFF111827),
              body: Center(child: CircularProgressIndicator()),
           );
        }

        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          
          // Initialize providers with UID
          // Using addPostFrameCallback to avoid state setting during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
             Provider.of<TransactionsProvider>(context, listen: false).init(uid);
             Provider.of<ConfigProvider>(context, listen: false).init(uid);
             Provider.of<BudgetProvider>(context, listen: false).init(uid);
          });

          return const MainLayout();
        } else {
           // Clear providers
           WidgetsBinding.instance.addPostFrameCallback((_) {
             Provider.of<TransactionsProvider>(context, listen: false).clear();
             Provider.of<ConfigProvider>(context, listen: false).clear();
             Provider.of<BudgetProvider>(context, listen: false).clear();
          });

          return const LoginScreen();
        }
      },
    );
  }
}
