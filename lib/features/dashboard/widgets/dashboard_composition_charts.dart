import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/config_provider.dart';
import '../../../models/category.dart';
import '../utils/dashboard_calculator.dart';
import 'dashboard_hover_card.dart';

class DashboardCompositionCharts extends StatefulWidget {
  final List<Transaction> periodTxs;
  final ConfigProvider configProvider;

  const DashboardCompositionCharts({
    super.key,
    required this.periodTxs,
    required this.configProvider,
  });

  @override
  State<DashboardCompositionCharts> createState() => _DashboardCompositionChartsState();
}

class _DashboardCompositionChartsState extends State<DashboardCompositionCharts> {
  int _touchedIndexExpense = -1;
  int _touchedIndexIncome = -1;

  @override
  Widget build(BuildContext context) {
    // If mobile, they might want PageView or Column. The user asked for "PageView o Row de 2 columnas".
    // We can use a Row wrapped in an intrinsic height or expanded if inside a SliverToBoxAdapter/Wrap.
    // Let's use a Wrap or Row. We'll use a Row inside a container, assuming wide screen (desktop/web). 
    // Wait, Wrap is better for responsiveness.

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 600;
        
        List<Widget> children = [
          if (isWide)
            Expanded(child: _buildPieChart(CategoryType.expense, "Composición de Egresos", _touchedIndexExpense, (i) => setState(() => _touchedIndexExpense = i)))
          else
            _buildPieChart(CategoryType.expense, "Composición de Egresos", _touchedIndexExpense, (i) => setState(() => _touchedIndexExpense = i)),
            
          if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),
          
          if (isWide)
            Expanded(child: _buildPieChart(CategoryType.income, "Ingresos por Rubro", _touchedIndexIncome, (i) => setState(() => _touchedIndexIncome = i)))
          else
            _buildPieChart(CategoryType.income, "Ingresos por Rubro", _touchedIndexIncome, (i) => setState(() => _touchedIndexIncome = i)),
        ];

        if (isWide) {
          return IntrinsicHeight(child: Row(children: children));
        } else {
          return Column(children: children);
        }
      }
    );
  }

  Widget _buildPieChart(CategoryType type, String title, int touchedIndex, Function(int) onTouch) {
     Map<String, double> catSums = {};
     double totalSum = 0;

     for (var tx in widget.periodTxs) {
         if (DashboardCalculator.isExcludedFromOperativeFlow(tx)) continue;

         // Determine category type via configProvider
         final catObj = widget.configProvider.categories.firstWhere(
             (c) => c.name == tx.category, 
             orElse: () => const Category(id: '?', name: 'Unknown', type: CategoryType.expense, icon: 'help', color: '#000')
         );

         // We want to sum if the category type matches the requested type
         // e.g., only sum CategoryType.expense for Expenses Pie Chart
         if (catObj.type == type) {
             double val = DashboardCalculator.getAmountInPesos(tx).abs();
             catSums[tx.category] = (catSums[tx.category] ?? 0) + val;
             totalSum += val;
         }
     }

     if (catSums.isEmpty) {
        return DashboardHoverCard(
            height: 250,
            child: Column(
                children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Expanded(child: Center(child: Text("Sin datos", style: TextStyle(color: Colors.white54)))),
                ]
            )
        );
     }

     final sortedEntries = catSums.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
     final topEntries = sortedEntries.take(8).toList(); // Show top 8 max

     const List<Color> luxColors = [
         Color(0xFF00E5FF), Color(0xFF3B82F6), Color(0xFF8B5CF6),
         Color(0xFFF43F5E), Color(0xFF10B981), Color(0xFFEAB308),
         Color(0xFF06B6D4), Color(0xFF6366F1),
     ];

     String centerText1 = "";
     String centerText2 = "";
     Color centerColor = Colors.white;

     if (touchedIndex != -1 && touchedIndex < topEntries.length) {
         final entry = topEntries[touchedIndex];
         final pct = totalSum > 0 ? (entry.value / totalSum * 100) : 0;
         centerText1 = entry.key;
         centerText2 = "${pct.toStringAsFixed(1)}%";
         centerColor = luxColors[touchedIndex % luxColors.length];
     }

     return DashboardHoverCard(
         height: 250,
         child: Column(
             children: [
                 Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 12),
                 Expanded(
                     child: Stack(
                         alignment: Alignment.center,
                         children: [
                             PieChart(
                                 PieChartData(
                                     pieTouchData: PieTouchData(
                                         touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                                onTouch(-1);
                                                return;
                                            }
                                            onTouch(pieTouchResponse.touchedSection!.touchedSectionIndex);
                                         }
                                     ),
                                     borderData: FlBorderData(show: false),
                                     sectionsSpace: 2,
                                     centerSpaceRadius: 60,
                                     sections: topEntries.asMap().entries.map((e) {
                                         final i = e.key;
                                         final isTouched = i == touchedIndex;
                                         final color = luxColors[i % luxColors.length];
                                         return PieChartSectionData(
                                             color: color.withValues(alpha: isTouched ? 1.0 : 0.7),
                                             value: e.value.value,
                                             showTitle: false,
                                             radius: isTouched ? 45.0 : 40.0,
                                         );
                                     }).toList(),
                                 )
                             ),
                             if (centerText1.isNotEmpty)
                               Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      Text(centerText1, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                      Text(centerText2, style: TextStyle(color: centerColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ]
                               )
                         ]
                     )
                 )
             ]
         )
     );
  }
}
