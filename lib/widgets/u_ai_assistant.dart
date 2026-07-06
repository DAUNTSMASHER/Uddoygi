import 'package:flutter/material.dart';
import 'package:uddoygi/services/ai_service.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:google_fonts/google_fonts.dart';

class UAiAssistant extends StatefulWidget {
  const UAiAssistant({super.key});

  @override
  State<UAiAssistant> createState() => _UAiAssistantState();
}

class _UAiAssistantState extends State<UAiAssistant> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _controller.clear();
      _isLoading = true;
    });

    final response = await AIService.chat(text);

    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'content': response});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                Text(
                  'Uddoygi AI Assistant',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E0040),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final isAi = m['role'] == 'ai';
                        return _buildChatBubble(m['content']!, isAi);
                      },
                    ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _handleSend(),
                    decoration: InputDecoration(
                      hintText: 'Ask anything...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _handleSend,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Try asking:\n"How can I improve production?"\n"Summarize today\'s notices"',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isAi) {
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isAi ? const Color(0xFFF3F4F6) : const Color(0xFF7C3AED),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isAi ? 0 : 15),
            bottomRight: Radius.circular(isAi ? 15 : 0),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: isAi ? Colors.black87 : Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
