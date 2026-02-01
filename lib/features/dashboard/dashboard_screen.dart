import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transactions_provider.dart';
import '../../providers/config_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category.dart';
import '../../config/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Chart 1 Filters
  bool showIncome = true;
  bool showExpense = true;
  bool showSavings = true;
  bool showResult = true;

  // Chart 2 Filters
  String? selectedCategoryForChart;

  // Time Filters
  DateTime? selectedMonth; // Null means "All Time"
  int selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    // Default to current month
    selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
      final txProvider = Provider.of<TransactionsProvider>(context);
      final configProvider = Provider.of<ConfigProvider>(context);
      
      final allTxs = txProvider.transactions;
      
      // Filter Logic
      List<Transaction> filteredTxs = allTxs;
      if (selectedMonth != null) {
          filteredTxs = allTxs.where((t) => t.date.year == selectedMonth!.year && t.date.month == selectedMonth!.month).toList();
      }

      // Calculate Card Totals
      double income = filteredTxs.where((t) => t.amount > 0).fold(0, (sum, t) => sum + t.amount);
      double expense = filteredTxs.where((t) => t.amount < 0).fold(0, (sum, t) => sum + t.amount);
      double result = income + expense;

      return Scaffold(
          backgroundColor: AppColors.backgroundDark, 
          appBar: AppBar(
             title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
             backgroundColor: Colors.transparent,
             elevation: 0,
             centerTitle: true,
             scrolledUnderElevation: 0,
          ),
          body: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          children: [
                              // 1. Time Filters
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                     Row(
                                       children: [
                                          const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                                          const SizedBox(width: 8),
                                          DropdownButton<int>(
                                            value: selectedMonth?.month,
                                            dropdownColor: const Color(0xFF374151),
                                            style: const TextStyle(color: Colors.white),
                                            hint: const Text("Todo", style: TextStyle(color: Colors.white)),
                                            underline: const SizedBox(),
                                            items: [
                                               if (selectedMonth == null) 
                                                   const DropdownMenuItem(value: null, child: Text("Histórico")),
                                               ...List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(
                                                    value: m, 
                                                    child: Text(DateFormat('MMMM', 'es').format(DateTime(2000, m)).capitalize())
                                               ))
                                            ],
                                            onChanged: (v) => setState(() {
                                                if (v == null) {
                                                   selectedMonth = null;
                                                } else {
                                                   selectedMonth = DateTime(selectedYear, v);
                                                }
                                            }),
                                          ),
                                          if (selectedMonth != null) ...[
                                              const SizedBox(width: 8),
                                              DropdownButton<int>(
                                                value: selectedYear,
                                                dropdownColor: const Color(0xFF374151),
                                                style: const TextStyle(color: Colors.white),
                                                underline: const SizedBox(),
                                                items: List.generate(5, (i) => DateTime.now().year - 2 + i).map((y) => DropdownMenuItem(
                                                     value: y, child: Text(y.toString())
                                                )).toList(),
                                                onChanged: (v) => setState(() {
                                                    selectedYear = v!;
                                                    selectedMonth = DateTime(selectedYear, selectedMonth!.month);
                                                }),
                                              )
                                          ]
                                       ],
                                     ),
                                     TextButton.icon(
                                       onPressed: () => setState(() => selectedMonth = null), 
                                       icon: const Icon(Icons.restore, color: Colors.blueAccent), 
                                       label: const Text("Ver Histórico", style: TextStyle(color: Colors.blueAccent))
                                     )
                                  ],
                                ),
                              ),

                              // 2. Summary Cards
                              Row(
                                  children: [
                                      _buildSummaryCard("Ingresos", income, Colors.green),
                                      const SizedBox(width: 12),
                                      _buildSummaryCard("Egresos", expense, Colors.red),
                                      const SizedBox(width: 12),
                                      _buildSummaryCard("Resultado", result, result >= 0 ? Colors.blue : Colors.orange),
                                  ],
                              ),
                              const SizedBox(height: 16),

                              // 3. Charts Area
                              SizedBox(
                                  height: 500, 
                                  child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          // LEFT: Line Charts Area
                                          Expanded(
                                              flex: 2,
                                              child: Column(
                                                  children: [
                                                      // Chart 1: General Trends
                                                      Expanded(
                                                          child: Container(
                                                              padding: const EdgeInsets.all(16),
                                                              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
                                                              child: Column(
                                                                  children: [
                                                                      _buildChartTitle("Evolución General", [
                                                                          _buildToggle("Ingresos", Colors.green, showIncome, (v) => setState(() => showIncome = v)),
                                                                          _buildToggle("Egresos", Colors.red, showExpense, (v) => setState(() => showExpense = v)),
                                                                          _buildToggle("Ahorro", Colors.orange, showSavings, (v) => setState(() => showSavings = v)),
                                                                          _buildToggle("Result", Colors.blue, showResult, (v) => setState(() => showResult = v)),
                                                                      ]),
                                                                      const SizedBox(height: 16),
                                                                      Expanded(child: _buildMainLineChart(filteredTxs)), // Pass Filtered
                                                                  ],
                                                              ),
                                                          ),
                                                      ),
                                                      const SizedBox(height: 16),
                                                      // Chart 2: Category Specific
                                                      Expanded(
                                                          child: Container(
                                                              padding: const EdgeInsets.all(16),
                                                              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
                                                              child: Column(
                                                                  children: [
                                                                      Row(
                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                              const Text("Evolución por Rubro", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                                                              DropdownButton<String>(
                                                                                  value: selectedCategoryForChart,
                                                                                  hint: const Text("Seleccionar Rubro", style: TextStyle(color: Colors.white70)),
                                                                                  dropdownColor: const Color(0xFF374151),
                                                                                  style: const TextStyle(color: Colors.white),
                                                                                  items: configProvider.categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                                                                                  onChanged: (v) => setState(() => selectedCategoryForChart = v),
                                                                              ),
                                                                          ],
                                                                      ),
                                                                      const SizedBox(height: 16),
                                                                      Expanded(child: _buildCategoryLineChart(filteredTxs)), // Pass Filtered
                                                                  ],
                                                              ),
                                                          ),
                                                      ),
                                                  ],
                                              ),
                                          ),
                                          const SizedBox(width: 16),
                                          // RIGHT: Pie Charts Area
                                          Expanded(
                                              flex: 1,
                                              child: Column(
                                                  children: [
                                                       Expanded(
                                                           child: _buildPieChartContainer("Ingresos por Rubro", filteredTxs, CategoryType.income), // Pass Filtered
                                                       ),
                                                       const SizedBox(height: 16),
                                                       Expanded(
                                                           child: _buildPieChartContainer("Egresos por Rubro", filteredTxs, CategoryType.expense), // Pass Filtered
                                                       ),
                                                  ],
                                              ),
                                          ),
                                      ],
                                  ),
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

  // --- HELPERS ---

  Widget _buildToggle(String label, Color color, bool value, Function(bool) onChanged) {
      return Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: InkWell(
            onTap: () => onChanged(!value),
            child: Row(
                children: [
                    Icon(value ? Icons.check_box : Icons.check_box_outline_blank, color: color, size: 18),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(color: color, fontSize: 12)),
                ],
            ),
        ),
      );
  }

  Widget _buildChartTitle(String title, List<Widget> actions) {
      return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Row(children: actions),
          ],
      );
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
      return Expanded(
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3))
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(title, style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(value), 
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
              ),
          ),
      );
  }

  // --- CHART LOGIC ---

  Map<DateTime, Map<String, double>> _prepareMonthlyData(List<Transaction> txs) {
      txs.sort((a, b) => a.date.compareTo(b.date));
      if (txs.isEmpty) return {};

      Map<DateTime, Map<String, double>> data = {};
      
      bool isDaily = selectedMonth != null;

      for (var tx in txs) {
          DateTime key;
          if (isDaily) {
             key = DateTime(tx.date.year, tx.date.month, tx.date.day);
          } else {
             key = DateTime(tx.date.year, tx.date.month);
          }
          
          if (!data.containsKey(key)) {
             data[key] = { "income": 0.0, "expense": 0.0, "savings": 0.0, "result": 0.0, "category": 0.0 };
          }
          
          if (tx.amount > 0) data[key]!["income"] = (data[key]!["income"] ?? 0) + tx.amount;
          else data[key]!["expense"] = (data[key]!["expense"] ?? 0) + tx.amount;
          
          data[key]!["result"] = (data[key]!["result"] ?? 0) + tx.amount;

          if (selectedCategoryForChart != null && tx.category == selectedCategoryForChart) {
               data[key]!["category"] = (data[key]!["category"] ?? 0) + tx.amount;
          }
      }
      return Map.fromEntries(data.entries.toList()..sort((a,b) => a.key.compareTo(b.key)));
  }

  Widget _buildMainLineChart(List<Transaction> txs) {
      final data = _prepareMonthlyData(txs);
      final keys = data.keys.toList();
      
      if (keys.isEmpty) return const Center(child: Text("Sin datos", style: TextStyle(color: Colors.white54)));
      
      bool isDaily = selectedMonth != null;

      return LineChart(
        LineChartData(
          minY: -50000, maxY: 150000, 
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                   int index = val.toInt();
                   if (index >= 0 && index < keys.length) {
                       final date = keys[index];
                       String text = isDaily ? DateFormat('d').format(date) : DateFormat('MMM').format(date);
                       return Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10)));
                   }
                   return const Text("");
                },
                reservedSize: 30,
                interval: (keys.length > 10) ? (keys.length / 10).ceil().toDouble() : 1, // Avoid crowding
              ),
            ),
            leftTitles: AxisTitles(
               sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (val, _) => Text(NumberFormat.compact().format(val), style: const TextStyle(color: Colors.white70, fontSize: 10))),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
             touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.black87, // Updated API
                getTooltipItems: (touchedSpots) {
                   return touchedSpots.map((spot) {
                      return LineTooltipItem(
                         "${NumberFormat.currency(symbol: '\$').format(spot.y)}",
                         TextStyle(color: spot.bar.color, fontWeight: FontWeight.bold)
                      );
                   }).toList();
                }
             )
          ),
          lineBarsData: [
             if (showIncome) _buildLine(keys, data, "income", Colors.green),
             if (showExpense) _buildLine(keys, data, "expense", Colors.red),
             if (showResult) _buildLine(keys, data, "result", Colors.blue),
          ],
        ),
      );
  }
  
  LineChartBarData _buildLine(List<DateTime> months, Map<DateTime, Map<String, double>> data, String key, Color color) {
      return LineChartBarData(
          spots: months.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), data[e.value]![key] ?? 0);
          }).toList(),
          isCurved: true,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
      );
  }

  Widget _buildCategoryLineChart(List<Transaction> txs) {
       if (selectedCategoryForChart == null) return const Center(child: Text("Selecciona un rubro", style: TextStyle(color: Colors.white54)));

       final data = _prepareMonthlyData(txs);
       final months = data.keys.toList();
       if (months.isEmpty) return const SizedBox();

       return LineChart(
          LineChartData(
             titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                       int index = val.toInt();
                       if (index >= 0 && index < months.length) {
                           return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('d').format(months[index]), style: const TextStyle(color: Colors.white70, fontSize: 10)));
                       }
                       return const Text("");
                    },
                    reservedSize: 30,
                    interval: 1,
                  ),
                ),
                leftTitles: AxisTitles(
                   sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (val, _) => Text(NumberFormat.compact().format(val), style: const TextStyle(color: Colors.white70, fontSize: 10))),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
             ),
             gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1)),
             borderData: FlBorderData(show: false),
             lineBarsData: [
                 _buildLine(months, data, "category", Colors.purpleAccent),
             ]
          )
       );
  }

  Widget _buildPieChartContainer(String title, List<Transaction> txs, CategoryType type) {
      final config = Provider.of<ConfigProvider>(context, listen: false);
      Map<String, double> catSums = {};
      double totalSum = 0;

      for (var tx in txs) {
          final cat = config.categories.firstWhere((c) => c.name == tx.category, orElse: () => const Category(id: '?', name: 'Unknown', type: CategoryType.expense, icon: 'help_outline', color: '#9E9E9E'));
          
          if (cat.type == type) {
              double val = tx.amount.abs();
              catSums[tx.category] = (catSums[tx.category] ?? 0) + val;
              totalSum += val;
          }
      }
      
      if (catSums.isEmpty) return _buildTile(title, const Center(child: Text("Sin datos", style: TextStyle(color: Colors.white54))));

      final sortedEntries = catSums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topEntries = sortedEntries.take(5).toList(); 

      return _buildTile(
          title,
          Row(
              children: [
                   Expanded(
                       flex: 3,
                       child: PieChart(
                           PieChartData(
                               sectionsSpace: 2,
                               centerSpaceRadius: 30,
                               sections: topEntries.map((e) {
                                   final index = topEntries.indexOf(e);
                                   final color = Colors.primaries[index % Colors.primaries.length];
                                   return PieChartSectionData(
                                       value: e.value,
                                       color: color,
                                       radius: 40,
                                       showTitle: false,
                                   );
                               }).toList(),
                           )
                       ),
                   ),
                   Expanded(
                       flex: 2,
                       child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: topEntries.map((e) {
                               final index = topEntries.indexOf(e);
                               final color = Colors.primaries[index % Colors.primaries.length];
                               return Padding(
                                 padding: const EdgeInsets.symmetric(vertical: 2.0),
                                 child: Row(
                                     children: [
                                         Container(width: 8, height: 8, color: color),
                                         const SizedBox(width: 4),
                                         Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 10), overflow: TextOverflow.ellipsis)),
                                     ],
                                 ),
                               );
                           }).toList(),
                       )
                   )
              ],
          )
      );
  }
  
  Widget _buildTile(String title, Widget child) {
       return Container(
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
           child: Column(
               children: [
                   Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   Expanded(child: child),
               ],
           ),
       );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
