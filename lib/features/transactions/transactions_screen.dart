import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

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

   // --- LÓGIC DE IMPORTACIÓN MEJORADA ---

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
            bool isCreditCard = false;
            bool isBankAccount = false;
            String sourceAccount = "Desconocido";
            String fileCurrency = "UYU"; // Default

            // Análisis de primeras líneas para detectar tipo
            for (int i = 0; i < rows.length && i < 20; i++) {
              String rowStr = rows[i].join(" ").toLowerCase();
              
              if (rowStr.contains("visa soy santander") || rowStr.contains("tarjeta de crédito") || (rowStr.contains("importe original") && rowStr.contains("dólares"))) {
                isCreditCard = true;
                sourceAccount = "Visa Platinum";
                break;
              }
              if (rowStr.contains("ca personal") || (rowStr.contains("referencia") && rowStr.contains("concepto") && rowStr.contains("saldos"))) {
                isBankAccount = true;
                if (rowStr.contains("moneda usd")) fileCurrency = "USD";
                if (rowStr.contains("moneda uyu")) fileCurrency = "UYU";
                sourceAccount = "Caja Ahorro $fileCurrency";
                break;
              }
            }

            if (!isCreditCard && !isBankAccount) {
                 debugPrint("Formato no reconocido para archivo: ${file.name}");
                 errors++;
                 continue;
            }

            // 4. Parsear Datos
            List<Transaction> newTransactions = [];
            
            // Indices para CAJA DE AHORRO
            // "los valores que siguen enseguida a la derecha de la descripción son los débitos, los que siguen son los créditos"
            int dataStartIndex = -1;

            if (isBankAccount) {
                // Buscar encabezados
                for (int i = 0; i < rows.length; i++) {
                    var row = rows[i].map((e) => e.toString().toLowerCase()).toList();
                    if (row.contains("fecha") && row.contains("referencia")) {
                        dataStartIndex = i + 1;
                        break;
                    }
                }
            } else if (isCreditCard) {
                // Buscar encabezados de TC
                for (int i = 0; i < rows.length; i++) {
                     var row = rows[i].map((e) => e.toString().toLowerCase()).toList();
                     if (row.contains("fecha") && row.contains("número de tarjeta")) {
                         dataStartIndex = i + 1;
                         break;
                     }
                }
            }

            if (dataStartIndex == -1) {
                 errors++; 
                 continue;
            }

            for (int i = dataStartIndex; i < rows.length; i++) {
              var row = rows[i];
              // Validaciones básicas
              if (row.length < 3) continue;

              try {
                // FECHA
                String dateStr = row[0].toString();
                DateTime? date;
                try {
                   date = DateFormat("dd/MM/yyyy").parse(dateStr);
                } catch (_) { continue; }

                String description = "";
                double amount = 0.0;
                String currency = "UYU";
                
                // Mapeo detallado de montos
                double valOriginal = 0.0;
                double valPesos = 0.0;
                double valDolares = 0.0;
                
                if (isBankAccount) {
                    // --- ESTRATEGIA HÍBRIDA: HEADERS + CONTENIDO ---
                    int idxDesc = -1;
                    int idxDebit = -1;
                    int idxCredit = -1;
                    
                    // 1. Intentar por Headers primero
                    if (dataStartIndex > 0) {
                        List<String> headers = rows[dataStartIndex - 1].map((e) => e.toString().toLowerCase()).toList();
                        idxDesc = headers.indexWhere((h) => h.contains("concepto") || h.contains("desc") || h.contains("detalle") || h.contains("referencia"));
                        idxDebit = headers.indexWhere((h) => h.contains("débito") || h.contains("debito") || h.contains("retiro"));
                        idxCredit = headers.indexWhere((h) => h.contains("crédito") || h.contains("credito") || h.contains("depósito") || h.contains("deposito"));
                    }

                    // 2. Si falla, usar HEURÍSTICA DE CONTENIDO (Escáner de Tipos)
                    if (idxDesc == -1 || (idxDebit == -1 && idxCredit == -1)) {
                        // Analizar la fila actual (y siguientes si es necesario) para determinar tipos
                        // Buscamos: 
                        // - Columna Numérica Negativa/Positiva mezclada o dos columnas numéricas -> Montos
                        // - Columna de Texto largo -> Descripción
                        
                        int bestTxtCol = -1;
                        int maxTxtLen = 0;
                        List<int> numericCols = [];

                        for (int c = 0; c < row.length; c++) {
                            String val = row[c].toString();
                            // Chequear si es numero
                            if (RegExp(r'^-?[0-9]+([.,][0-9]+)?$').hasMatch(val.trim().replaceAll('.', '').replaceAll(',', '.'))) {
                                numericCols.add(c);
                            } else if (val.length > 5 && !val.contains(RegExp(r'\d{2}/\d{2}/\d{4}'))) {
                                // Candidato a Texto (y no es fecha)
                                if (val.length > maxTxtLen) {
                                  maxTxtLen = val.length;
                                  bestTxtCol = c;
                                }
                            }
                        }
                        
                        if (idxDesc == -1) idxDesc = bestTxtCol;
                        
                        // Asignar columnas numéricas
                        if (numericCols.isNotEmpty) {
                           // Si hay 2 columnas numéricas y no tenemos definidos deb/cred
                           if (numericCols.length >= 2 && idxDebit == -1 && idxCredit == -1) {
                               idxDebit = numericCols[0]; // Asumimos orden standard: Debito, Credito
                               idxCredit = numericCols[1];
                           } else if (numericCols.length == 1 && idxDebit == -1 && idxCredit == -1) {
                               // Probablemente col única de importe con signo
                               idxDebit = numericCols[0]; // Usaremos esta como "Amount" genérico
                           }
                        }
                    }

                    // Fallback final
                    if (idxDesc == -1) idxDesc = 3; 
                    if (idxDebit == -1) idxDebit = 4; // Si es columna única, debito chequea primero
                    
                    // --- EXTRACCIÓN ---
                    if (row.length > idxDesc) description = row[idxDesc].toString();
                    
                    double debito = 0.0;
                    double credito = 0.0;
                    
                    if (idxDebit != -1 && row.length > idxDebit) debito = _parseMontoRaw(row[idxDebit]);
                    if (idxCredit != -1 && row.length > idxCredit) credito = _parseMontoRaw(row[idxCredit]);
                    
                    // Lógica especial para Columna Única de Importe
                    if (idxDebit != -1 && idxCredit == -1) {
                        amount = debito; // Asumimos que viene con signo (-100 o +100)
                         // Si el banco trae débitos positivos, necesitamos heurística extra, pero standard es con signo si es col única.
                         // Si BROU: trae Debito y Credito separados positivos.
                    } else {
                        // Lógica Debito/Credito Separados (Positivos ambos, columna define signo)
                        if (debito != 0) {
                            amount = -debito.abs(); // Forzamos negativo
                        } else if (credito != 0) {
                            amount = credito.abs(); // Forzamos positivo
                        }
                    }
                    
                    currency = fileCurrency;
                    
                    if (currency == "UYU") {
                        valPesos = amount;
                        valDolares = 0; 
                    } else {
                        valDolares = amount;
                        valPesos = 0;
                    }
                    valOriginal = amount;

                } else if (isCreditCard) {
                    // TC tiene columnas específicas
                    // Headers: Fecha, Nro Tarjeta, Autorización, Descripción, Importe Original, Pesos, Dólares
                    int idxDesc = 3;
                    int idxOrig = 4;
                    int idxPesos = 5;
                    int idxDolar = 6;
                    
                    if (row.length > idxDesc) description = row[idxDesc].toString();
                    
                    if (row.length > idxOrig) valOriginal = _parseMontoRaw(row[idxOrig]);
                    if (row.length > idxPesos) valPesos = _parseMontoRaw(row[idxPesos]);
                    if (row.length > idxDolar) valDolares = _parseMontoRaw(row[idxDolar]);

                    // Lógica de Negación: En el resumen, compras son positivas. Queremos gastos negativos.
                    valOriginal = valOriginal * -1;
                    valPesos = valPesos * -1;
                    valDolares = valDolares * -1;
                    
                    // Lógica de visualización principal
                    if (valDolares.abs() > 0) {
                        amount = valDolares;
                        currency = "USD";
                    } else if (valPesos.abs() > 0) {
                        amount = valPesos;
                        currency = "UYU";
                    } else {
                         // Fallback si ambos son 0 (ej: items informativos)
                         continue;
                    }
                }

                if (amount == 0 && valOriginal == 0) continue;

                // === LÓGICA DE CATEGORIZACIÓN AUTOMÁTICA ===
                // === LÓGICA DE CATEGORIZACIÓN AUTOMÁTICA ===
                String? catId = config.getCategoryIdForDescription(description);
                String finalCategory = "Categoría no asignada";
                if (catId != null) { 
                   finalCategory = config.getCategoryById(catId)?.name ?? "Categoría no asignada"; 
                }

                newTransactions.add(Transaction(
                    id: const Uuid().v4(), // FORCE UNIQUE ID
                    date: date,
                    description: description,
                    category: finalCategory,
                    amount: amount,
                    currency: currency,
                    sourceAccount: sourceAccount,
                    accountNumber: "N/A",
                    balance: 0.0,
                    originalAmount: valOriginal,
                    amountUYU: valPesos,
                    amountUSD: valDolares,
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

        // Ensure Spinner has been seen at least briefly (UX)
        await Future.delayed(const Duration(milliseconds: 500));

        if (totalNewTransactions.isNotEmpty) {
            // Await the batch write fully
            await Provider.of<TransactionsProvider>(context, listen: false).addTransactions(totalNewTransactions);
            
            if (context.mounted) {
               // Success message ONLY after write is done
               ModernFeedback.showSuccess(context, "¡Carga Completa! $filesProcessed archivos procesados.");
            }
        } else if (errors > 0) {
            if (context.mounted) ModernFeedback.showError(context, "Error", "No se pudieron procesar los archivos seleccionados.");
        }

        if (context.mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (context.mounted) {
         setState(() => _isLoading = false);
         ModernFeedback.showError(context, "Error General", e.toString());
      }
    }
  }

  // Helper Simplificado
  double _parseMontoRaw(dynamic value) {
      if (value == null) return 0.0;
      String val = value.toString().trim();
      if (val.isEmpty) return 0.0;
      
      // Manejo de formatos numéricos (1.000,00 vs 1000.00)
      // Asumimos formato español/latino: 1.234,56
      // Si hay comas, reemplazar puntos (miles) por nada y comas por puntos (decimal)
      if (val.contains(',')) {
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
                        _buildHeaderCell("DESCRIPCIÓN", flex: 4), // Reduced from 5
                        _buildHeaderCell("RUBRO", flex: 3, alignment: Alignment.center), // Increased from 2 to 3
                        _buildHeaderCell("CUENTA", flex: 3),
                        _buildHeaderCell("IMPORTE", flex: 2, alignment: Alignment.centerRight),
                      ],
                    ),
                  ),
              
              // Lista de Movimientos
              Expanded(
                  child: ListView.separated(
                      reverse: false, // Standard Top-Down view
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
                                        flex: 4, // Match Header
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
                                      Expanded(flex: 3, child: // Match Header
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
                                      // Amount - Right Aligned
                                      Expanded(
                                        flex: 2, 
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Tooltip(
                                              message: tx.currency == 'USD' 
                                                  ? "En Pesos: \$U ${tx.amountUYU.toStringAsFixed(2)}"
                                                  : "En Dólares: U\$S ${tx.amountUSD.toStringAsFixed(2)}",
                                              child: Text(
                                                  "${tx.currency == 'USD' ? 'U\$S' : '\$U'} ${tx.amount.toStringAsFixed(2)}", 
                                                  style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 13),
                                                  textAlign: TextAlign.right,
                                              ),
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
          textAlign: alignment == Alignment.center ? TextAlign.center : (alignment == Alignment.centerRight ? TextAlign.right : TextAlign.left),
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
