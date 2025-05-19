import 'dart:convert';
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

  List<Map<String, dynamic>> medicines = [];
  List<String> _extractedMedicines = [];
  List<Map<String, dynamic>> _matchedMedicines = [];
  List<Map<String, dynamic>> _alternativeMedicines = [];
  String _formattedReport = '';

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    try {
      String data = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/json/medicines.json');
      setState(() {
        medicines = List<Map<String, dynamic>>.from(json.decode(data));
      });
    } catch (e) {
      _showError('Failed to load medicine database: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _analysisResult = '';
          _extractedMedicines = [];
          _matchedMedicines = [];
          _alternativeMedicines = [];
          _formattedReport = '';
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
      _extractedMedicines = [];
      _matchedMedicines = [];
      _alternativeMedicines = [];
      _formattedReport = '';
    });

    try {
      const apiBase = "http://203.6.209.25:5010";

      const prompt = """
You are a compassionate medical-report analysis assistant. Parse the following clinical document and extract its information with sensitivity and accuracy. Return the response formatted exactly as plain text with section headings and simple lines—do not use asterisks, hashtags, or any special characters also any brackets{}()[] or other symbols.. Include a brief sentiment analysis at the end.

Patient Information:
Name: [patient name here]
Age: [age if available]
Gender: [gender if available]

Doctor Information:
Name: [doctor name here]
Specialty: [specialty if available]

Report Details:
Date: [report date here]
Diagnosis: [primary diagnosis if available]

Medications:
Medication 1: [Corrected Medication Name 1]
Medication 2: [Corrected Medication Name 2]
Medication 3: [Corrected Medication Name 3]

Report Summary:
[Provide a concise three to four sentence summary of the report's key findings in clear, patient-friendly language]

Sentiment Analysis:
Overall Tone of Report: [e.g. reassuring, urgent, cautious]
Estimated Patient Emotional Context: [e.g. concerned, hopeful, anxious]

Important Notes:
1. Verify medication names against a trusted medical lexicon (for example, RxNorm) and correct any spelling errors.
2. List only the medication names under "Medications"—do not include any dosage, strength, or frequency word "tab" fellow this strictly.
3. If a field cannot be found, leave its value blank.
4. Do not mix up fields—keep each piece of data under its proper heading.
5. Do not add any extra commentary, sections, or formatting beyond what is requested.
6. Preserve these exact headings and plain-text formatting.
7. dont include any etra words expect the mentiones above.
""";

      var request = http.MultipartRequest('POST', Uri.parse('$apiBase/vision'));
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          _selectedFile!.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      request.fields['prompt'] = prompt;

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      print(responseData);
      if (response.statusCode == 200) {
        _processResponse(responseData);
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

  void _processResponse(String response) {
    try {
      // Clean up the response by removing JSON formatting if present
      String cleanedResponse = response;
      if (response.startsWith('{') && response.endsWith('}')) {
        try {
          final jsonResponse = json.decode(response);
          cleanedResponse = jsonResponse['description'] ?? response;
        } catch (e) {
          cleanedResponse = response;
        }
      }

      cleanedResponse = cleanedResponse
          .replaceAll('*', '')
          .replaceAll('#', '')
          .replaceAll('**', '')
          .replaceAll('\\n', '\n');

      // Extract medications section
      final medsSection = _extractSection(
        cleanedResponse,
        'Medications:',
        'Report Summary:',
      );

      if (medsSection != null) {
        _extractedMedicines =
            medsSection
                .split('\n')
                .where(
                  (line) =>
                      line.trim().isNotEmpty &&
                      !line.trim().startsWith('Medication'),
                )
                .map((line) => line.trim())
                .toList();
      }

      // Match medicines with database
      _matchMedicines();

      // Format the report for display
      setState(() {
        _formattedReport = _formatReport(cleanedResponse);
        _analysisResult =
            'Found ${_extractedMedicines.length} medications in the report';
      });
    } catch (e) {
      _showError('Error processing response: $e');
    }
  }

  String _formatReport(String report) {
    // Split into sections
    List<String> sections = report.split('\n\n');

    // Format each section
    String formatted = '';
    for (String section in sections) {
      if (section.startsWith('Patient Information:')) {
        formatted += 'PATIENT INFORMATION\n';
        formatted +=
            section.replaceFirst('Patient Information:', '').trim() + '\n\n';
      } else if (section.startsWith('Doctor Information:')) {
        formatted += 'DOCTOR INFORMATION\n';
        formatted +=
            section.replaceFirst('Doctor Information:', '').trim() + '\n\n';
      } else if (section.startsWith('Report Details:')) {
        formatted += 'REPORT DETAILS\n';
        formatted +=
            section.replaceFirst('Report Details:', '').trim() + '\n\n';
      } else if (section.startsWith('Medications:')) {
        formatted += 'PRESCRIBED MEDICATIONS\n';
        formatted += section.replaceFirst('Medications:', '').trim() + '\n\n';
      } else if (section.startsWith('Report Summary:')) {
        formatted += 'REPORT SUMMARY\n';
        formatted +=
            section.replaceFirst('Report Summary:', '').trim() + '\n\n';
      } else if (section.startsWith('Sentiment Analysis:')) {
        formatted += 'SENTIMENT ANALYSIS\n';
        formatted +=
            section.replaceFirst('Sentiment Analysis:', '').trim() + '\n\n';
      } else {
        formatted += section + '\n\n';
      }
    }

    return formatted.trim();
  }

  String? _extractSection(
    String text,
    String startDelimiter,
    String endDelimiter,
  ) {
    final startIndex = text.indexOf(startDelimiter);
    if (startIndex == -1) return null;

    final endIndex =
        endDelimiter.isNotEmpty
            ? text.indexOf(endDelimiter, startIndex + startDelimiter.length)
            : text.length;
    if (endIndex == -1) return null;

    return text.substring(startIndex + startDelimiter.length, endIndex).trim();
  }

  void _matchMedicines() {
    _matchedMedicines = [];
    _alternativeMedicines = [];

    for (var med in _extractedMedicines) {
      // Extract just the medicine name (without dosage)
      String medName = med.split('(')[0].trim();
      print("MedName: $medName");

      // Find exact or partial matches
      var matches =
          medicines.where((m) {
            String dbName = m['Medicine Name']?.toString() ?? '';
            return _normalizeMedicineName(
                  dbName,
                ).contains(_normalizeMedicineName(medName)) ||
                _normalizeMedicineName(
                  medName,
                ).contains(_normalizeMedicineName(dbName));
          }).toList();

      if (matches.isNotEmpty) {
        // Take the first match as the primary medicine
        var primaryMatch = matches.first;
        _matchedMedicines.add(primaryMatch);

        // Find medicines with similar composition (alternatives)
        final composition = primaryMatch['Composition']?.toString();
        if (composition != null && composition.isNotEmpty) {
          // Get all medicines with the same composition (excluding the primary match)
          var alternatives =
              medicines.where((m) {
                return m['Composition']?.toString() == composition &&
                    m['Medicine Name']?.toString() !=
                        primaryMatch['Medicine Name']?.toString();
              }).toList();

          // Shuffle and take up to 5 random alternatives
          alternatives.shuffle();
          if (alternatives.length > 5) {
            alternatives = alternatives.sublist(0, 5);
          }

          _alternativeMedicines.addAll(alternatives);
        }
      }
    }

    // Remove duplicates
    _matchedMedicines = _matchedMedicines.toSet().toList();
    _alternativeMedicines = _alternativeMedicines.toSet().toList();
  }

  String _normalizeMedicineName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _analysisResult = '';
      _extractedMedicines = [];
      _matchedMedicines = [];
      _alternativeMedicines = [];
      _formattedReport = '';
    });
  }

  Widget _buildReportSection(String title, String content) {
    if (content.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            content,
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMedicineAnalysis() {
    if (_matchedMedicines.isEmpty && _alternativeMedicines.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MEDICINE ANALYSIS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryDark,
          ),
        ),
        const SizedBox(height: 10),

        // Group matched medicines with their alternatives
        for (int i = 0; i < _matchedMedicines.length; i++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prescribed Medicine ${i + 1}:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: secondaryDark,
                ),
              ),
              const SizedBox(height: 8),
              _buildMedicineCard(_matchedMedicines[i], false),

              // Show alternatives for this medicine if available
              if (_alternativeMedicines.isNotEmpty &&
                  _alternativeMedicines.any(
                    (alt) =>
                        alt['Composition'] ==
                        _matchedMedicines[i]['Composition'],
                  ))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Alternative Medicines (Same Composition):',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: secondaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._alternativeMedicines
                        .where(
                          (alt) =>
                              alt['Composition'] ==
                              _matchedMedicines[i]['Composition'],
                        )
                        .map((alt) => _buildMedicineCard(alt, true)),
                    const SizedBox(height: 10),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),

        Text(
          'Note: Alternatives have the same active ingredients but may differ in brand or price',
          style: TextStyle(
            fontSize: 12,
            color: secondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine, bool isAlternative) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isAlternative ? accentLight.withOpacity(0.2) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isAlternative ? primaryLight.withOpacity(0.5) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAlternative ? Icons.medication_outlined : Icons.medication,
                  color: isAlternative ? primaryLight : primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    medicine['Medicine Name'] ?? 'Unknown Medicine',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isAlternative ? primary : primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (medicine['Composition'] != null)
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  'Composition: ${medicine['Composition']}',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            if (medicine['Dosage Form'] != null)
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  'Form: ${medicine['Dosage Form']}',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
          ],
        ),
      ),
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
          title: const Text(
            'Medicine Report Analyzer',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: primary,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: highlight),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accentLight.withOpacity(0.2), Colors.white],
              stops: [0.1, 0.9],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 15,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        accentLight.withOpacity(0.3),
                        primaryLight.withOpacity(0.3),
                      ],
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
                      Icon(Icons.medication_liquid, size: 50, color: primary),
                      const SizedBox(height: 10),
                      Text(
                        'Medicine Analysis Tool',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Upload your medical report to analyze prescribed medicines',
                        style: TextStyle(fontSize: 14, color: secondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                Card(
                  color: Colors.white,
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
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 20.0,
                                  right: 20.0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload,
                                      size: 50,
                                      color: primaryLight,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Tap to upload report',
                                      style: TextStyle(
                                        color: secondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
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
                  icon: Icon(Icons.search, size: 24),
                  label: Text(
                    'ANALYZE MEDICINES',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: accent.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 30),

                if (_analysisResult.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryLight.withOpacity(0.3)),
                    ),
                    child: Text(
                      _analysisResult,
                      style: TextStyle(
                        fontSize: 16,
                        color: primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Display the formatted report
                  if (_formattedReport.isNotEmpty) ...[
                    _buildReportSection('REPORT ANALYSIS', _formattedReport),
                    const SizedBox(height: 20),
                  ],

                  // Display medicine analysis
                  _buildMedicineAnalysis(),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Text(
                      'Important: Always consult with your doctor before making any changes to your prescribed medications.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        floatingActionButton:
            _selectedFile != null && _analysisResult.isEmpty
                ? FloatingActionButton.extended(
                  onPressed: _analyzeReport,
                  icon: Icon(Icons.search),
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
