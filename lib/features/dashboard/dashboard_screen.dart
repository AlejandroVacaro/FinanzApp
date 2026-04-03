import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/transactions_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/budget_provider.dart';
import '../../models/transaction_model.dart';
import '../../config/app_theme.dart';

// Modulares 
import 'widgets/dashboard_metrics_grid.dart';
import 'widgets/dashboard_composition_charts.dart';
import 'widgets/dashboard_trend_charts.dart';
import 'widgets/dashboard_insights_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Time Filters State (Global for Dashboard)
  DateTime? selectedMonth; // Null means "All Time" (Histórico)
  int selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
      final txProvider = Provider.of<TransactionsProvider>(context);
      final configProvider = Provider.of<ConfigProvider>(context);
      final budgetProvider = Provider.of<BudgetProvider>(context);
      
      final allTxs = txProvider.transactions;
      
      // Filter Logic for Current Period
      List<Transaction> periodTxs = allTxs;
      if (selectedMonth != null) {
          periodTxs = allTxs.where((t) => 
               t.date.year == selectedMonth!.year && 
               t.date.month == selectedMonth!.month
          ).toList();
      }

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
              if (txProvider.error != null)
                Container(
                  color: Colors.redAccent,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    txProvider.error!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.backgroundDark, Color(0xFF131B2D)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: CustomScrollView(
                      slivers: [
                          // Filter Bar
                          SliverToBoxAdapter(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _buildTimeFilterBar(),
                              ),
                          ),
                          
                          // SECCIÓN 1: KPIs Rápidos
                          SliverPadding(
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             sliver: SliverToBoxAdapter(
                                 child: DashboardMetricsGrid(
                                     allTxs: allTxs,
                                     periodTxs: periodTxs,
                                     selectedMonth: selectedMonth,
                                     budgetProvider: budgetProvider,
                                 ),
                             ),
                          ),

                          // Gap
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),

                          // SECCIÓN 2: Gráficos de Composición
                          SliverPadding(
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             sliver: SliverToBoxAdapter(
                                 child: DashboardCompositionCharts(
                                     periodTxs: periodTxs,
                                     configProvider: configProvider,
                                 ),
                             ),
                          ),

                          // Gap
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),

                          // SECCIÓN 3: Gráficos de Tendencia
                          SliverPadding(
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             sliver: SliverToBoxAdapter(
                                 child: DashboardTrendCharts(
                                     allTxs: allTxs,
                                     selectedMonth: selectedMonth,
                                 )
                             ),
                          ),

                          // Gap
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),

                          // SECCIÓN 4: Insights y Rankings
                          SliverPadding(
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             sliver: SliverToBoxAdapter(
                                 child: DashboardInsightsPanel(
                                     periodTxs: periodTxs,
                                 )
                             ),
                          ),

                          // Bottom Padding
                          const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ]
                  ),
                ),
              ),
            ],
          ),
      );
  }

  Widget _buildTimeFilterBar() {
      return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
             color: AppColors.backgroundLight, 
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: AppColors.panelBorder)
          ),
          child: Row(
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
                              const DropdownMenuItem(value: null, child: Text("Histórico global")),
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
                  ],
                  const Spacer(),
                  if (selectedMonth != null)
                      TextButton.icon(
                          onPressed: () => setState(() => selectedMonth = null), 
                          icon: const Icon(Icons.restore, color: Colors.blueAccent, size: 18), 
                          label: const Text("Limpiar", style: TextStyle(color: Colors.blueAccent))
                      )
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
