import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa email y contraseña')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // Navigation is handled by the AuthGate in main.dart
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundDark, Color(0xFF131B2D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Align(
          alignment: const Alignment(0, -0.2), // Sube un poco el contenido
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Rocket Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryPurple, AppColors.secondaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ]
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 50),
                ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 20),
                const Text(
                  'FinanzApp',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5, end: 0),
                const SizedBox(height: 40),
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.panelBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Bienvenido',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textWhite,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: AppColors.textWhite),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textGrey),
                          filled: true,
                          fillColor: AppColors.backgroundDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        style: const TextStyle(color: AppColors.textWhite),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: const TextStyle(color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textGrey),
                          filled: true,
                          fillColor: AppColors.backgroundDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
                          ),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: AppColors.primaryPurple.withValues(alpha: 0.5),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Ingresar',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
