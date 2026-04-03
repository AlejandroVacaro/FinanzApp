import 'package:flutter/material.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../utils/format_utils.dart';
import '../utils/dashboard_calculator.dart';
import 'dashboard_hover_card.dart';

class DashboardMetricsGrid extends StatelessWidget {
  final List<Transaction> allTxs;
  final List<Transaction> periodTxs;
  final DateTime? selectedMonth;
  final BudgetProvider budgetProvider;

  const DashboardMetricsGrid({
    super.key,
    required this.allTxs,
    required this.periodTxs,
    required this.selectedMonth,
    required this.budgetProvider,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculations
    final double netWorth = DashboardCalculator.calculateNetWorth(allTxs);
    final double income = DashboardCalculator.calculatePeriodIncome(periodTxs);
    final double expenseAbs = DashboardCalculator.calculatePeriodExpense(periodTxs).abs();
    final double netFlow = income - expenseAbs;
    final double savingsRate = DashboardCalculator.calculateSavingsRate(income, expenseAbs);
    final double avgDaily = DashboardCalculator.calculateDailyAverage(expenseAbs, selectedMonth);

    // ConfigProvider should be used for real budgets, simplified here.

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate exact width for 3 items per row, or 2 if too small
        int cols = constraints.maxWidth < 600 ? 2 : 3;
        final spacing = 12.0;
        final w = (constraints.maxWidth - (spacing * (cols - 1))) / cols;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                 _buildMetricCard(context, "Patrimonio Total", netWorth, Colors.blueAccent, w),
                 _buildMetricCard(context, "Ingresos", income, Colors.green, w),
                 _buildMetricCard(context, "Egresos", -expenseAbs, Colors.redAccent, w),
                 _buildMetricCard(context, "Flujo Neto", netFlow, netFlow >= 0 ? Colors.blue : Colors.orange, w),
                 _buildPercentCard(context, "Tasa de Ahorro", savingsRate, Colors.tealAccent, w),
                 _buildMetricCard(context, "Gasto Diario Promedio", -avgDaily, Colors.amber, w),
              ],
            ),
            const SizedBox(height: 16),
            // Budget Bar
            _buildBudgetBar(expenseAbs, 50000, context),
          ],
        );
      }
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, double value, Color color, double width) {
    return DashboardHoverCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            FormatUtils.formatCurrency(value, 'UYU'), 
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPercentCard(BuildContext context, String title, double percent, Color color, double width) {
    return DashboardHoverCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            "${percent.toStringAsFixed(1)}%", 
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetBar(double expenseAbs, double totalBudget, BuildContext context) {
      if (selectedMonth == null) return const SizedBox(); // Don't show generic budget for "All Time"

      double ratio = totalBudget > 0 ? (expenseAbs / totalBudget) : 0.0;
      if (ratio > 1.0) ratio = 1.0;
      
      Color barColor = Colors.green;
      if (ratio > 0.8) barColor = Colors.redAccent;
      else if (ratio > 0.5) barColor = Colors.orange;

      return DashboardHoverCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          const Text("Presupuesto Mensual Global Consumido", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text("${(ratio * 100).toStringAsFixed(1)}%", style: TextStyle(color: barColor, fontWeight: FontWeight.bold)),
                      ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 12,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                  ),
              ],
          ),
      );
  }
}
