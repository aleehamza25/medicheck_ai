import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:translator/translator.dart';

class VoiceMedicalAssistant extends StatefulWidget {
  const VoiceMedicalAssistant({super.key});

  @override
  _VoiceMedicalAssistantState createState() => _VoiceMedicalAssistantState();
}

class _VoiceMedicalAssistantState extends State<VoiceMedicalAssistant> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  String _assistantResponse = '';
  bool _isResponding = false;
  String _selectedLanguage = 'English';
  final List<Map<String, String>> _conversation = [];
  final ScrollController _scrollController = ScrollController();
  final translator = GoogleTranslator();

  // Medical context memory
  Map<String, String> _patientContext = {
    'age': '',
    'gender': '',
    'mainComplaint': '',
    'currentMedications': '',
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    // Set Urdu voice parameters
    await _flutterTts.setVoice({
      'name': 'ur-PK-Standard-A',
      'locale': 'ur-PK'
    });
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _selectedLanguage == 'English' ? 'en_US' : 'ur_PK',
    );
    setState(() {
      _isListening = true;
      _lastWords = '';
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
    if (_lastWords.isNotEmpty) {
      _processUserInput(_lastWords);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  Future<void> _processUserInput(String input) async {
    if (input.isEmpty) return;

    setState(() {
      _conversation.add({'role': 'user', 'message': input});
      _isResponding = true;
      _assistantResponse = '';
    });

    _scrollToBottom();

    try {
      // Translate to English if needed for API processing
      final translatedInput = _selectedLanguage == 'English'
          ? input
          : (await translator.translate(input, from: 'ur', to: 'en')).text;

      // Get medical response (with context)
      final response = await _getMedicalResponse(translatedInput);

      // Update patient context if relevant information was provided
      _updatePatientContext(translatedInput, response);

      // Translate back to user's selected language
      final translatedResponse = _selectedLanguage == 'English'
          ? response
          : (await translator.translate(response, from: 'en', to: 'ur')).text;

      setState(() {
        _assistantResponse = translatedResponse;
        _conversation.add({'role': 'assistant', 'message': translatedResponse});
        _isResponding = false;
      });

      await _speak(translatedResponse);
    } catch (e) {
      setState(() {
        _assistantResponse = 'Error processing request. Please try again.';
        _isResponding = false;
      });
    }

    _scrollToBottom();
  }

  void _updatePatientContext(String input, String response) {
    final lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('i am') || lowerInput.contains('my age is')) {
      final ageMatch = RegExp(r'\d+').firstMatch(input);
      if (ageMatch != null) {
        _patientContext['age'] = ageMatch.group(0)!;
      }
    }
    
    if (lowerInput.contains('male') || lowerInput.contains('female')) {
      _patientContext['gender'] = lowerInput.contains('male') ? 'male' : 'female';
    }
    
    if (lowerInput.contains('pain') || 
        lowerInput.contains('hurt') || 
        lowerInput.contains('symptom') ||
        lowerInput.contains('feel')) {
      _patientContext['mainComplaint'] = input;
    }
    
    if (lowerInput.contains('take') || lowerInput.contains('medication')) {
      _patientContext['currentMedications'] = input;
    }
  }

  Future<String> _getMedicalResponse(String input) async {
    const url = 'https://api.groq.com/openai/v1/chat/completions';
    final apiKey = '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';

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final contextString = _buildContextString();

    final messages = [
      {
        'role': 'system',
        'content': '''
You are a professional medical assistant. Follow these rules strictly:
1. Respond only to medical queries - decline politely for non-medical questions
2. For serious symptoms, always recommend seeing a doctor immediately
3. When suggesting medications, include: generic name, dosage, frequency
4. Keep responses concise (2-3 sentences max)
5. Consider patient context: $contextString
'''
      },
      {'role': 'user', 'content': input}
    ];

    final body = jsonEncode({
      'messages': messages,
      'model': 'meta-llama/llama-4-maverick-17b-128e-instruct',
      'temperature': 0.7,
      'max_tokens': 150,
      'top_p': 1,
      'stream': false,
      'stop': null,
    });

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to get response: ${response.statusCode}');
    }
  }

  String _buildContextString() {
    final contextParts = [];
    if (_patientContext['age']!.isNotEmpty) {
      contextParts.add('Age: ${_patientContext['age']}');
    }
    if (_patientContext['gender']!.isNotEmpty) {
      contextParts.add('Gender: ${_patientContext['gender']}');
    }
    if (_patientContext['mainComplaint']!.isNotEmpty) {
      contextParts.add('Main complaint: ${_patientContext['mainComplaint']}');
    }
    if (_patientContext['currentMedications']!.isNotEmpty) {
      contextParts.add('Current medications: ${_patientContext['currentMedications']}');
    }
    
    return contextParts.isEmpty ? 'No context yet' : contextParts.join(', ');
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage(
        _selectedLanguage == 'English' ? 'en-US' : 'ur-PK');
    await _flutterTts.speak(text);
  }

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

  void _toggleLanguage() {
    setState(() {
      _selectedLanguage = _selectedLanguage == 'English' ? 'Urdu' : 'English';
    });
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF03045E);
    final Color secondaryColor = const Color(0xFF1976D2);
    final Color accentColor = const Color(0xFFE3F2FD);
    final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentLight = const Color(0xFF90E0EF);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medical Voice Assistant',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                _selectedLanguage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.translate,
              color: Colors.white,
            ),
            onPressed: _toggleLanguage,
            tooltip: 'Toggle Language',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [accentLight.withOpacity(0.3), primaryLight.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
        child: Column(
          children: [
            // Language indicator
            Container(
              padding: const EdgeInsets.all(12),
              color: secondaryColor.withOpacity(0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.record_voice_over, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    _isListening
                        ? 'Listening... ($_selectedLanguage)'
                        : 'Tap mic to speak ($_selectedLanguage)',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Conversation history
            Expanded(
              child: _conversation.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.healing,
                            size: 80,
                            color: primaryColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Describe your symptoms\nin English or Urdu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: primaryColor.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'I can help with:\n- Medication advice\n- Symptom analysis\n- First aid guidance',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _conversation.length + (_isResponding ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < _conversation.length) {
                          final message = _conversation[index];
                          return _buildMessageBubble(
                              message['role']!, message['message']!);
                        } else {
                          return _buildTypingIndicator();
                        }
                      },
                    ),
            ),
            
            // Current listening status
            if (_lastWords.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastWords,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Responding indicator
            if (_isResponding)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.healing, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Analyzing your symptoms...',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Disclaimer at bottom
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[200],
              child: const Text(
                'Note: This is for informational purposes only. Always consult a doctor for medical advice.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AvatarGlow(
        animate: _isListening,
        glowColor: primaryColor,
        duration: const Duration(milliseconds: 2000),
        repeat: true,
        child: FloatingActionButton(
          onPressed: _isListening ? _stopListening : _startListening,
          backgroundColor: _isListening ? Colors.red : primaryColor,
          child: Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMessageBubble(String role, String message) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser 
                    ? const Color(0xFF1976D2)
                    : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft:
                      Radius.circular(isUser ? 20 : 0),
                  bottomRight:
                      Radius.circular(isUser ? 0 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(const Duration(milliseconds: 0)),
                const SizedBox(width: 4),
                _buildTypingDot(const Duration(milliseconds: 300)),
                const SizedBox(width: 4),
                _buildTypingDot(const Duration(milliseconds: 600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(Duration delay) {
    return AnimatedOpacity(
      opacity: _isResponding ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFF0D47A1),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}