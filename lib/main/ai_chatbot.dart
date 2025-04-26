import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MedicalAIChatScreen extends StatefulWidget {
  @override
  _MedicalAIChatScreenState createState() => _MedicalAIChatScreenState();
}

class _MedicalAIChatScreenState extends State<MedicalAIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  double _bottomPadding = 0;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Groq API configuration
  final String _apiKey = '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';
  final String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // Medical keywords to identify health-related queries
  final List<String> _medicalKeywords = [
    'health', 'medical', 'doctor', 'symptom', 'pain', 'illness', 'disease',
    'medicine', 'treatment', 'diagnosis', 'hospital', 'clinic', 'pharmacy',
    'prescription', 'fever', 'headache', 'cough', 'cold', 'allergy', 'blood',
    'pressure', 'sugar', 'diabetes', 'heart', 'lung', 'liver', 'kidney',
    'stomach', 'digestion', 'mental', 'anxiety', 'depression', 'vaccine',
    'infection', 'virus', 'bacteria', 'injury', 'wound', 'fracture', 'covid',
    'pandemic', 'exercise', 'diet', 'nutrition', 'vitamin', 'sleep', 'weight',
    'obesity', 'cancer', 'tumor', 'asthma', 'arthritis', 'migraine', 'stroke',
    'attack', 'cholesterol', 'thyroid', 'pregnancy', 'childbirth', 'baby',
    'pediatric', 'elderly', 'aging', 'dementia', 'alzheimer', 'autism', 'adhd',
    'therapy', 'rehabilitation', 'physiotherapy', 'surgery', 'operation',
    'anesthesia', 'x-ray', 'scan', 'test', 'result', 'report', 'checkup'
  ];

  @override
  void initState() {
    super.initState();
    _messages.add({
      'text': "Hello! I'm Dr. HealthAI, your virtual medical assistant. I can help with health-related questions. Please describe your symptoms or health concern.",
      'isUser': false,
      'timestamp': DateTime.now(),
    });
    _loadChatHistory();
    _setupKeyboardListener();
  }

  void _setupKeyboardListener() {
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _bottomPadding = MediaQuery.of(context).viewInsets.bottom);
        _scrollToBottom();
      } else {
        setState(() => _bottomPadding = 0);
      }
    });
  }

  Future<void> _loadChatHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('medical_chats')
          .doc(user.uid)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(snapshot.docs.reversed.map((doc) {
            final data = doc.data();
            return {
              'text': data['text'],
              'isUser': data['isUser'],
              'timestamp': data['timestamp'].toDate(),
            };
          }).toList());
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }

  Future<void> _saveMessage(String text, bool isUser) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('medical_chats')
          .doc(user.uid)
          .collection('messages')
          .add({
        'text': text,
        'isUser': isUser,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  bool _isMedicalQuery(String query) {
    final lowerQuery = query.toLowerCase();
    return _medicalKeywords.any((keyword) => lowerQuery.contains(keyword));
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    await _saveMessage(message, true);

    setState(() {
      _messages.add({
        'text': message,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      if (!_isMedicalQuery(message)) {
        final nonMedicalResponse = "I specialize in medical questions only. Please ask about symptoms, conditions, or treatments. For other inquiries, consult the appropriate professional.";
        await _saveMessage(nonMedicalResponse, false);
        
        setState(() {
          _messages.add({
            'text': nonMedicalResponse,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
        });
        return;
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "messages": [
            {
              "role": "system",
              "content": "You are Dr. HealthAI, a professional medical assistant. Provide concise, evidence-based health information. "
                  "Format responses clearly without asterisks or markdown. "
                  "For serious symptoms, recommend seeing a doctor immediately. "
                  "Keep responses under 3 sentences unless more detail is medically necessary. "
                  "Focus on: symptom explanation, possible causes, when to seek help, and general advice.",
            },
            ..._messages
                .where((m) => m['isUser'] == false)
                .map((m) => {"role": "assistant", "content": m['text']})
                .toList(),
            {"role": "user", "content": message},
          ],
          "model": "meta-llama/llama-4-scout-17b-16e-instruct",
          "temperature": 0.7,
          "max_completion_tokens": 256, // Shorter responses
          "top_p": 1,
          "stream": false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiResponse = data['choices'][0]['message']['content'];
        
        // Clean up response format
        aiResponse = aiResponse.replaceAll('*', '').trim();
        if (aiResponse.startsWith('Dr. HealthAI:')) {
          aiResponse = aiResponse.substring('Dr. HealthAI:'.length).trim();
        }
        
        await _saveMessage(aiResponse, false);

        setState(() {
          _messages.add({
            'text': aiResponse,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
        });
      } else {
        final errorMessage = "I'm currently unable to respond. Please try again with your medical question.";
        await _saveMessage(errorMessage, false);
        
        setState(() {
          _messages.add({
            'text': errorMessage,
            'isUser': false,
            'timestamp': DateTime.now(),
          });
        });
      }
    } catch (e) {
      final errorMessage = "Connection issue. Please check your internet and try again with your health concern.";
      await _saveMessage(errorMessage, false);
      
      setState(() {
        _messages.add({
          'text': errorMessage,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF03045E);
    final Color accentLight = const Color(0xFF90E0EF);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Dr. HealthAI', style: TextStyle(color: Colors.white)),
        backgroundColor: primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, accentLight.withOpacity(0.1)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: _bottomPadding),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(
                      message: message['text'],
                      isUser: message['isUser'],
                      timestamp: message['timestamp'],
                    );
                  },
                ),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.fromLTRB(8, 8, 8, 8 + _bottomPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Describe your health concern...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: primary),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isUser,
    required DateTime timestamp,
  }) {
    final Color primary = const Color(0xFF0077B6);
    final Color accentLight = const Color(0xFF90E0EF);
    final timeFormat = DateFormat('h:mm a');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                'Dr. HealthAI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? primary.withOpacity(0.1) : accentLight.withOpacity(0.3),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isUser ? 12 : 0),
                topRight: Radius.circular(isUser ? 0 : 12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(
                color: isUser ? primary.withOpacity(0.3) : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: isUser ? Colors.black : Colors.black87,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  timeFormat.format(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}