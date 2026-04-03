import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction_model.dart';
import '../../../utils/format_utils.dart';
import '../utils/dashboard_calculator.dart';
import 'dashboard_hover_card.dart';

class DashboardTrendCharts extends StatelessWidget {
  final List<Transaction> allTxs;
  final DateTime? selectedMonth;

  const DashboardTrendCharts({
    super.key,
    required this.allTxs,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _build6MonthTrendBarChart(),
        const SizedBox(height: 16),
        _buildNetWorthLineChart(),
        const SizedBox(height: 16),
        _buildComparativeLineChart(),
      ],
    );
  }

  // --- 10. Tendencia 6 meses (BarChart: Ingresos vs Egresos por mes) ---
  Widget _build6MonthTrendBarChart() {
     // Ignores time filter. Last 6 months up to now.
     final now = DateTime.now();
     List<DateTime> last6Months = [];
     for (int i = 5; i >= 0; i--) {
        last6Months.add(DateTime(now.year, now.month - i, 1));
     }

     Map<DateTime, Map<String, double>> data = {};
     for (var m in last6Months) {
         data[m] = {"inc": 0.0, "exp": 0.0};
     }

     for (var t in allTxs) {
         if (DashboardCalculator.isExcludedFromOperativeFlow(t)) continue;
         
         final dateKey = DateTime(t.date.year, t.date.month, 1);
         if (data.containsKey(dateKey)) {
             double amt = DashboardCalculator.getAmountInPesos(t);
             if (amt > 0) {
                 data[dateKey]!["inc"] = data[dateKey]!["inc"]! + amt;
             } else {
                 data[dateKey]!["exp"] = data[dateKey]!["exp"]! + amt.abs();
             }
         }
     }

     double maxY = 0;
     for (var v in data.values) {
         if (v["inc"]! > maxY) maxY = v["inc"]!;
         if (v["exp"]! > maxY) maxY = v["exp"]!;
     }
     if (maxY == 0) maxY = 100;

     return _buildCard("Tendencia 6 Meses", SizedBox(
         height: 250,
         child: BarChart(
             BarChartData(
                 maxY: maxY * 1.2,
                 barGroups: last6Months.asMap().entries.map((e) {
                     final int i = e.key;
                     final m = e.value;
                     final vals = data[m]!;
                     return BarChartGroupData(
                         x: i,
                         barRods: [
                             BarChartRodData(toY: vals["inc"]!, color: const Color(0xFF10B981), width: 8, borderRadius: BorderRadius.circular(4)),
                             BarChartRodData(toY: vals["exp"]!, color: const Color(0xFFEF4444), width: 8, borderRadius: BorderRadius.circular(4)),
                         ],
                     );
                 }).toList(),
                 titlesData: FlTitlesData(
                     bottomTitles: AxisTitles(
                         sideTitles: SideTitles(
                             showTitles: true,
                             getTitlesWidget: (val, _) {
                                 int i = val.toInt();
                                 if (i >= 0 && i < last6Months.length) {
                                     String txt = DateFormat('MMM', 'es').format(last6Months[i]);
                                     return Padding(padding: const EdgeInsets.only(top: 8), child: Text(txt, style: const TextStyle(color: Colors.white70, fontSize: 10)));
                                 }
                                 return const Text("");
                             }
                         )
                     ),
                     leftTitles: AxisTitles(
                         sideTitles: SideTitles(
                             showTitles: true,
                             reservedSize: 45,
                             getTitlesWidget: (val, _) => Text(FormatUtils.formatForChart(val), style: const TextStyle(color: Colors.white70, fontSize: 10))
                         )
                     ),
                     topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 ),
                 gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1)),
                 borderData: FlBorderData(show: false),
                 barTouchData: BarTouchData(
                     touchTooltipData: BarTouchTooltipData(
                         getTooltipColor: (_) => Colors.black87,
                         getTooltipItem: (group, groupIndex, rod, rodIndex) {
                             return BarTooltipItem(
                                 FormatUtils.formatCurrency(rod.toY, 'UYU'),
                                 TextStyle(color: rod.color, fontWeight: FontWeight.bold)
                             );
                         }
                     )
                 )
             )
         )
     ));
  }

  // --- 11. Evolución del Patrimonio Neto ---
  Widget _buildNetWorthLineChart() {
      // Historical cumulative sum over time. Ignorning selectedMonth filter? 
      // User says: "Evolución del Patrimonio Neto (LineChart: Acumulado histórico total a lo largo del tiempo)."
      // So all time!
      if (allTxs.isEmpty) return _buildCard("Evolución Patrimonio Neto", const Center(child: Text("Sin datos")));

      List<Transaction> sortedTxs = List.from(allTxs)..sort((a,b) => a.date.compareTo(b.date));
      List<FlSpot> spots = [];
      double currentNetWorth = 0;
      
      // Group by month to avoid too many points
      Map<DateTime, double> monthlyNW = {};
      for (var t in sortedTxs) {
          currentNetWorth += DashboardCalculator.getAmountInPesos(t);
          DateTime mKey = DateTime(t.date.year, t.date.month, 1);
          monthlyNW[mKey] = currentNetWorth;
      }

      final dates = monthlyNW.keys.toList()..sort();
      double minY = currentNetWorth;
      double maxY = currentNetWorth;
      
      for (int i = 0; i < dates.length; i++) {
          double val = monthlyNW[dates[i]]!;
          if (val < minY) minY = val;
          if (val > maxY) maxY = val;
          spots.add(FlSpot(i.toDouble(), val));
      }

      if (minY == maxY) { minY -= 100; maxY += 100; }
      double range = maxY - minY;

      return _buildCard("Evolución Patrimonio Neto", SizedBox(
         height: 200,
         child: LineChart(
             LineChartData(
                 minY: minY - (range * 0.1),
                 maxY: maxY + (range * 0.1),
                 lineBarsData: [
                     LineChartBarData(
                         spots: spots,
                         isCurved: true,
                         color: const Color(0xFF06B6D4),
                         barWidth: 3,
                         dotData: const FlDotData(show: false),
                         belowBarData: BarAreaData(
                             show: true, 
                             gradient: const LinearGradient(
                                 colors: [Color(0x8806B6D4), Color(0x0006B6D4)],
                                 begin: Alignment.topCenter,
                                 end: Alignment.bottomCenter,
                             )
                         )
                     )
                 ],
                 titlesData: FlTitlesData(
                     bottomTitles: AxisTitles(
                         sideTitles: SideTitles(
                             showTitles: true,
                             reservedSize: 30,
                             getTitlesWidget: (val, _) {
                                 int i = val.toInt();
                                 if (i >= 0 && i < dates.length) {
                                     // Show every N labels to avoid clutter
                                     int step = (dates.length / 6).ceil();
                                     if (step == 0) step = 1;
                                     if (i % step == 0 || i == dates.length - 1) {
                                         return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('MMM-yy', 'es').format(dates[i]), style: const TextStyle(color: Colors.white70, fontSize: 10)));
                                     }
                                 }
                                 return const Text("");
                             }
                         )
                     ),
                     leftTitles: AxisTitles(
                         sideTitles: SideTitles(
                             showTitles: true,
                             reservedSize: 45,
                             getTitlesWidget: (val, _) => Text(FormatUtils.formatForChart(val), style: const TextStyle(color: Colors.white70, fontSize: 10))
                         )
                     ),
                     topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 ),
                 gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1)),
                 borderData: FlBorderData(show: false),
                 lineTouchData: LineTouchData(
                     touchTooltipData: LineTouchTooltipData(
                         getTooltipColor: (_) => Colors.black87,
                         getTooltipItems: (touchedSpots) {
                             return touchedSpots.map((s) => LineTooltipItem(FormatUtils.formatCurrency(s.y, 'UYU'), const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))).toList();
                         }
                     )
                 )
             )
         )
      ));
  }

  // --- 12. Comparativa Gasto ---
  Widget _buildComparativeLineChart() {
      // Current month line vs Previous month up to current day dashed line.
      // Must respect selectedMonth filter? "Línea del mes seleccionado vs mes anterior" makes sense.
      DateTime tMonth = selectedMonth ?? DateTime.now();
      tMonth = DateTime(tMonth.year, tMonth.month, 1);
      DateTime prevMonth = DateTime(tMonth.year, tMonth.month - 1, 1);
      
      int daysInMonth = DateTime(tMonth.year, tMonth.month + 1, 0).day;
      
      Map<int, double> currDaily = {};
      Map<int, double> prevDaily = {};
      
      double currAccum = 0;
      double prevAccum = 0;

      // Ensure days 1 to daysInMonth exist
      for(int i=1; i<=daysInMonth; i++) {
         currDaily[i] = 0;
         prevDaily[i] = 0;
      }

      for (var t in allTxs) {
          if (DashboardCalculator.isExcludedFromOperativeFlow(t)) continue;
          double amt = -DashboardCalculator.getAmountInPesos(t); // Gastos positivos para el grafico
          if (amt <= 0) continue; // Only expenses
          
          if (t.date.year == tMonth.year && t.date.month == tMonth.month) {
              currDaily[t.date.day] = (currDaily[t.date.day] ?? 0) + amt;
          } else if (t.date.year == prevMonth.year && t.date.month == prevMonth.month) {
              prevDaily[t.date.day] = (prevDaily[t.date.day] ?? 0) + amt;
          }
      }

      List<FlSpot> currSpots = [];
      List<FlSpot> prevSpots = [];
      double maxY = 0;

      // Valid until which day? If it's the current month, up to today. Otherwise up to end of month.
      final now = DateTime.now();
      int limitDayCurr = (tMonth.year == now.year && tMonth.month == now.month) ? now.day : daysInMonth;

      for (int i = 1; i <= daysInMonth; i++) {
          prevAccum += prevDaily[i] ?? 0;
          prevSpots.add(FlSpot(i.toDouble(), prevAccum));
          if (prevAccum > maxY) maxY = prevAccum;

          if (i <= limitDayCurr) {
              currAccum += currDaily[i] ?? 0;
              currSpots.add(FlSpot(i.toDouble(), currAccum));
              if (currAccum > maxY) maxY = currAccum;
          }
      }
      
      if (maxY == 0) maxY = 100;

      return _buildCard("Comparativa de Gasto (Vs. Mes Anterior)", SizedBox(
         height: 200,
         child: LineChart(
             LineChartData(
                 minY: 0,
                 maxY: maxY * 1.1,
                 lineBarsData: [
                     // Prev Month Dashed
                     LineChartBarData(
                         spots: prevSpots,
                         isCurved: true,
                         color: Colors.white.withValues(alpha: 0.2),
                         barWidth: 2,
                         dashArray: [5, 5],
                         dotData: const FlDotData(show: false),
                         belowBarData: BarAreaData(show: false)
                     ),
                     // Current Month Solid
                     LineChartBarData(
                         spots: currSpots,
                         isCurved: true,
                         color: const Color(0xFFF43F5E),
                         barWidth: 3,
                         dotData: const FlDotData(show: false),
                         belowBarData: BarAreaData(
                             show: true, 
                             gradient: const LinearGradient(
                                 colors: [Color(0x66F43F5E), Color(0x00F43F5E)],
                                 begin: Alignment.topCenter,
                                 end: Alignment.bottomCenter,
                             )
                         )
                     )
                 ],
                 titlesData: FlTitlesData(
                     bottomTitles: AxisTitles(
                         sideTitles: SideTitles(
                             showTitles: true,
                             reservedSize: 30,
                             getTitlesWidget: (val, _) {
                                 int day = val.toInt();
                                 if (day % 5 == 0 || day == 1 || day == daysInMonth) {
                                     return Padding(padding: const EdgeInsets.only(top: 8), child: Text(day.toString(), style: const TextStyle(color: Colors.white70, fontSize: 10)));
                                 }
                                 return const Text("");
                             }
                         )
                     ),
                     leftTitles: AxisTitles(
                         sideTitles: SideTitles(
                             showTitles: true,
                             reservedSize: 45,
                             getTitlesWidget: (val, _) => Text(FormatUtils.formatForChart(val), style: const TextStyle(color: Colors.white70, fontSize: 10))
                         )
                     ),
                     topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 ),
                 gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1)),
                 borderData: FlBorderData(show: false),
                 lineTouchData: LineTouchData(
                     touchTooltipData: LineTouchTooltipData(
                         getTooltipColor: (_) => Colors.black87,
                         getTooltipItems: (touchedSpots) {
                             return touchedSpots.map((s) {
                                 final isCurr = s.bar.color == Colors.redAccent;
                                 return LineTooltipItem(
                                    FormatUtils.formatCurrency(s.y, 'UYU'), 
                                    TextStyle(color: isCurr ? Colors.redAccent : Colors.grey, fontWeight: FontWeight.bold)
                                 );
                             }).toList();
                         }
                     )
                 )
             )
         )
      ));
  }

  Widget _buildCard(String title, Widget child) {
     return DashboardHoverCard(
         child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
                 Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 child,
             ]
         )
     );
  }
}
