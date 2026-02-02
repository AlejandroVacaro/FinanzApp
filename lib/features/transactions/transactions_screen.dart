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
import '../../models/category.dart';
import '../../utils/notifications.dart';

import '../../config/app_theme.dart';
import '../../utils/format_utils.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _isLoading = false;
  String _searchQuery = ""; 
  String _filterSource = "Todos";
  String _filterCategory = "Todos"; // Filtro de Rubro

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
            bool isCreditCard = false;
            bool isBankAccount = false;
            String sourceAccount = "Desconocido";
            String fileCurrency = "UYU"; // Default
            DateTime? cutoffDate; // FECHA DE CORTE

            // Análisis de primeras líneas para detectar tipo y METADATA
            for (int i = 0; i < rows.length && i < 20; i++) {
              String rowStr = rows[i].join(" ").toLowerCase();
              
              if (rowStr.contains("visa soy santander") || rowStr.contains("tarjeta de crédito") || (rowStr.contains("importe original") && rowStr.contains("dólares"))) {
                isCreditCard = true;
                sourceAccount = "Visa Platinum";
                // No break yet, might find cutoff date later or in same pass
              }
              if (rowStr.contains("ca personal") || (rowStr.contains("referencia") && rowStr.contains("concepto") && rowStr.contains("saldos"))) {
                isBankAccount = true;
                if (rowStr.contains("moneda usd")) fileCurrency = "USD";
                if (rowStr.contains("moneda uyu")) fileCurrency = "UYU";
                sourceAccount = "Caja Ahorro $fileCurrency";
              }
              
              // Buscar Fecha de Corte (Solo relevante para TC, pero buscamos igual)
              if (isCreditCard && rowStr.contains("fecha de corte")) {
                   // Asumimos formato vertical u horizontal cercano
                   // Buscamos en la fila actual el índice de "Fecha de corte"
                   List<String> rowRaw = rows[i].map((e) => e.toString().toLowerCase()).toList();
                   int idxCutoff = rowRaw.indexWhere((cell) => cell.contains("fecha de corte"));
                   
                   if (idxCutoff != -1) {
                       // Check next row at same index (Vertical Key-Value)
                       if (i + 1 < rows.length) {
                           String potentialDate = rows[i+1][idxCutoff].toString();
                           try {
                               cutoffDate = DateFormat("dd/MM/yyyy").parse(potentialDate);
                               debugPrint("Fecha de corte detectada: $cutoffDate");
                           } catch (e) {
                               debugPrint("Error parseando fecha de corte: $e");
                           }
                       }
                   }
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
                
                // OVERRIDE DATE IF CUTOFF EXISTS AND IS TC
                if (isCreditCard && cutoffDate != null) {
                    date = cutoffDate;
                }

                String description = "";
                double amount = 0.0;
                String currency = "UYU";
                
                // Mapeo detallado de montos
                double valOriginal = 0.0;
                double valPesos = 0.0;
                double valDolares = 0.0;
                
                if (isBankAccount) {
                    // --- ESTRATEGIA: ANCLAJE RELATIVO (Anchor Strategy) ---
                    // El usuario indica que la estructura es: [..., Debito, Credito, Saldo]
                    // El problema es que al buscar "Débito" vs "Crédito" por headers a veces falla o los montos vacíos confunden al escáner de tipos.
                    // SOLUCIÓN: Buscar "Saldos" (Header) o usar posición, y definir Deb/Cred RELATIVOS a él.
                    
                    int idxBalance = -1;
                    int idxDebit = -1;
                    int idxCredit = -1;
                    int idxDesc = -1;

                    // 1. Buscar Header "Saldos" o "Saldo" o "Balance" para encontrar columna pivote
                    if (dataStartIndex > 0) {
                        List<String> headers = rows[dataStartIndex - 1].map((e) => e.toString().toLowerCase()).toList();
                        idxBalance = headers.indexWhere((h) => h.contains("saldo"));
                        
                        if (idxDesc == -1) idxDesc = headers.indexWhere((h) => h.contains("concepto") || h.contains("descripcion") || h.contains("referencia"));
                    }

                    // 2. Si falló header, usar heurística de "Última columna numérica" en las primeras filas de datos
                    if (idxBalance == -1) {
                         // Escanear filas de datos para encontrar la estructura común
                         // Asumimos que "Saldo" es la última columna numérica relevante a la derecha.
                         for (int k = dataStartIndex; k < rows.length && k < dataStartIndex + 5; k++) {
                             var sampleRow = rows[k];
                             List<int> nums = [];
                             for(int c=0; c<sampleRow.length; c++) {
                                 if (RegExp(r'^-?[0-9]+([.,][0-9]+)?$').hasMatch(sampleRow[c].toString().trim().replaceAll('.', '').replaceAll(',', '.'))) {
                                     nums.add(c);
                                 }
                             }
                             if (nums.isNotEmpty) {
                                 idxBalance = nums.last; // Asumimos saldo al final
                                 break; // Encontrado un candidato
                             }
                         }
                    }

                    // 3. Definir Debit y Credit relativos a Balance
                    // Estructura BROU/Standard: [Debit] [Credit] [Balance]
                    if (idxBalance != -1 && idxBalance >= 2) {
                        idxCredit = idxBalance - 1;
                        idxDebit = idxBalance - 2;
                    } else if (idxBalance != -1 && idxBalance == 1) {
                         // Caso raro: [Amount, Balance]? -> Asumimos Columna única
                         idxDebit = 0;
                    } else {
                         // Fallback absoluto si no hallamos nada (Estructura fija según screenshot usuario)
                         // Screenshot muestra: ..., Descripción (Col 2), Débito (Col 3), Crédito (Col 4), Saldos (Col 5) - (0-indexed? No, screenshot muestra headers)
                         // Excel screenshot: Col 4 (Saldos), Col 5 (Debit?? No, wait)
                         // Re-reading user request: "la primera columna de número son los débitos, la segunda los créditos, la tercera el saldo"
                         // Entonces order: Debit, Credit, Balance.
                         // Esto coincide con idxCredit = idxBalance -1, idxDebit = idxBalance - 2.
                         
                         // Si falla detección dinámica, usemos índices fijos basados en la observación del usuario si tenemos suficientes columnas
                         if (row.length >= 6) { 
                             // Asumiendo Concepto en col 2 o 3.
                             // User says: "la primera columna de número son los débitos"
                             // Buscamos primera columna numérica available? NO, eso fallaba antes (salary bug).
                             // We MUST rely on fixed positions relative to end or specific indices if headers fail.
                             idxDebit = row.length - 3; // Antepenúltima
                             idxCredit = row.length - 2; // Penúltima
                             // This is risky. Let's stick to strict relative if Balance found, or search headers.
                         }
                    }

                    // 4. Extracción
                    // Descripción
                    if (idxDesc == -1) {
                        // Buscar la columna de texto más larga a la izquierda de los números
                         int limitCol = (idxDebit != -1) ? idxDebit : row.length;
                         int maxLen = 0;
                         for(int c=0; c < limitCol; c++) {
                             String txt = row[c].toString();
                             if (txt.length > maxLen && !txt.contains(RegExp(r'\d'))) { // Texto puro preferible
                                 maxLen = txt.length;
                                 idxDesc = c;
                             }
                         }
                         if (idxDesc == -1) idxDesc = 2; // Default
                    }
                    if (row.length > idxDesc) description = row[idxDesc].toString();

                    double debito = 0.0;
                    double credito = 0.0;

                    if (idxDebit != -1 && row.length > idxDebit) debito = _parseMontoRaw(row[idxDebit]);
                    if (idxCredit != -1 && row.length > idxCredit) credito = _parseMontoRaw(row[idxCredit]);

                    // Lógica BROU / Bancaria: Débito y Crédito separados y positivos
                    if (debito != 0 && credito == 0) {
                         amount = -debito.abs(); // Es gasto
                    } else if (credito != 0 && debito == 0) {
                         amount = credito.abs(); // Es ingreso
                    } else if (debito != 0 && credito != 0) {
                         // Raro en una misma tx bancaria, pero priorizamos neto
                         amount = credito.abs() - debito.abs();
                    } else {
                        // Ambos 0?
                        continue;
                    }

                    currency = fileCurrency;
                    if (currency == "UYU") {
                         valPesos = amount;
                    } else {
                         valDolares = amount;
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
                String? catId = config.getCategoryIdForDescription(description);
                String finalCategory = "Categoría no asignada";
                if (catId != null) { 
                   finalCategory = config.getCategoryById(catId)?.name ?? "Categoría no asignada"; 
                }

                newTransactions.add(Transaction(
                    id: const Uuid().v4(), // FORCE UNIQUE ID
                    date: date, // Will be cutoffDate if set
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
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      final txProvider = Provider.of<TransactionsProvider>(context, listen: false);

      String selectedCategory = tx.category;
      String description = tx.description;
      bool saveRule = false;
      
      final categories = configProvider.categories.map((e) => e.name).toList()..sort();
      
      showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, setState) {
                  return AlertDialog(
                      backgroundColor: const Color(0xFF1F2937),
                      title: const Text("Editar Movimiento", style: TextStyle(color: Colors.white)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Editable Description
                          TextField(
                            controller: TextEditingController(text: description),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: "Descripción",
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                            ),
                            onChanged: (val) => description = val,
                          ),
                          const SizedBox(height: 16),
                          
                          // 2. Category Dropdown
                          DropdownButtonFormField<String>(
                              value: categories.contains(selectedCategory) ? selectedCategory : null,
                              dropdownColor: const Color(0xFF374151),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "Rubro",
                                labelStyle: TextStyle(color: Colors.white70),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                              ),
                              isExpanded: true,
                              hint: const Text("Seleccionar Rubro", style: TextStyle(color: Colors.white70)),
                              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) {
                                  if (val != null) setState(() => selectedCategory = val);
                              }
                          ),
                          const SizedBox(height: 24),

                          // 3. Save Rule Checkbox
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Guardar asignación automática", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            subtitle: const Text("Se usará esta descripción para asignar futuros movimientos.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                            value: saveRule, 
                            onChanged: (val) => setState(() => saveRule = val ?? false),
                            activeColor: Colors.blueAccent,
                            checkColor: Colors.white,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                      actions: [
                          TextButton(
                              child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                              onPressed: () => Navigator.pop(ctx)
                          ),
                          TextButton(
                              child: const Text("Guardar", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                  Navigator.pop(ctx); // Close Dialog first

                                  // 1. Update Transaction (Category & Description)
                                  // Warning: description update for transaction wasn't explicitly asked but implied by "texto editable".
                                  // However, TransactionsProvider doesn't have updateTransactionDescription?
                                  // Let's check provider usage in the original code. It uses updateTransactionCategory.
                                  // I might need to update the provider or just pass the description if the provider supports full update? 
                                  // Looking at provider code: `await _firestoreService.updateTransaction(_uid!, updatedTx);` 
                                  // It uses copyWith and saves. So I can update description too manually here.
                                  
                                  final newTx = tx.copyWith(category: selectedCategory, description: description);
                                  // Transaction provider currently has `updateTransactionCategory`. 
                                  // Let's assume WE ONLY update category via that method or I need to update the method?
                                  // Provide code showed `updateTransactionCategory(Transaction tx, String newCategory)`.
                                  // I should probably manually call firestore update or modify the provider to support generic update.
                                  // ACTUALLY, for safety, I will stick to what the provider offers or do a quick update? 
                                  // The user wants "texto del movimiento editable". 
                                  // I'll assume they want the transaction description updated too.
                                  // Since I can't easily change the provider method signature without breaking other things (maybe), 
                                  // I'll just check if I can use the same method but passing a modified TX? 
                                  // `updateTransactionCategory` takes `Transaction tx` and `String newCategory`.
                                  // It does `tx.copyWith(category: newCategory)`. It ignores my description change if I pass old tx.
                                  
                                  // FIX: I should use a generic update or call firestore directly? 
                                  // Better: Expand the provider method or add a new one? 
                                  // Or just modify the provider method to take the whole updated transaction?
                                  // Wait, `updateTransactionCategory` implementation:
                                  /*
                                  Future<void> updateTransactionCategory(Transaction tx, String newCategory) async {
                                      if (_uid == null) return;
                                      final updatedTx = tx.copyWith(category: newCategory);
                                      await _firestoreService.updateTransaction(_uid!, updatedTx);
                                  }
                                  */
                                  // It overwrites my description change. 
                                  // I will create a new method in this file to handle the update properly or just modify the provider in next step?
                                  // I'll modify the provider in the next step to `updateTransaction` generic.
                                  // For now, I will invoke a hypothetical `updateTransaction` or just `updateTransactionCategory` and fix it in provider.
                                  // Actually, I can just use the firestore service directly? No, keep architecture.
                                  
                                  // Let's assumme I will rename `updateTransactionCategory` to `updateTransaction` in Provider.
                                  await txProvider.updateTransaction(newTx); 

                                  // 2. Save Rule Logic
                                  Category? catObj = configProvider.categories.cast<Category?>().firstWhere(
                                      (c) => c?.name == selectedCategory, orElse: () => null
                                  );
                                  
                                  if (saveRule && catObj != null) {
                                      configProvider.addRule(description, catObj.id);
                                      
                                      if (context.mounted) {
                                          _showRetroactiveDialog(context, description, selectedCategory);
                                      }
                                  }
                              }
                          )
                      ],
                  );
              }
          )
      );
  }

  void _showRetroactiveDialog(BuildContext context, String keyword, String categoryName) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text("Aplicar a existentes", style: TextStyle(color: Colors.white)),
          content: Text(
            "¿Deseas aplicar esta asignación a los movimientos ya registrados que contengan '$keyword'?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text("No", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(ctx),
            ),
            TextButton(
              child: const Text("Sí, aplicar", style: TextStyle(color: Colors.blueAccent)),
              onPressed: () async {
                Navigator.pop(ctx);
                final count = await Provider.of<TransactionsProvider>(context, listen: false)
                    .applyRuleToExistingTransactions(keyword, categoryName);
                if (context.mounted) {
                   ModernFeedback.showSuccess(context, "Se actualizaron $count movimientos.");
                }
              },
            ),
          ],
        ),
      );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text("Movimientos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              margin: const EdgeInsets.symmetric(horizontal: 24), // Added external margin
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : Consumer<TransactionsProvider>(
                    builder: (context, provider, _) {
                        if (_isLoading || provider.isLoading) {
                           return const Center(child: CircularProgressIndicator());
                        }
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
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      
      // 1. Filtrado
      List<Transaction> filteredTxs = allTxs;
      
      if (_searchQuery.isNotEmpty) {
        filteredTxs = allTxs.where((t) {
          return t.description.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
        
        filteredTxs.sort((a, b) => a.date.compareTo(b.date));
      } else {
         filteredTxs.sort((a, b) => b.date.compareTo(a.date));
      }

      // Apply source filter
      filteredTxs = filteredTxs.where((tx) {
         return _filterSource == "Todos" || tx.sourceAccount == _filterSource;
      }).toList();
      
      // Apply category filter
      filteredTxs = filteredTxs.where((tx) {
         return _filterCategory == "Todos" || tx.category == _filterCategory;
      }).toList();

      final sources = ["Todos", ...allTxs.map((e) => e.sourceAccount).toSet().toList()];
      final categories = ["Todos", ...configProvider.categories.map((c) => c.name).toSet().toList()..sort()];

      return Column(
          children: [
              // Barra de Buscador y Filtros
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Buscador
                    Expanded(
                      flex: 4, 
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
                    const SizedBox(width: 12),
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
                            icon: const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18), // Icon hint
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: sources.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _filterSource = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Filtro de Rubro (Categoría)
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
                            value: categories.contains(_filterCategory) ? _filterCategory : "Todos",
                            isExpanded: true,
                            dropdownColor: const Color(0xFF374151),
                            icon: const Icon(Icons.category, color: Colors.white70, size: 18), // Icon hint
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _filterCategory = val);
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
                                                  ? "En Pesos: ${FormatUtils.formatCurrency(tx.amountUYU, 'UYU')}"
                                                  : "En Dólares: ${FormatUtils.formatCurrency(tx.amountUSD, 'USD')}",
                                              child: Text(
                                                  FormatUtils.formatCurrency(tx.amount, tx.currency), 
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
