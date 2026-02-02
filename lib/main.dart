import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      scrollBehavior: MyCustomScrollBehavior(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}


class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isInit = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        // 1. Auth Loading or App Init Loading
        if (snapshot.connectionState == ConnectionState.waiting || (_isInit && snapshot.hasData == false)) {
             return const Scaffold(
              backgroundColor: Color(0xFF111827),
              body: Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
           );
        }

        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          
          if (!_isInit) {
             // Initialize providers once
             WidgetsBinding.instance.addPostFrameCallback((_) async {
                 // Initialize
                 Provider.of<TransactionsProvider>(context, listen: false).init(uid);
                 Provider.of<ConfigProvider>(context, listen: false).init(uid);
                 Provider.of<BudgetProvider>(context, listen: false).init(uid);
                 
                 // Fake delay for smooth spinner UX (optional, but requested "pon un spinner")
                 await Future.delayed(const Duration(milliseconds: 800));
                 
                 if (mounted) setState(() => _isInit = true);
             });
             
             // Show spinner while initializing
             return const Scaffold(
                backgroundColor: Color(0xFF111827),
                body: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
             );
          }

          return const MainLayout();
        } else {
           // Not logged in
           return const LoginScreen();
        }
      },
    );
  }
}
