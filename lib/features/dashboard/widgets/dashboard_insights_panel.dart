import 'package:flutter/material.dart';
import '../../../models/transaction_model.dart';
import '../../../utils/format_utils.dart';
import '../utils/dashboard_calculator.dart';
import 'dashboard_hover_card.dart';

class DashboardInsightsPanel extends StatelessWidget {
  final List<Transaction> periodTxs;

  const DashboardInsightsPanel({
    super.key,
    required this.periodTxs,
  });

  @override
  Widget build(BuildContext context) {
    if (periodTxs.isEmpty) {
        return const SizedBox();
    }

    // 13. Top Comercios
    final topMerchants = DashboardCalculator.getTopMerchants(periodTxs);
    // 14. Top Categorías
    final topCategories = DashboardCalculator.getTopCategories(periodTxs);
    // 15. Top Transacciones
    final topTransactions = DashboardCalculator.getTopTransactions(periodTxs);
    // 16. Gastos Hormiga
    final antExpenses = DashboardCalculator.getAntExpenses(periodTxs, limit: 5, threshold: 500);

    return DashboardHoverCard(
        padding: EdgeInsets.zero,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("Insights y Rankings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Divider(height: 1, color: Colors.white10),
                
                _buildExpansionTile("Top Comercios", Icons.store, topMerchants.map((e) => _buildRankRow(e.key, e.value)).toList()),
                _buildExpansionTile("Top Categorías", Icons.category, topCategories.map((e) => _buildRankRow(e.key, e.value)).toList()),
                _buildExpansionTile(
                    "Top 3 Transacciones Más Altas", 
                    Icons.trending_up, 
                    topTransactions.map((t) => _buildRankRow(t.description, DashboardCalculator.getAmountInPesos(t).abs())).toList()
                ),
                _buildExpansionTile(
                    "Gastos Hormiga (Frecuentes < \$500)", 
                    Icons.pest_control, 
                    antExpenses.map((e) => _buildRankRow("${e.key} (${e.value} veces)", -1, trailingText: "")).toList() 
                ),
            ],
        ),
    );
  }

  Widget _buildExpansionTile(String title, IconData icon, List<Widget> children) {
      if (children.isEmpty) {
          children = [const Padding(padding: EdgeInsets.all(16), child: Text("Sin datos suficientes", style: TextStyle(color: Colors.white54)))];
      }
      return ExpansionTile(
          collapsedIconColor: Colors.white54,
          iconColor: Colors.blueAccent,
          leading: Icon(icon, color: Colors.blueAccent, size: 20),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          children: children,
      );
  }

  Widget _buildRankRow(String label, double amount, {String? trailingText}) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Expanded(child: Text(label, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
                  Text(
                      trailingText ?? FormatUtils.formatCurrency(amount, 'UYU'), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
              ],
          ),
      );
  }
}
