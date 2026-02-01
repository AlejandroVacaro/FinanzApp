import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transactions_provider.dart';
import '../../config/app_theme.dart';

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text("Mi Balance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Net Worth Card
                    Consumer<TransactionsProvider>(
                      builder: (context, provider, child) {
                        final netWorth = provider.netWorth;
                        final color = netWorth >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
                        final currencyFormat = NumberFormat.currency(symbol: '\$U ', decimalDigits: 2, locale: "es_UY");

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "Patrimonio Neto",
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currencyFormat.format(netWorth),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    const Text(
                      "Mis Cuentas",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // Added color white
                    ),
                    const SizedBox(height: 16),

                    // Accounts List
                    Consumer<TransactionsProvider>(
                      builder: (context, provider, child) {
                        final balances = provider.accountBalances;
                        if (balances.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text("No hay cuentas registradas. Importa movimientos primero.", style: TextStyle(color: Colors.grey)),
                            ),
                          );
                        }

                        final accounts = balances.keys.toList();
                        final currencyFormat = NumberFormat.currency(symbol: '\$U ', decimalDigits: 2, locale: "es_UY");

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWeb ? 3 : 1,
                            childAspectRatio: 3.5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: accounts.length,
                          itemBuilder: (context, index) {
                            final accountName = accounts[index];
                            final balance = balances[accountName] ?? 0.0;
                            final isDebt = balance < 0;
                            final isCard = accountName.toLowerCase().contains("visa") || accountName.toLowerCase().contains("tarjeta");
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF374151), // Darker card bg
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                                boxShadow: [
                                   BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                   )
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isCard ? Colors.deepPurple.shade900 : Colors.blue.shade900,
                                      shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCard ? Icons.credit_card : Icons.account_balance,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            accountName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isCard ? "Tarjeta de Crédito" : "Cuenta Bancaria",
                                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      currencyFormat.format(balance),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDebt ? Colors.redAccent : Colors.greenAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
