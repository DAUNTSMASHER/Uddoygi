import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:uddoygi/services/ai_service.dart';
import 'package:uddoygi/models/chat_message.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';

class UAiAssistant extends StatefulWidget {
  const UAiAssistant({super.key});

  @override
  State<UAiAssistant> createState() => _UAiAssistantState();
}

class _UAiAssistantState extends State<UAiAssistant> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Requirement: Conversation History
  final List<genai.Content> _history = [];
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(content: text, isAi: false));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    // Requirement: Use conversation history in AIService
    final response = await AIService.chat(text, history: _history);

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(content: response, isAi: true));
        // Update history for next turn
        _history.add(genai.Content.text(text));
        _history.add(genai.Content.model([genai.TextPart(response)]));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildChatList(),
          ),
          if (_isLoading) _buildTypingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Uddoygi AI Assistant', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              Text('Powered by Gemini 3.1 Flash', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.green[600], fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final m = _messages[index];
        return _ChatBubble(content: m.content, isAi: m.isAi)
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.forum_outlined, size: 64, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          Text('Welcome to Uddoygi AI', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('Ask me about HR policies, attendance, marketing insights, or factory workflows.', textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 32),
          _buildQuickAction('How to improve sales this month?'),
          _buildQuickAction('Analyze my company database metrics'),
          _buildQuickAction('Summarize today\'s attendance'),
          _buildQuickAction('How to optimize factory load?'),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String text) {
    return GestureDetector(
      onTap: () { _controller.text = text; _handleSend(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Text(text, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
      ),
    ).animate().scale(delay: 500.ms);
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
                const SizedBox(width: 12),
                Text('Uddoygi AI is typing...', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _handleSend(),
              style: GoogleFonts.dmSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                hintStyle: GoogleFonts.dmSans(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Requirement: Purple Gradient Send Button
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFC026D3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ).animate().scale(delay: 200.ms),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String content;
  final bool isAi;
  const _ChatBubble({required this.content, required this.isAi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
        child: Column(
          crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(16),
              // Requirement: Rounded chat bubbles
              decoration: BoxDecoration(
                color: isAi ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isAi ? 4 : 20),
                  bottomRight: Radius.circular(isAi ? 20 : 4),
                ),
              ),
              child: Stack(
                children: [
                  isAi
                      ? Padding(
                          padding: const EdgeInsets.only(right: 24),
                          child: MarkdownBody(
                            data: content,
                            styleSheet: MarkdownStyleSheet(
                              p: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF1E293B), height: 1.5),
                              strong: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                              listBullet: GoogleFonts.dmSans(color: const Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      : Text(content, style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
                  if (isAi)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(isAi ? 'AI' : 'You', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}
