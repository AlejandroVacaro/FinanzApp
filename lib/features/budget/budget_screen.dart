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
    final incomeCats = categories.where((c) => c.type == CategoryType.income).toList()..sort((a, b) => a.name.compareTo(b.name));
    final expenseCats = categories.where((c) => c.type == CategoryType.expense).toList()..sort((a, b) => a.name.compareTo(b.name));
    final savingsCats = categories.where((c) => c.type == CategoryType.savings).toList()..sort((a, b) => a.name.compareTo(b.name));
    final transferCats = categories.where((c) => c.type == CategoryType.transfer).toList()..sort((a, b) => a.name.compareTo(b.name));

    const double cellWidth = 110.0;
    const double rowHeight = 45.0;
    const double fixedColWidth = 180.0;

    // Calculate Chain
    Map<DateTime, double> initialBalances = {};
    Map<DateTime, double> finalResults = {};
    
    // Logic:
    // Saldo Inicial (Month M) = 
    //    IF Manual Override Exists for M -> Use Manual Value
    //    ELSE -> Saldo Inicial (M-1) + Result (M-1) 
    //    WAIT, User said: "Saldo inicial... va a tomar el saldo inicial más los otros subtotales (ingresos, egresos y movimiento puente), quiero que deje por fuera los ahorros y el margen."
    
    // So Carry Over Formula:
    // NextStart = CurrentStart + Income + Expense + Puente (Transfer)
    // Savings and Margen are NOT included in the carry over to the next month's start.

    double previousCarryOverReference = 0.0; // The value that travels to the next month

    for (int i = 0; i < _months.length; i++) {
        final m = _months[i];
        
        // 1. Determine Start Balance for this month
        double startBalance;
        final manualBalance = budgetProvider.getManualInitialBalance(m);
        
        if (manualBalance != null) {
           startBalance = manualBalance;
           previousCarryOverReference = manualBalance; // Reset the chain from here
        } else {
           if (i == 0) {
              startBalance = 0.0; // Or some global initial defaults? For now 0 if no history
           } else {
              startBalance = previousCarryOverReference;
           }
        }
        
        initialBalances[m] = startBalance;

        // 2. Calculate Flows for this month
        double incomeSum = 0.0;
        double expenseSum = 0.0;
        double transferSum = 0.0;
        double savingsSum = 0.0;
        
        final isPast = m.isBefore(DateTime(DateTime.now().year, DateTime.now().month));
        
        for (var c in incomeCats) {
             incomeSum += isPast ? _getRealSum(txProvider.transactions, c.name, m) : budgetProvider.getAmount(c.id, m);
        }
        for (var c in expenseCats) {
             expenseSum += isPast ? _getRealSum(txProvider.transactions, c.name, m) : budgetProvider.getAmount(c.id, m);
        }
        for (var c in transferCats) {
             transferSum += isPast ? _getRealSum(txProvider.transactions, c.name, m) : budgetProvider.getAmount(c.id, m);
        }
        for (var c in savingsCats) {
             savingsSum += isPast ? _getRealSum(txProvider.transactions, c.name, m) : budgetProvider.getAmount(c.id, m);
        }
        
        final margen = budgetProvider.getMargin(m);

        // 3. Calculate Result
        // Result = (Income + Expense + Transfer + Savings) - Margen
        final result = incomeSum + expenseSum + transferSum + savingsSum - margen; 
        finalResults[m] = result;
        
        // 4. Update Carry Over for Next Month
        // User requested Saldo Final = Initial + Income - Expenses.
        // Usually Carry Over = Previous Final. 
        // If Final excludes Transfer/Savings, then Carry Over should too?
        // User said "Saldo Inicial... quiero que deje por fuera los ahorros y el margen."
        // Bridges (Transfer) were included in my previous logic (Income+Expense+Transfer).
        // If Final Balance Row explicitly excludes Bridge, I should probably align Carry Over if user intends them to match.
        // User: "saldo final toma el saldo incial más los ingresos menos los egresos únicamente"
        
        previousCarryOverReference = startBalance + incomeSum + expenseSum + transferSum; // Keep Transfer in CarryOver for now unless explicitly told to remove from chain. BRIDGE usually implies moving to next month.
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

                                 _buildFixedPlaceholderForSection("INGRESOS", incomeCats.length, incomeCats, Colors.green),
                                 _buildFixedPlaceholderForSection("EGRESOS", expenseCats.length, expenseCats, Colors.red),


                                 _buildFixedPlaceholderForSection("AHORRO", savingsCats.length, savingsCats, Colors.orange),
                                 _buildFixedPlaceholderForSection("MOV. PUENTE", transferCats.length, transferCats, Colors.blue),
                                 
                                 // Margen Row
                                 _buildFixedCell("MARGEN", isBold: true, bg: const Color(0xFF111827), textColor: Colors.lightBlueAccent),
                                 
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

                                   
                                   _buildSectionGrid(incomeCats, _months, budgetProvider, txProvider, cellWidth, Colors.green, Colors.greenAccent),
                                   _buildSectionGrid(expenseCats, _months, budgetProvider, txProvider, cellWidth, Colors.red, Colors.redAccent),
                                   


                                   _buildSectionGrid(savingsCats, _months, budgetProvider, txProvider, cellWidth, Colors.orange, Colors.orangeAccent),
                                   _buildSectionGrid(transferCats, _months, budgetProvider, txProvider, cellWidth, Colors.blue, Colors.blueAccent),
                                   
                                   // Margen Row
                                   Row(
                                      children: _months.map((m) {
                                         final margin = budgetProvider.getMargin(m);
                                         return Container(
                                           width: cellWidth,
                                           height: 45,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF111827),
                                              border: Border(bottom: BorderSide(color: Colors.grey[900]!), right: BorderSide(color: Colors.grey[900]!))
                                            ),
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(right: 12),
                                            child: _BudgetCell(
                                              initialValue: margin,
                                              isReadOnly: false,
                                              onChanged: (val) => budgetProvider.updateMargin(m, val),
                                              textColor: Colors.lightBlueAccent,
                                            ),
                                         );
                                      }).toList(),
                                   ),
                                   
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
           ...cats.map((c) => Container(
              height: 45, width: 180,
              padding: const EdgeInsets.only(left: 24),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[900]!))),
              child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.white70)),
           )), 
           _buildFixedCell(title, isBold: true, bg: color.withOpacity(0.1), textColor: color), // Header/Total at bottom
        ],
      );
  }

  Widget _buildSectionGrid(List<Category> cats, List<DateTime> months, BudgetProvider budgetProvider, TransactionsProvider txProvider, double cellWidth, Color colorHeader, Color colorText) {
      if (cats.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actual Rows First (as requested: "quiero que primero aparezcan los ítems y que debajo de cada tipo aparezca el total")
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
                      textColor: isPast ? Colors.white70 : Colors.white,
                    ),
                  );

                  if (isPast) {
                     final diff = realVal - amount;
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
                        textStyle: const TextStyle(color: Colors.black87),
                        child: cell,
                     );
                  }
                  return cell;
               }).toList(),
             );
          }).toList(),
          
          // Section Totals Row (Now at the bottom)
          Row(
            children: months.map((m) {
               double total = 0.0;
               final isPast = m.isBefore(DateTime(DateTime.now().year, DateTime.now().month));
               
               for (var c in cats) {
                   if (isPast) {
                       total += _getRealSum(txProvider.transactions, c.name, m);
                   } else {
                       total += budgetProvider.getAmount(c.id, m);
                   }
               }
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
        ],
      );
  }


  void _showInitialBalanceDialog(BuildContext context, DateTime month, BudgetProvider provider) {
    final TextEditingController amountController = TextEditingController(
       text: FormatUtils.formatValue(provider.getManualInitialBalance(month) ?? 0).replaceAll('.', '').replaceAll(',', '') // Rough unformat, better to use raw number
    );
     // Better to just start empty or with current raw value?
    amountController.text = (provider.getManualInitialBalance(month) ?? 0).toString();
    
    final TextEditingController noteController = TextEditingController(text: provider.getInitialBalanceNote(month) ?? "");
    
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text("Editar Saldo Inicial", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Este valor sobreescribirá el cálculo automático.", style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Monto",
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Observación (Obligatorio)",
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Restaurar Automático", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
               provider.clearManualInitialBalance(month);
               Navigator.pop(ctx);
            },
          ),
          TextButton(
             child: const Text("Cancelar"),
             onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Guardar"),
            onPressed: () {
               final val = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
               if (noteController.text.trim().isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La observación es obligatoria.")));
                 return;
               }
               provider.updateManualInitialBalance(month, val, noteController.text);
               Navigator.pop(ctx);
            },
          )
        ],
      )
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
