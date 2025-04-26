import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SymptomInputScreen extends StatefulWidget {
  @override
  _SymptomInputScreenState createState() => _SymptomInputScreenState();
}

class _SymptomInputScreenState extends State<SymptomInputScreen> {
  final _symptomController = TextEditingController();
  bool _isLoading = false;
  String _analysisResult = '';
  List<String> _possibleConditions = [];
  List<String> _recommendedActions = [];
  List<String> _medicationSuggestions = [];
  List<Map<String, dynamic>> _chatHistory = [];

  // Groq API Configuration
  static const String GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
  static const String GROQ_API_KEY = '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';
  static const String MODEL = 'meta-llama/llama-4-scout-17b-16e-instruct';

  // Color Scheme
  final Color primaryDark = Color(0xFF03045E);
  final Color primary = Color(0xFF0077B6);
  final Color primaryLight = Color(0xFF00B4D8);
  final Color accentLight = Color(0xFF90E0EF);
  final Color secondaryDark = Color(0xFF05668D);
  final Color secondary = Color(0xFF028090);
  final Color highlight = Color(0xFFF0F3BD);
  final Color accent = Color(0xFF02C39A);

  Future<void> _submitSymptom() async {
    if (_symptomController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _analysisResult = '';
      _possibleConditions = [];
      _recommendedActions = [];
      _medicationSuggestions = [];
    });

    try {
      // Prepare the prompt for the AI
      final prompt = """
You are a professional medical assistant. Analyze these symptoms: ${_symptomController.text}

Provide response in this exact JSON format (keep responses concise):
{
  "analysis": "Brief 1-2 sentence medical summary",
  "possible_conditions": ["Condition 1", "Condition 2", "Condition 3"],
  "recommended_actions": ["Action 1", "Action 2", "Action 3"],
  "medication_suggestions": ["Medication 1 (OTC)", "Medication 2 (if prescribed)", "Medication 3 (if severe)"]
}

Important:
- Only suggest common OTC medications when appropriate
- Always include "consult doctor" for prescription medications
- Never suggest dangerous combinations
- Mark prescription medications clearly
""";

      // Add user message to chat history
      _chatHistory.add({
        "role": "user",
        "content": prompt,
      });

      // Make the API request to Groq
      final response = await http.post(
        Uri.parse(GROQ_API_URL),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $GROQ_API_KEY',
        },
        body: jsonEncode({
          "messages": _chatHistory,
          "model": MODEL,
          "temperature": 0.7,
          "max_completion_tokens": 400,
          "top_p": 1,
          "stop": null,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];

        // Clean response by removing markdown formatting
        String cleanResponse = aiResponse
            .replaceAll('**', '')
            .replaceAll('```', '')
            .replaceAll('json', '')
            .trim();

        // Try to parse the JSON response
        try {
          final parsedResponse = jsonDecode(cleanResponse);
          setState(() {
            _analysisResult = parsedResponse['analysis'] ?? 'No specific condition identified';
            _possibleConditions = List<String>.from(parsedResponse['possible_conditions'] ?? []);
            _recommendedActions = List<String>.from(parsedResponse['recommended_actions'] ?? []);
            _medicationSuggestions = List<String>.from(parsedResponse['medication_suggestions'] ?? []);
          });
        } catch (e) {
          // If JSON parsing fails, use the raw response
          setState(() {
            _analysisResult = cleanResponse;
          });
        }

        // Add AI response to chat history
        _chatHistory.add({
          "role": "assistant",
          "content": aiResponse,
        });
      } else {
        setState(() {
          _analysisResult = 'Error analyzing symptoms. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _analysisResult = 'Service unavailable. Please try later.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: accentLight.withOpacity(0.2),
      appBar: AppBar(
        title: Text(
          'MediCheck AI',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryDark,
        elevation: 0,
        // shape: RoundedRectangleBorder(
        //   borderRadius: BorderRadius.vertical(
        //     bottom: Radius.circular(15),
        //   ),
        // ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Disclaimer', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                  content: Text('This tool provides preliminary health information only. Medication suggestions are for reference and must be approved by a healthcare professional. Never self-medicate without proper medical advice.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('I Understand', 
                        style: TextStyle(color: primary),
                      ),
                    ),
                  ],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Symptom Input Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: primaryDark.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medical_services_outlined, 
                        color: primary, 
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Symptom Assessment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Describe your symptoms in detail (e.g., "throbbing headache for 3 hours with nausea")',
                    style: TextStyle(
                      color: secondaryDark.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _symptomController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter symptoms here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryLight, width: 1.5),
                      ),
                      filled: true,
                      fillColor: accentLight.withOpacity(0.3),
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _submitSymptom,
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.analytics_outlined, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Analyze Symptoms',
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w500
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Results Section
            if (_analysisResult.isNotEmpty) ...[
              SizedBox(height: 30),
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Clinical Analysis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(height: 15),
              
              // Medical Summary
              _buildResultCard(
                icon: Icons.note_alt_rounded,
                title: 'Professional Assessment',
                content: _analysisResult,
                color: primary,
              ),

              // Possible Conditions
              if (_possibleConditions.isNotEmpty) ...[
                SizedBox(height: 20),
                _buildResultCard(
                  icon: Icons.assignment_rounded,
                  title: 'Differential Diagnosis',
                  content: Column(
                    children: _possibleConditions
                        .map((condition) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_possibleConditions.indexOf(condition) + 1}',
                                        style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      condition,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  color: primary,
                ),
              ],

              // Recommended Actions
              if (_recommendedActions.isNotEmpty) ...[
                SizedBox(height: 20),
                _buildResultCard(
                  icon: Icons.recommend_rounded,
                  title: 'Clinical Recommendations',
                  content: Column(
                    children: _recommendedActions
                        .map((action) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_rounded, 
                                    size: 20, 
                                    color: accent,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      action,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  color: accent,
                ),
              ],

              // Medication Suggestions
              if (_medicationSuggestions.isNotEmpty) ...[
                SizedBox(height: 20),
                _buildResultCard(
                  icon: Icons.medication_rounded,
                  title: 'Medication Guidance',
                  content: Column(
                    children: _medicationSuggestions
                        .map((med) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    med.toLowerCase().contains('consult') 
                                      ? Icons.warning_amber_rounded
                                      : Icons.medical_information_rounded,
                                    size: 20,
                                    color: med.toLowerCase().contains('consult') 
                                      ? secondary 
                                      : primaryLight,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      med,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: med.toLowerCase().contains('consult') 
                                          ? secondary 
                                          : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  color: secondary,
                  warning: true,
                ),
              ],
              
              // Medical Disclaimer
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: highlight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: secondary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: secondaryDark,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'Important: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: secondary,
                        ),
                      ),
                      TextSpan(
                        text: 'This analysis is not a substitute for professional medical care. Always consult a qualified healthcare provider for diagnosis and treatment, especially before taking any medication.',
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Symptom Examples (when no results yet)
            if (_analysisResult.isEmpty) ...[
              SizedBox(height: 30),
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Common Symptom Examples',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  'Headache with nausea',
                  'Fever above 38°C',
                  'Persistent dry cough',
                  'Fatigue for 1 week',
                  'Sharp abdominal pain',
                  'Dizziness when standing',
                  'Shortness of breath',
                  'Chest tightness',
                  'Joint swelling and pain',
                  'Sore throat with fever',
                ].map((symptom) => GestureDetector(
                      onTap: () {
                        _symptomController.text = symptom;
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryLight.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          symptom,
                          style: TextStyle(
                            color: primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )).toList(),
              ),
              SizedBox(height: 25),
              Container(
                decoration: BoxDecoration(
                  color: accentLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryLight.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, 
                      color: primaryLight,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'For accurate results: Describe symptom duration, severity, location, and any accompanying symptoms.',
                        style: TextStyle(
                          color: secondaryDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required String title,
    required dynamic content,
    Color color = Colors.blue,
    bool warning = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: warning 
          ? Border.all(
              color: secondary.withOpacity(0.3),
              width: 1.5,
            )
          : null,
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, 
                color: color,
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          if (content is String)
            Text(
              content,
              style: TextStyle(
                fontSize: 16, 
                height: 1.5,
                color: Colors.grey.shade800,
              ),
            )
          else if (content is Widget)
            content,
        ],
      ),
    );
  }
}