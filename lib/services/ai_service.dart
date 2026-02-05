import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'firestore_service.dart';
import '../utils/format_utils.dart';
import 'package:intl/intl.dart';

class AIService {
  final FirestoreService _firestoreService = FirestoreService();
  late final GenerativeModel _model;

  AIService() {
    _model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-1.5-flash',
    );
  }

  /// Sends a message to the AI, injecting the user's recent financial data as context.
  Future<String> sendMessage(String userMessage, String uid) async {
    try {
      // 1. Build Financial Context
      final contextData = await _buildFinancialContext(uid);
      
      // 2. Create System Prompt
      final systemPrompt = '''
Eres un asesor financiero experto, sarcástico pero muy útil. Tu objetivo es ayudar al usuario a entender sus finanzas basándote en sus datos reales.
Actúa como un analista que no tiene miedo de decir la verdad si el usuario está gastando demasiado.
Responde de manera concisa y directa.
Usa formato Markdown para resaltar números importantes.

AQUI ESTAN LOS DATOS FINANCIEROS ACTUALES DEL USUARIO:
$contextData

PREGUNTA DEL USUARIO:
"$userMessage"

Responde a la pregunta basándote estrictamente en los datos proporcionados arriba. Si no hay datos suficientes para responder, dilo.
''';

      // 3. Generate Content
      final content = [Content.text(systemPrompt)];
      final response = await _model.generateContent(content);

      return response.text ?? "Lo siento, no pude generar una respuesta. Intenta de nuevo.";
    } catch (e) {
      print("Error generating AI response: $e");
      return "Hubo un error al procesar tu consulta. Asegúrate de tener conexión a internet.";
    }
  }

  Future<String> _buildFinancialContext(String uid) async {
    // A. Recent Transactions
    final transactions = await _firestoreService.getRecentTransactions(uid, limit: 30);
    
    // B. Budget Data
    final budgetData = await _firestoreService.getBudget(uid);
    
    // Format Transactions
    final txBuffer = StringBuffer();
    txBuffer.writeln("--- ÚLTIMAS 30 TRANSACCIONES ---");
    if (transactions.isEmpty) {
      txBuffer.writeln("(No hay transacciones recientes)");
    } else {
      for (var tx in transactions) {
        final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);
        final amountStr = FormatUtils.formatCurrency(tx.amount, tx.currency);
        txBuffer.writeln("- $dateStr | ${tx.description} | $amountStr | Categoría: ${tx.category}");
      }
    }

    // Format Budget (Simplified)
    final budgetBuffer = StringBuffer();
    budgetBuffer.writeln("\n--- PRESUPUESTO ACTUAL ---");
    if (budgetData == null || budgetData.isEmpty) {
      budgetBuffer.writeln("(No hay presupuesto definido)");
    } else {
      // Traverse categories in budget to show current month context if possible, 
      // but for simplicity, let's just show top-level summary if available or raw structure
      // Actually, passing the raw JSON map might be confusing for the AI, let's try to extract key numbers if possible.
      // Since budget structure is complex (Map<CategoryId, Map<Month, Amount>>), let's summarize Key Categories for CURRENT month.
      
      final now = DateTime.now();
      final currentMonthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";
      
      budgetBuffer.writeln("Mes Actual ($currentMonthKey):");
      
      // We need category names to make sense of IDs. 
      // Fetching categories might be expensive here, but let's try to trust the AI can interpret or just skip deep budget analysis for now 
      // and rely on transactions which have category names.
      // Ideally, we should fetch categories too.
      
      final categories = await _firestoreService.getCategories(uid).first; 
      // Note: .first on stream might be risky if empty, but usually fine for one-shot fetch. 
      // Better to use a Future-based fetch in FirestoreService if needed, but getCategories returns a Stream.
      // Let's use the stream as a future for now.
      
      for (var cat in categories) {
        if (budgetData.containsKey(cat.id)) {
           final catBudget = budgetData[cat.id] as Map<String, dynamic>;
           if (catBudget.containsKey(currentMonthKey)) {
             final amount = catBudget[currentMonthKey];
             budgetBuffer.writeln("- ${cat.name}: \$${amount is num ? amount.toStringAsFixed(2) : amount}");
           }
        }
      }
    }

    return "${txBuffer.toString()}\n${budgetBuffer.toString()}";
  }
}
