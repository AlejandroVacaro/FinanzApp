import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/budget_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../models/category.dart';
import '../../models/transaction_model.dart';
import '../../models/transaction_model.dart' as tx_model;
import 'package:intl/date_symbol_data_local.dart'; // Local setup
import '../../config/app_theme.dart';
import '../../utils/format_utils.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  // Dynamic dates now used in initState
  List<DateTime> _months = [];
  
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  bool _isLoading = true; // Loading State

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es'); // Init Spanish Locale
    _months = [];
    
    final now = DateTime.now();
    // Start from Jan 1st of previous year to show history
    DateTime current = DateTime(now.year - 1, 1);
    
    // End 12 months from NOW
    final endDate = DateTime(now.year, now.month + 12);
    
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      _months.add(current);
      current = DateTime(current.year, current.month + 1);
    }
    
    // Simulate Data Loading and Scroll to Current Month on Init
    Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
            setState(() => _isLoading = false);
            WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToCurrentMonth();
            });
        }
    });
    
    _headerScrollController.addListener(() {
       if (_bodyScrollController.hasClients && _headerScrollController.hasClients) {
         if (_bodyScrollController.offset != _headerScrollController.offset) {
            _bodyScrollController.jumpTo(_headerScrollController.offset);
         }
       }
    });
    
    _bodyScrollController.addListener(() {
       if (_headerScrollController.hasClients && _bodyScrollController.hasClients) {
         if (_headerScrollController.offset != _bodyScrollController.offset) {
            _headerScrollController.jumpTo(_bodyScrollController.offset);
         }
       }
    });
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _scrollToCurrentMonth() {
      final now = DateTime.now();
      // Find index ignoring day/time, strictly year/month matching
      int index = _months.indexWhere((m) => m.year == now.year && m.month == now.month);
      if (index != -1) {
         final offset = index * 110.0; // cellWidth
         if (_headerScrollController.hasClients) {
             _headerScrollController.animateTo(offset, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
         }
      }
  }

  // --- CALCULATION HELPERS ---

  double _getRealSum(List<Transaction> txs, String catName, DateTime month) {
    // Filter txs by Category Name (Case Insensitive) and Month
    final monthTxs = txs.where((t) => 
      t.date.year == month.year && 
      t.date.month == month.month &&
      t.category.toLowerCase() == catName.toLowerCase()
    );
    return monthTxs.fold(0.0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final txProvider = Provider.of<TransactionsProvider>(context);

    // Group Categories
    final categories = configProvider.categories;
    final incomeCats = categories.where((c) => c.type == CategoryType.income).toList();
    final expenseCats = categories.where((c) => c.type == CategoryType.expense).toList();
    final savingsCats = categories.where((c) => c.type == CategoryType.savings).toList();
    final transferCats = categories.where((c) => c.type == CategoryType.transfer).toList();

    const double cellWidth = 110.0;
    const double rowHeight = 45.0;
    const double fixedColWidth = 180.0;

    // Calculate Chain
    Map<DateTime, double> initialBalances = {};
    Map<DateTime, double> finalResults = {};
    double currentBalance = 0.0; // Starting Balance

    for (var m in _months) {
        initialBalances[m] = currentBalance;
        double monthFlow = 0.0;
        
        // Sum all budget items for this month
        // Flow = Income + Expense (negative) + etc.
        // Assuming Expense is stored as negative in BudgetProvider? 
        // If BudgetProvider stores positive for expense, we need to negate.
        // Let's check BudgetProvider... initialized with Negatives in defaults. 
        // So simple Sum is correct.
        for (var c in categories) {
           monthFlow += budgetProvider.getAmount(c.id, m);
        }
        
        currentBalance += monthFlow;
        finalResults[m] = currentBalance;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark, 
      appBar: AppBar(
        title: Text("Presupuesto", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
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
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : Column(
                children: [
                  // 1. HEADER (Months)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0), // Spacing from rounded corner
                    child: SizedBox(
                      height: 50,
                      child: Row(
                        children: [
                          Container(
                              width: fixedColWidth, 
                              color: const Color(0xFF1F2937),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                   const Text("CONCEPTO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                   IconButton(
                                      icon: const Icon(Icons.today, color: Colors.blueAccent, size: 20),
                                      tooltip: "Ir al mes actual",
                                      onPressed: _scrollToCurrentMonth
                                   )
                                ],
                              )
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: _headerScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: _months.length,
                              itemBuilder: (_, i) => Container(
                                width: cellWidth,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    border: Border(right: BorderSide(color: Colors.grey[800]!)), 
                                    color: const Color(0xFF1F2937)
                                ),
                                child: Text(
                                    DateFormat('MMMM yy', 'es').format(_months[i]).capitalize(), 
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 2. BODY (Scrollable Rows)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT COLUMN
                          Container(
                            width: fixedColWidth,
                            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[800]!))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 // Saldo Inicial
                                 _buildFixedCell("SALDO INICIAL", isBold: true, bg: const Color(0xFF111827), textColor: Colors.white70),
                                 _buildFixedPlaceholderForSection("INGRESOS", incomeCats.length, incomeCats, Colors.green),
                                 _buildFixedPlaceholderForSection("EGRESOS", expenseCats.length, expenseCats, Colors.red),
                                 _buildFixedPlaceholderForSection("AHORRO", savingsCats.length, savingsCats, Colors.orange),
                                 _buildFixedPlaceholderForSection("MOV. PUENTE", transferCats.length, transferCats, Colors.blue),
                                 _buildFixedCell("RESULTADO", isBold: true, bg: const Color(0xFF111827), textColor: Colors.white70),
                              ],
                            ),
                          ),
                          
                          // RIGHT GRID
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _bodyScrollController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   // Saldo Inicial Row
                                   Row(children: _months.map((m) => _buildDisplayCell(initialBalances[m]!, cellWidth, bg: const Color(0xFF111827), textColor: Colors.white70)).toList()),
                                   
                                   _buildSectionGrid(incomeCats, _months, budgetProvider, txProvider, cellWidth, Colors.green, Colors.greenAccent),
                                   _buildSectionGrid(expenseCats, _months, budgetProvider, txProvider, cellWidth, Colors.red, Colors.redAccent),
                                   _buildSectionGrid(savingsCats, _months, budgetProvider, txProvider, cellWidth, Colors.orange, Colors.orangeAccent),
                                   _buildSectionGrid(transferCats, _months, budgetProvider, txProvider, cellWidth, Colors.blue, Colors.blueAccent),
                                   
                                   // Resultado Row
                                   Row(children: _months.map((m) {
                                       final res = finalResults[m]!;
                                       final color = res >= 0 ? Colors.greenAccent : Colors.redAccent;
                                       return _buildDisplayCell(res, cellWidth, bg: const Color(0xFF111827), textColor: color, isBold: true);
                                   }).toList()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // --- UI BUILDERS ---
  
  Widget _buildDisplayCell(double value, double width, {Color? bg, Color? textColor, bool isBold = false}) {
      return Container(
         width: width,
         height: 45,
         alignment: Alignment.centerRight,
         padding: const EdgeInsets.only(right: 12),
         decoration: BoxDecoration(
           color: bg ?? const Color(0xFF111827),
           border: Border(bottom: BorderSide(color: Colors.grey[900]!), right: BorderSide(color: Colors.grey[900]!))
         ),
         child: Text(_formatCurrency(value), style: TextStyle(
             fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
             color: textColor ?? Colors.white,
             fontSize: 13
         )),
      );
  }

  Widget _buildFixedCell(String text, {bool isBold = false, Color? bg, Color? textColor}) {
      return Container(
         height: 45,
         width: 180,
         padding: const EdgeInsets.only(left: 16),
         alignment: Alignment.centerLeft,
         decoration: BoxDecoration(
           color: bg ?? const Color(0xFF111827),
           border: Border(bottom: BorderSide(color: Colors.grey[900]!))
         ),
         child: Text(text, style: GoogleFonts.inter(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13, color: textColor ?? Colors.white)),
      );
  }
  
  Widget _buildFixedPlaceholderForSection(String title, int count, List<Category> cats, Color color) {
      if (count == 0) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           _buildFixedCell(title, isBold: true, bg: color.withOpacity(0.1), textColor: color), // Header
           ...cats.map((c) => Container(
              height: 45, width: 180,
              padding: const EdgeInsets.only(left: 24),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[900]!))),
              child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.white70)),
           )), 
        ],
      );
  }

  Widget _buildSectionGrid(List<Category> cats, List<DateTime> months, BudgetProvider budgetProvider, TransactionsProvider txProvider, double cellWidth, Color colorHeader, Color colorText) {
      if (cats.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Totals Row
          Row(
            children: months.map((m) {
               double total = 0.0;
               for (var c in cats) total += budgetProvider.getAmount(c.id, m);
               return Container(
                 width: cellWidth,
                 height: 45,
                 alignment: Alignment.centerRight,
                 padding: const EdgeInsets.only(right: 12),
                 color: colorHeader.withOpacity(0.1),
                 child: Text(_formatCurrency(total), style: TextStyle(fontWeight: FontWeight.bold, color: colorText, fontSize: 13)),
               );
            }).toList(),
          ),
          
          // Actual Rows
          ...cats.map((cat) {
             return Row(
               children: months.map((m) {
                  final amount = budgetProvider.getAmount(cat.id, m);
                  final isPast = m.isBefore(DateTime(DateTime.now().year, DateTime.now().month));
                  
                  final realVal = _getRealSum(txProvider.transactions, cat.name, m);
                  
                  // For past months, we show the Real Value. For current/future, the Budgeted Amount.
                  final displayValue = isPast ? realVal : amount;
                  
                  Widget cell = Container(
                    width: cellWidth,
                    height: 45,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[900]!), right: BorderSide(color: Colors.grey[900]!))),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 12),
                    child: _BudgetCell(
                      initialValue: displayValue,
                      isReadOnly: isPast,
                      onChanged: (val) => budgetProvider.updateAmount(cat.id, m, val),
                      textColor: isPast ? Colors.white70 : Colors.white, // Visual cue?
                    ),
                  );

                  if (isPast) {
                     final diff = realVal - amount;
                     // Logic:
                     // Income (Positive): Real > Budget (Positive Diff) = Good (Green)
                     // Expense (Negative): Real > Budget (Positive Diff -> -800 > -1000) = Good (Green)
                     // So simply: Diff > 0 is Good. Diff < 0 is Bad.
                     
                     final color = diff > 0 ? const Color(0xFF00C853) : (diff < 0 ? const Color(0xFFFF5252) : Colors.black);
                     
                     return Tooltip(
                        richMessage: TextSpan(
                          children: [
                            TextSpan(text: "Presupuestado: ${_formatCurrency(amount)}\n", style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: "Diferencia: ${_formatCurrency(diff)}", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                          ]
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
                        textStyle: const TextStyle(color: Colors.black87), // Tooltip default text color check
                        child: cell,
                     );
                  }
                  return cell;
               }).toList(),
             );
          }).toList(),
        ],
      );
  }
}

class _BudgetCell extends StatefulWidget {
  final double initialValue;
  final bool isReadOnly;
  final Function(double) onChanged;
  final Color? textColor;

  const _BudgetCell({required this.initialValue, required this.isReadOnly, required this.onChanged, this.textColor});

  @override
  State<_BudgetCell> createState() => _BudgetCellState();
}

class _BudgetCellState extends State<_BudgetCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.initialValue));
  }
  
  @override
  void didUpdateWidget(_BudgetCell oldWidget) {
     super.didUpdateWidget(oldWidget);
     if (oldWidget.initialValue != widget.initialValue) {
        _controller.text = _format(widget.initialValue);
     }
  }

  String _format(double val) {
    if (val == 0) return "";
    return FormatUtils.formatValue(val);
  }

  double _parse(String text) {
    if (text.isEmpty) return 0.0;
    final clean = text.replaceAll('.', '').replaceAll(',', '.'); 
    return double.tryParse(clean) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isReadOnly) {
       return Text(
         _format(widget.initialValue),
         style: TextStyle(color: Colors.grey[600], fontSize: 13), // Darker Grey for ReadOnly 
       );
    }

    return TextFormField(
      controller: _controller,
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 13, color: widget.textColor ?? Colors.white),
      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
      onFieldSubmitted: (value) => widget.onChanged(_parse(value)),
      cursorColor: Colors.white,
    );
  }
}

String _formatCurrency(double val) {
  // Use generic UYU formatting (symbol + correct separators)
  // Budget usually implies local currency unless specified, defaulting to UYU format which is $U 1.234,56
  return FormatUtils.formatCurrency(val, 'UYU');
}
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
