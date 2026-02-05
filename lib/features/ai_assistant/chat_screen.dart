import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/ai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: const Text("Asistente Financiero", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isTyping && index == _messages.length) {
                       return const Align(alignment: Alignment.centerLeft, child: _TypingIndicator());
                    }
                    return _ChatBubble(message: _messages[index]);
                  },
              ),
          ),
          _buildInputArea(user?.uid),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text("Pregúntame sobre tus finanzas...", style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          _buildSuggestionChip("¿Cuánto gasté en comida este mes?"),
          _buildSuggestionChip("Analiza mi situación actual"),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ActionChip(
        backgroundColor: const Color(0xFF1F2937),
        label: Text(text, style: const TextStyle(color: Colors.blueAccent)),
        onPressed: () {
          _controller.text = text;
          _sendMessage(FirebaseAuth.instance.currentUser?.uid);
        },
      ),
    );
  }

  Widget _buildInputArea(String? uid) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Escribe tu pregunta...",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _sendMessage(uid),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: _isTyping ? Colors.grey : Colors.blueAccent),
            onPressed: _isTyping ? null : () => _sendMessage(uid),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String? uid) async {
    if (uid == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
      _controller.clear();
    });
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final response = await _aiService.sendMessage(text);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: response, isUser: false));
          _isTyping = false;
        });
        // Scroll again
         WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: "Error: $e", isUser: false));
          _isTyping = false;
        });
      }
    }
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : const Color(0xFF374151),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOut);
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF374151),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
            SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
            const SizedBox(width: 8),
            const Text("Analizando...", style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
