import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

class ReportScanner extends StatefulWidget {
  const ReportScanner({super.key});

  @override
  State<ReportScanner> createState() => _ReportScannerState();
}

class _ReportScannerState extends State<ReportScanner> {
  final Color primaryDark = const Color(0xFF03045E);
  final Color primary = const Color(0xFF03045E);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentLight = const Color(0xFF90E0EF);
  final Color secondaryDark = const Color(0xFF05668D);
  final Color secondary = const Color(0xFF028090);
  final Color highlight = const Color(0xFFF0F3BD);
  final Color accent = const Color(0xFF02C39A);

  File? _selectedFile;
  String _analysisResult = '';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _analysisResult = '';
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _analyzeReport() async {
    if (_selectedFile == null) {
      _showError('Please select a medical report image first');
      return;
    }

    setState(() {
      _isLoading = true;
      _analysisResult = '';
    });

    try {
      const apiBase = "http://203.6.209.25:5010";
      
      const prompt = """
Please analyze this medical report thoroughly and provide a CLEAR, PATIENT-FRIENDLY summary with the following structure:

**Short Summary:**
- Provide a 2-3 sentence overview of the report's key points

**Patient & Doctor Information:**
- Bold the patient name and doctor name if present
- Mention patient age/sex if visible

**Report Type:**
- Identify the type of medical report

**Key Findings:**
- List 3-5 most important findings
- Highlight abnormal values
- Use bullet points with simple explanations

**Medications Identified:**
- List all medicine names clearly
- Format as: "• Medicine Name (Dosage if available)"
- Group similar medications

**Clinical Interpretation:**
- Explain what the findings mean in simple terms
- Use analogies where helpful
- Highlight urgent concerns

**Recommended Actions:**
- Suggest follow-up steps
- Mention if specialist consultation is needed
- Include lifestyle recommendations

**Important Notes:**
- Add disclaimers about limitations
- Remind to consult with their doctor
- Include emergency warnings if needed

Format with clear section headings, proper spacing, and plain language. Remove any symbols like *, **, nn, description, or other formatting artifacts.
""";

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/vision'),
      );

      request.files.add(await http.MultipartFile.fromPath(
        'image',
        _selectedFile!.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      request.fields['prompt'] = prompt;

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        setState(() {
          _analysisResult = _formatResponse(responseData);
        });
      } else {
        _showError('Analysis failed: ${response.reasonPhrase}');
      }
    } catch (e) {
      _showError('Error during analysis: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatResponse(String response) {
    // Clean up the response formatting
    String cleaned = response
        .replaceAll('*', '')
        .replaceAll('\\', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('**', '')
        .replaceAll('nn', '')
        .replaceAll('""', '')
        .replaceAll('description:', '')
        .replaceAll('description', '')
        .replaceAll('•', '•');

    // Enhance patient and doctor names
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(Patient Name:|Doctor Name:)(.*)'),
      (match) => '${match.group(1)} **${match.group(2)?.trim()}**',
    );

    // Add spacing between sections
    final sections = [
      'Short Summary:',
      'Patient & Doctor Information:',
      'Report Type:',
      'Key Findings:',
      'Medications Identified:',
      'Clinical Interpretation:',
      'Recommended Actions:',
      'Important Notes:'
    ];

    for (var section in sections) {
      cleaned = cleaned.replaceAll('$section', '\n\n$section\n');
    }

    // Capitalize the first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    // Remove excessive empty lines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
      ),
    ));
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _analysisResult = '';
    });
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: primaryDark,
        ),
      ),
    );
  }

  Widget _buildRichText(String text) {
    final List<TextSpan> spans = [];
    final lines = text.split('\n');
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      // Bold patient and doctor names
      if (line.contains('Patient Name:') || line.contains('Doctor Name:')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          spans.add(TextSpan(
            text: '${parts[0]}: ',
            style: TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ));
          spans.add(TextSpan(
            text: parts[1].trim(),
            style: TextStyle(
              color: primaryDark,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ));
        } else {
          spans.add(TextSpan(
            text: line,
            style: TextStyle(
              color: primaryDark,
              fontSize: 14,
            ),
          ));
        }
      } 
      // Style medications differently
      else if (line.contains('•') && 
              (line.contains('Medications Identified:') || 
               line.contains('Suggested Medications:'))) {
        spans.add(TextSpan(
          text: line,
          style: TextStyle(
            color: secondaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ));
      }
      // Highlight short summary
      else if (line.contains('Short Summary:')) {
        spans.add(TextSpan(
          text: line.replaceFirst('Short Summary:', ''),
          style: TextStyle(
            color: primaryDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ));
      }
      else {
        spans.add(TextSpan(
          text: line,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
        ));
      }
      spans.add(const TextSpan(text: '\n'));
    }
    
    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildAnalysisResult() {
    if (_analysisResult.isEmpty) return Container();

    List<Widget> sections = [];
    List<String> parts = _analysisResult.split('\n\n');

    for (String part in parts) {
      if (part.contains('Short Summary:')) {
        sections.add(_buildSectionHeader('Quick Overview'));
        sections.add(_buildRichText(part.replaceFirst('Short Summary:', '').trim()));
      }
      else if (part.contains('Patient & Doctor Information:')) {
        sections.add(_buildSectionHeader('Patient & Doctor Information'));
        sections.add(_buildRichText(part.replaceFirst('Patient & Doctor Information:', '').trim()));
      } 
      else if (part.contains('Report Type:')) {
        sections.add(_buildSectionHeader('Report Type'));
        sections.add(_buildRichText(part.replaceFirst('Report Type:', '').trim()));
      }
      else if (part.contains('Key Findings:')) {
        sections.add(_buildSectionHeader('Key Findings'));
        sections.add(_buildRichText(part.replaceFirst('Key Findings:', '').trim()));
      }
      else if (part.contains('Medications Identified:')) {
        sections.add(_buildSectionHeader('Medications Identified'));
        sections.add(_buildRichText(part.replaceFirst('Medications Identified:', '').trim()));
      }
      else if (part.contains('Clinical Interpretation:')) {
        sections.add(_buildSectionHeader('Clinical Interpretation'));
        sections.add(_buildRichText(part.replaceFirst('Clinical Interpretation:', '').trim()));
      }
      else if (part.contains('Recommended Actions:')) {
        sections.add(_buildSectionHeader('Recommended Actions'));
        sections.add(_buildRichText(part.replaceFirst('Recommended Actions:', '').trim()));
      }
      else if (part.contains('Important Notes:')) {
        sections.add(_buildSectionHeader('Important Notes'));
        sections.add(_buildRichText(part.replaceFirst('Important Notes:', '').trim()));
      }
      else {
        sections.add(_buildRichText(part));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModalProgressHUD(
      inAsyncCall: _isLoading,
      opacity: 0.7,
      color: primaryDark,
      progressIndicator: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(highlight),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Medical Report Scanner',style: TextStyle(color: Colors.white),),
          backgroundColor: primary,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: highlight),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: accentLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Icon(Icons.medical_services, size: 50, color: primary),
                    const SizedBox(height: 10),
                    Text(
                      'Medical Report Assistant',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Upload your medical reports to get a clear, easy-to-understand explanation',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Select Report Image',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryDark,
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (_selectedFile == null)
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: accentLight.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: primaryLight,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload, 
                                    size: 50, color: primaryLight),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap to upload report',
                                  style: TextStyle(
                                    color: secondary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '(Supports JPG, PNG)',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedFile!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: Icon(Icons.edit, size: 18),
                                  label: Text('Change'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryLight,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _clearSelection,
                                  icon: Icon(Icons.delete, size: 18),
                                  label: Text('Remove'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[300],
                                    foregroundColor: primaryDark,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _analyzeReport,
                icon: Icon(Icons.analytics, size: 24),
                label: Text(
                  'ANALYZE REPORT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  shadowColor: accent.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 30),

              if (_analysisResult.isNotEmpty)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.insights, color: primary),
                            const SizedBox(width: 10),
                            Text(
                              'Report Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: accentLight),
                          ),
                          child: SingleChildScrollView(
                            child: _buildAnalysisResult(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Text(
                            'Important: This analysis is generated by AI and should not replace professional medical advice. Always consult with your doctor about your health concerns.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        floatingActionButton: _selectedFile != null && _analysisResult.isEmpty
            ? FloatingActionButton.extended(
                onPressed: _analyzeReport,
                icon: Icon(Icons.analytics),
                label: Text('Analyze'),
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 3,
              )
            : null,
      ),
    );
  }
}