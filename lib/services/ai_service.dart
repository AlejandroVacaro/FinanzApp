import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIService {
  // CLAVE API OBTENIDA DE VARIABLES DE ENTORNO (Build)
  static const _apiKey = String.fromEnvironment('GOOGLE_API_KEY');
  late final GenerativeModel _model;

  AIService() {
    print("Iniciando AIService con Key: \${_apiKey.isNotEmpty ? 'OK' : 'VACIA'}");
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
  }

  Future<String> sendMessage(String userMessage) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return "Error: Usuario no identificado.";

      // 1. Obtener contexto financiero (últimos 20 gastos)
      final contextData = await _buildFinancialContext(uid);
      
      // 2. Crear el Prompt del Sistema
      final systemPrompt = '''
      Eres un asesor financiero personal, sarcástico pero útil.
      Analiza los siguientes datos recientes del usuario:
      $contextData
      
      Responde a la pregunta del usuario basándote estrictamente en estos datos.
      Si no hay datos, dímelo. Sé breve y directo.
      ''';

      // 3. Enviar a Gemini
      final content = [Content.text('$systemPrompt\n\nUsuario: $userMessage')];
      final response = await _model.generateContent(content);

      return response.text ?? "No pude generar una respuesta.";
    } catch (e) {
      return "Error de conexión con el cerebro: $e";
    }
  }

  Future<String> _buildFinancialContext(String uid) async {
    // Obtiene las últimas 20 transacciones para dar contexto
    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .limit(20)
        .get();

    if (query.docs.isEmpty) return "El usuario no tiene transacciones recientes.";

    return query.docs.map((doc) {
      final data = doc.data();
      return "- ${data['date']}: ${data['categoryName']} \$${data['amount']} (${data['description']})";
    }).join('\n');
  }
}
