import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';

import '../../providers/transactions_provider.dart';
import '../../providers/config_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/notifications.dart';
import '../../widgets/ui_components.dart';
import '../../config/app_theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isLoading = false;
  String _searchQuery = ""; // Renamed from _searchText for consistency
  String _filterSource = "Todos";

  // --- LÓGICA DE IMPORTACIÓN ---

  Future<void> _pickCSV() async {
    final config = Provider.of<ConfigProvider>(context, listen: false);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: true, 
        withData: true,
      );

      if (result != null) {
        setState(() => _isLoading = true);
        
        List<Transaction> totalNewTransactions = [];
        int filesProcessed = 0;
        int errors = 0;

        for (var file in result.files) {
          try {
            Uint8List? fileBytes = file.bytes;
            if (fileBytes == null) continue;

            // 1. Decodificación
            String csvContent;
            try {
              csvContent = utf8.decode(fileBytes);
            } catch (e) {
              csvContent = latin1.decode(fileBytes);
            }

            // 2. Parseo CSV
            List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent, eol: '\n');
            if (rows.isEmpty) continue;

            // 3. Detectar Formato
            int headerIndex = -1;
            bool isCreditCard = false;
            String sourceAccount = "Desconocido";

            for (int i = 0; i < rows.length && i < 50; i++) {
              String rowStr = rows[i].join(" ").toLowerCase();
              
              if (rowStr.contains("pesos") && (rowStr.contains("dólares") || rowStr.contains("dolares"))) {
                headerIndex = i;
                isCreditCard = true;
                sourceAccount = "Visa Platinum";
                break;
              }
              if (rowStr.contains("referencia") && rowStr.contains("concepto")) {
                headerIndex = i;
                isCreditCard = false;
                sourceAccount = "Caja Ahorro \$";
                break;
              }
            }

            if (headerIndex == -1) {
              debugPrint("Formato no reconocido para archivo: ${file.name}");
              errors++;
              continue;
            }

            // 4. Parsear Datos
            List<Transaction> newTransactions = [];
            List<dynamic> headers = rows[headerIndex].map((e) => e.toString().toLowerCase()).toList();

            int idxDesc = -1;
            int idxDebit = -1;
            int idxCredit = -1;
            int idxPesos = -1;
            int idxDolares = -1;

            if (isCreditCard) {
                idxDesc = _findIndex(headers, ["descripción", "descripcion"]);
                idxPesos = _findIndex(headers, ["pesos"]);
                idxDolares = _findIndex(headers, ["dólares", "dolares"]);
            } else {
                idxDesc = _findIndex(headers, ["concepto"]);
                idxDebit = _findIndex(headers, ["débito", "debito"]);
                idxCredit = _findIndex(headers, ["crédito", "credito"]);
            }

            for (int i = headerIndex + 1; i < rows.length; i++) {
              var row = rows[i];
              if (row.length < 3) continue;

              try {
                String dateStr = row[0].toString();
                DateTime? date;
                try {
                   date = DateFormat("dd/MM/yyyy").parse(dateStr);
                } catch (_) { continue; }

                String description = idxDesc != -1 && idxDesc < row.length ? row[idxDesc].toString() : "Sin descripción";
                double amount = 0.0;
                String currency = "UYU";

                if (isCreditCard) {
                    double p = _parseMonto(row, idxPesos);
                    double d = _parseMonto(row, idxDolares);
                    
                    if (d != 0) {
                        amount = d; currency = "USD";
                    } else {
                        amount = p; currency = "UYU";
                    }
                    amount = amount * -1; // Invert logic for Visa
                } else {
                    double deb = _parseMonto(row, idxDebit);
                    double cred = _parseMonto(row, idxCredit);
                    amount = deb + cred;
                }

                if (amount == 0) continue;

                // === LÓGICA DE CATEGORIZACIÓN AUTOMÁTICA ===
                String? catId = config.getCategoryIdForDescription(description);
                String finalCategory = "General";
                if (catId != null) { 
                   finalCategory = config.getCategoryById(catId)?.name ?? "General"; 
                }

                newTransactions.add(Transaction(
                    date: date,
                    description: description,
                    category: finalCategory,
                    amount: amount,
                    currency: currency,
                    sourceAccount: sourceAccount,
                    accountNumber: "N/A",
                    balance: 0.0,
                ));

              } catch (e) {
                debugPrint("Error parsing row $i in ${file.name}: $e");
              }
            }
            
            if (newTransactions.isNotEmpty) {
              totalNewTransactions.addAll(newTransactions);
              filesProcessed++;
            }

          } catch (e) {
            debugPrint("Error procesando archivo ${file.name}: $e");
            errors++;
          }
        } // Fin for

        if (totalNewTransactions.isNotEmpty) {
            Provider.of<TransactionsProvider>(context, listen: false).addTransactions(totalNewTransactions);
            ModernFeedback.showSuccess(context, "¡Éxito! $filesProcessed archivos procesados. +${totalNewTransactions.length} movimientos.");
        } else if (errors > 0) {
            ModernFeedback.showError(context, "Error", "No se pudieron procesar los archivos seleccionados.");
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ModernFeedback.showError(context, "Error General", e.toString());
    }
  }

  // Helpers
  int _findIndex(List<dynamic> headers, List<String> keys) {
      for (int i = 0; i < headers.length; i++) {
          for (var k in keys) {
              if (headers[i].toString().contains(k)) return i;
          }
      }
      return -1;
  }

  double _parseMonto(List<dynamic> row, int index) {
      if (index == -1 || index >= row.length) return 0.0;
      String val = row[index].toString().trim();
      if (val.isEmpty) return 0.0;
      
      // Smart Parsing:
      if (val.contains('.') && val.contains(',')) {
        if (val.lastIndexOf(',') > val.lastIndexOf('.')) {
             val = val.replaceAll('.', '').replaceAll(',', '.');
        } else {
             val = val.replaceAll(',', '');
        }
      } else if (val.contains(',')) {
          val = val.replaceAll('.', '').replaceAll(',', '.');
      }
      return double.tryParse(val) ?? 0.0;
  }

  void _showCategoryEditDialog(BuildContext context, Transaction tx) {
      String selectedCategory = tx.category;
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      final categories = tx.amount < 0 ? configProvider.expenseCategories : configProvider.incomeCategories;
      
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1F2937),
              title: const Text("Editar Rubro", style: TextStyle(color: Colors.white)),
              content: StatefulBuilder(
                  builder: (ctx, setState) {
                      return DropdownButton<String>(
                          value: categories.contains(selectedCategory) ? selectedCategory : null,
                          dropdownColor: const Color(0xFF374151),
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          hint: const Text("Seleccionar Rubro", style: TextStyle(color: Colors.white70)),
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                              if (val != null) setState(() => selectedCategory = val);
                          }
                      );
                  }
              ),
              actions: [
                  TextButton(
                      child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                      onPressed: () => Navigator.pop(ctx)
                  ),
                  TextButton(
                      child: const Text("Guardar", style: TextStyle(color: Colors.blueAccent)),
                      onPressed: () {
                          Provider.of<TransactionsProvider>(context, listen: false).updateTransactionCategory(tx, selectedCategory);
                          Navigator.pop(ctx);
                      }
                  )
              ],
          )
      );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text("Mis Movimientos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickCSV,
              icon: const Icon(Icons.upload_file, color: Colors.white, size: 20),
              label: const Text("Importar CSV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
          ),
        ],
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
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : Consumer<TransactionsProvider>(
                    builder: (context, provider, _) {
                        if (provider.transactions.isEmpty) {
                            return const Center(child: Text("No hay movimientos. Importa un archivo CSV."));
                        }
                        return _buildTable(provider.transactions);
                    },
                ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Transaction> allTxs) {
      // 1. Filtrado
      List<Transaction> filteredTxs = allTxs;
      
      if (_searchQuery.isNotEmpty) {
        filteredTxs = allTxs.where((t) {
          return t.description.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                 t.category.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
        
        // 2. Ordenamiento: Cuando Busco = Más VIEJOS arriba (Ascendente)
        filteredTxs.sort((a, b) => a.date.compareTo(b.date));
      } else {
         // Default (No Search) = Más NUEVOS arriba (Descendente)
         filteredTxs.sort((a, b) => b.date.compareTo(a.date));
      }

      // Apply source filter after search/sort
      filteredTxs = filteredTxs.where((tx) {
         return _filterSource == "Todos" || tx.sourceAccount == _filterSource;
      }).toList();

      final sources = ["Todos", ...allTxs.map((e) => e.sourceAccount).toSet().toList()];

      return Column(
          children: [
              // Barra de Buscador y Filtros
              Container(
                // color: const Color(0xFF1F2937), // Not strictly needed if transparent
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Buscador
                    Expanded(
                      flex: 3,
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Buscar...",
                          hintStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.search, color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF374151),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Filtro de Origen
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: sources.contains(_filterSource) ? _filterSource : "Todos",
                            isExpanded: true,
                            dropdownColor: const Color(0xFF374151),
                            icon: const Icon(Icons.filter_list, color: Colors.white70),
                            style: const TextStyle(color: Colors.white),
                            items: sources.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _filterSource = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Header Tabla
              Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1F2937),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell("FECHA", flex: 2),
                        _buildHeaderCell("DESCRIPCIÓN", flex: 5), // Adjusted flex
                        _buildHeaderCell("RUBRO", flex: 2), // Adjusted flex
                        _buildHeaderCell("CUENTA", flex: 3),
                        _buildHeaderCell("IMPORTE", flex: 2, alignment: Alignment.centerRight),
                      ],
                    ),
                  ),
              
              // Lista de Movimientos
              Expanded(
                  child: ListView.separated(
                      reverse: !(_searchQuery.isNotEmpty), 
                      itemCount: filteredTxs.length,
                      separatorBuilder: (_,__) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, i) {
                          final tx = filteredTxs[i];
                          final amountColor = tx.amount >= 0 ? AppColors.income : AppColors.expense;
                          
                          return _HoverRow(
                              child: Row(
                                  children: [
                                      // Date
                                      Expanded(
                                        flex: 2, 
                                        child: Text(
                                          DateFormat("dd/MM/yy").format(tx.date), 
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                                        )
                                      ),
                                      // Description
                                      Expanded(
                                        flex: 5, 
                                        child: Tooltip(
                                          message: tx.description,
                                          child: Text(
                                            tx.description, 
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, color: Colors.white),
                                          ),
                                        )
                                      ),
                                      // Category (Editable)
                                      Expanded(flex: 2, child: 
                                        InkWell(
                                          onTap: () => _showCategoryEditDialog(context, tx),
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      tx.category, 
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white), 
                                                      textAlign: TextAlign.center,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.edit, size: 10, color: Colors.grey)
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      ),
                                      // Account
                                      Expanded(
                                        flex: 3, 
                                        child: Text(
                                          tx.sourceAccount, 
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      ),
                                      // Amount
                                      Expanded(
                                        flex: 2, 
                                        child: Container(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                                "${tx.currency == 'USD' ? 'U\$S' : '\$U'} ${tx.amount.toStringAsFixed(2)}", 
                                                style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                        )
                                      ),
                                  ],
                              ),
                          );
                      },
                  ),
              ),
          ],
      );
  }

  Widget _buildHeaderCell(String text, {int flex = 1, Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  final Widget child;
  const _HoverRow({required this.child});

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100), // Faster
        color: _isHovering ? const Color(0xFF374151) : const Color(0xFF1F2937),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Less vertical padding
        child: widget.child,
      ),
    );
  }
}
