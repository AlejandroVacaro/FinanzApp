import '../../../models/transaction_model.dart';
import '../../../models/category.dart';
import '../../../providers/budget_provider.dart';

class DashboardCalculator {
  // Helpers to get correct values in Pesos
  static double getAmountInPesos(Transaction t) {
      if (t.amountUYU != 0) return t.amountUYU;
      return t.amount;
  }

  static bool isExcludedFromOperativeFlow(Transaction t) {
      final c = t.category.toLowerCase();
      // Exclude transfers, unknown, and savings from period analysis
      if (c.contains('puente') || c.contains('no asignada') || c.contains('ahorro')) {
          return true;
      }
      return false;
  }

  // --- SECCIÓN 1: KPIs Rápidos ---

  // 1. Liquidez Total / Patrimonio Neto (Histórico Global)
  static double calculateNetWorth(List<Transaction> allTxs) {
      double total = 0;
      for (var t in allTxs) {
          total += getAmountInPesos(t);
      }
      return total;
  }

  // 2. Ingresos del Período
  static double calculatePeriodIncome(List<Transaction> periodTxs) {
      double sum = 0;
      for (var t in periodTxs) {
          if (isExcludedFromOperativeFlow(t)) continue;
          double amt = getAmountInPesos(t);
          if (amt > 0) sum += amt;
      }
      return sum;
  }

  // 3. Egresos del Período
  static double calculatePeriodExpense(List<Transaction> periodTxs) {
      double sum = 0;
      for (var t in periodTxs) {
          if (isExcludedFromOperativeFlow(t)) continue;
          double amt = getAmountInPesos(t);
          if (amt < 0) sum += amt;
      }
      return sum; // returns negative
  }

  // 6. Tasa de Ahorro (% de ingresos no gastados)
  static double calculateSavingsRate(double income, double expenseAbs) {
     if (income <= 0) return 0.0;
     double saved = income - expenseAbs;
     if (saved <= 0) return 0.0;
     return (saved / income) * 100;
  }

  // 7. Gasto Promedio Diario
  static double calculateDailyAverage(double expenseAbs, DateTime? selectedMonth) {
      if (expenseAbs == 0) return 0.0;
      int days = 1;
      final now = DateTime.now();
      
      if (selectedMonth == null) {
          // If no month is selected, this might be all time. 
          // Default to 1 to avoid crash, or approx 30
          days = 30; 
      } else {
          // If selected month is current month, divide by days passed.
          // Otherwise divide by total days in that month.
          if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
              days = now.day;
          } else {
              days = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
          }
      }
      return (expenseAbs / days);
  }

  // 5. Presupuesto Consumido (Porcentaje)
  static double calculateBudgetConsumedPercent(double expenseAbs, DateTime month, BudgetProvider budgetProvider) {
       double totalBudget = 0;
       // Assuming getBudgets() or similar exists. We can also approximate by checking all categories.
       // We'll calculate it broadly in the UI if we get access to the list of budgets.
       return 0; // will be resolved in the widget
  }

  // --- SECCIÓN 4: Insights ---

  // 13. Top Comercios
  static List<MapEntry<String, double>> getTopMerchants(List<Transaction> periodTxs, {int limit = 5}) {
      Map<String, double> merchants = {};
      for (var t in periodTxs) {
         if (isExcludedFromOperativeFlow(t)) continue;
         double amt = getAmountInPesos(t);
         if (amt < 0) { // Only expenses
             // Clean description
             String desc = t.description.trim().toUpperCase();
             if (desc.isEmpty) desc = "DESCONOCIDO";
             merchants[desc] = (merchants[desc] ?? 0) + amt.abs();
         }
      }
      var sorted = merchants.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
      return sorted.take(limit).toList();
  }

  // 14. Top Categorías
  static List<MapEntry<String, double>> getTopCategories(List<Transaction> periodTxs, {int limit = 5}) {
      Map<String, double> cats = {};
      for (var t in periodTxs) {
         if (isExcludedFromOperativeFlow(t)) continue;
         double amt = getAmountInPesos(t);
         if (amt < 0) {
             cats[t.category] = (cats[t.category] ?? 0) + amt.abs();
         }
      }
      var sorted = cats.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
      return sorted.take(limit).toList();
  }

  // 15. Top Transacciones individuales
  static List<Transaction> getTopTransactions(List<Transaction> periodTxs, {int limit = 3}) {
      List<Transaction> expenses = periodTxs.where((t) {
         if (isExcludedFromOperativeFlow(t)) return false;
         return getAmountInPesos(t) < 0;
      }).toList();

      expenses.sort((a, b) => getAmountInPesos(a).abs().compareTo(getAmountInPesos(b).abs()));
      // descending
      return expenses.reversed.take(limit).toList();
  }

  // 16. Gastos Hormiga (< $500, ordered by count)
  static List<MapEntry<String, int>> getAntExpenses(List<Transaction> periodTxs, {int limit = 5, double threshold = 500}) {
      Map<String, int> counts = {};
      Map<String, double> sums = {};

      for (var t in periodTxs) {
          if (isExcludedFromOperativeFlow(t)) continue;
          double amt = getAmountInPesos(t).abs();
          
          if (getAmountInPesos(t) < 0 && amt <= threshold) {
              String desc = t.description.trim().toUpperCase();
              if (desc.isEmpty) desc = "DESCONOCIDO";
              counts[desc] = (counts[desc] ?? 0) + 1;
              sums[desc] = (sums[desc] ?? 0) + amt;
          }
      }
      
      // Filter out if they only occurred once? Maybe keep all.
      var sorted = counts.entries.toList()..sort((a,b) {
          int countCompare = b.value.compareTo(a.value);
          if (countCompare == 0) { // If same count, prefer highest total spend
               return (sums[b.key] ?? 0).compareTo((sums[a.key] ?? 0));
          }
          return countCompare;
      });

      return sorted.take(limit).toList();
  }
}
