import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_controller.dart';
import '../services/ai_service.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage(AppController ctrl) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text, true));
      _loading = true;
    });
    _controller.clear();

    // Build context string for the AI
    final context = _buildContext(ctrl);

    try {
      // Pass the user message and app context to the AI service
      final reply = await AIService.ask(
        userMessage: text,
        context: context,
      );
      setState(() {
        _messages.add(_ChatMessage(reply, false));
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
            'Oops, something went wrong. Please try again.', false));
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _buildContext(AppController ctrl) {
    final stats = ctrl.todayStats;
    return '''
Current noise level: ${ctrl.currentDb > 0 ? '${ctrl.currentDb.toStringAsFixed(0)} dB' : 'not monitoring'}
Location: ${ctrl.currentLocationName}
Monitoring: ${ctrl.isMonitoring ? 'active' : 'inactive'}
Today's min: ${stats['min']?.toStringAsFixed(0) ?? 'N/A'} dB
Today's max: ${stats['max']?.toStringAsFixed(0) ?? 'N/A'} dB
Today's avg: ${stats['avg']?.toStringAsFixed(0) ?? 'N/A'} dB
Quiet spots found: ${ctrl.detectedQuietSpots.length} auto-detected
Alert active: ${ctrl.alertActive ? 'yes' : 'no'}
''';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AppController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        children: [
          // Header
          const Row(children: [
            Text('🤖', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('AI Assistant',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          // Quick suggestions
          if (_messages.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Try asking:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _suggestionChip(ctrl, 'Where is the quietest place near me?'),
                  _suggestionChip(ctrl, 'How is the noise today?'),
                  _suggestionChip(ctrl, 'Should I use headphones right now?'),
                ],
              ),
            ),
          // Chat list
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) => _messageBubble(_messages[i]),
            ),
          ),
          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ask something...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onSubmitted: (_) => _sendMessage(ctrl),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _loading ? null : () => _sendMessage(ctrl),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(AppController ctrl, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ActionChip(
        label: Text(
          text,
          style: const TextStyle(fontSize: 13),
        ),
        backgroundColor: Colors.white,
        onPressed: () {
          _controller.text = text;
          _sendMessage(ctrl);
        },
      ),
    );
  }

  Widget _messageBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 20),
          ),
          boxShadow: msg.isUser
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                  )
                ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : const Color(0xFF1E293B),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, this.isUser);
}
