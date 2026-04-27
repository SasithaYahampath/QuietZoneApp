import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  // Read the API key from the .env file safely
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Use Gemini 2.0 Flash – fast and free
  static const String _modelName = 'gemini-2.0-flash';

  // Create the model instance
  static GenerativeModel get _model => GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );

  // The chat session persists for the entire conversation
  static ChatSession? _chatSession;

  /// Start a new chat with the system instruction.
  /// Call this once when the AI screen opens.
  static void initChat({required String context}) {
    // Build the system prompt that tells the AI about current app data
    final systemInstruction = Content.system(
      'You are a helpful sound‑monitoring assistant. '
      'The user is in the "Quiet Zone" app. '
      'Provide concise, friendly answers. '
      'Use the following real‑time data: $context',
    );

    // Create a chat session with the system instruction as the first history item
    _chatSession = _model.startChat(
      history: [systemInstruction],
    );
  }

  /// Sends a user message and returns the AI response.
  /// If the chat session doesn’t exist, it creates one automatically.
  static Future<String> ask({
    required String userMessage,
    required String context,
  }) async {
    // If no chat session exists (first message), initialise it
    if (_chatSession == null) {
      initChat(context: context);
    }

    try {
      final response = await _chatSession!.sendMessage(
        Content.text(userMessage),
      );

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      } else {
        return 'Sorry, I received an empty response from the AI.';
      }
    } catch (e) {
      debugPrint('❌ Gemini API Error: $e');
      return 'Oops, something went wrong. Please try again.';
    }
  }
}
