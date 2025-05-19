import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  List<Map<String, dynamic>> _medicationSuggestions = [];
  List<Map<String, dynamic>> _doctorSuggestions = [];
  List<Map<String, dynamic>> _chatHistory = [];
  String _currentCity = '';
  bool _locationLoading = false;
  List<String> _recommendedSpecializations = [];

  List<Map<String, dynamic>> _allMedicines = [];
  List<Map<String, dynamic>> _allDoctors = [];

  // Color Scheme
  final Color primaryDark = Color(0xFF03045E);
  final Color primary = Color(0xFF0077B6);
  final Color primaryLight = Color(0xFF00B4D8);
  final Color accentLight = Color(0xFF90E0EF);
  final Color secondaryDark = Color(0xFF05668D);
  final Color secondary = Color(0xFF028090);
  final Color highlight = Color(0xFFF0F3BD);
  final Color accent = Color(0xFF02C39A);

  // List of major cities in Pakistan
  final List<String> _pakistanCities = [
    'Islamabad',
    'Karachi',
    'Lahore',
    'Faisalabad',
    'Rawalpindi',
    'Multan',
    'Gujranwala',
    'Hyderabad',
    'Peshawar',
    'Quetta',
    'Bahawalpur',
    'Sargodha',
    'Sialkot',
    'Sukkur',
    'Larkana',
    'Sheikhupura',
    'Rahim Yar Khan',
    'Jhang',
    'Dera Ghazi Khan',
    'Gujrat',
    'Sahiwal',
    'Wah Cantonment',
    'Mardan',
    'Kasur',
    'Okara',
    'Mingora',
    'Nawabshah',
    'Chiniot',
    'Kamoke',
    'Hafizabad',
    'Kot Addu',
    'Mirpur Khas',
    'Chishtian',
    'Abbottabad',
    'Jhelum',
    'Mansehra',
    'Khanewal',
    'Muzaffargarh',
    'Khanpur',
    'Gojra',
    'Bahawalnagar',
    'Muridke',
    'Pakpattan',
    'Jaranwala',
    'Chakwal',
    'Kharian',
    'Mianwali',
    'Tando Adam',
    'Kamalia',
    'Vehari',
    'Kotri',
    'Wazirabad',
    'Khairpur',
    'Daska',
    'Swabi',
    'Haripur',
    'Taxila',
    'Nowshera',
    'Kohat',
    'Muzaffarabad',
    'Mirpur',
    'Gilgit',
    'Skardu',
  ];

  @override
  void initState() {
    super.initState();
    _loadJsonData();
    _getCurrentLocation();
  }

  // Show city search dialog
  void _showCitySearch() {
    TextEditingController searchController = TextEditingController();
    List<String> filteredCities = List.from(_pakistanCities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select City',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: primaryDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 10),
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: accentLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search cities...',
                    prefixIcon: Icon(Icons.search, color: primary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      filteredCities = _pakistanCities
                          .where((city) => city.toLowerCase().contains(
                                value.toLowerCase(),
                              ))
                          .toList();
                    });
                  },
                ),
              ),
              SizedBox(height: 15),
              // Current location button
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await _getCurrentLocation();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.my_location, color: primary),
                      SizedBox(width: 10),
                      Text(
                        'Use my current location',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredCities.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(Icons.location_city, color: primaryLight),
                      title: Text(filteredCities[index]),
                      onTap: () {
                        setState(() {
                          _currentCity = filteredCities[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Get current location and city
  Future<void> _getCurrentLocation() async {
    setState(() {
      _locationLoading = true;
    });

    try {
      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get city name from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        setState(() {
          _currentCity = placemarks[0].locality ?? '';
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      // If we can't get location, we'll proceed without city filtering
    } finally {
      setState(() {
        _locationLoading = false;
      });
    }
  }

  // Load JSON data
  Future<void> _loadJsonData() async {
    try {
      // Load medicines data
      final medicinesString =
          await rootBundle.loadString('assets/json/medicines.json');
      final medicinesJson = json.decode(medicinesString) as List;
      _allMedicines = medicinesJson.cast<Map<String, dynamic>>();

      // Load doctors data
      final doctorsString =
          await rootBundle.loadString('assets/json/doctors.json');
      final doctorsJson = json.decode(doctorsString) as List;
      _allDoctors = doctorsJson.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading JSON data: $e');
      // Initialize as empty lists if there's an error
      _allMedicines = [];
      _allDoctors = [];
    }
  }

  // Groq API Configuration
  static const String GROQ_API_URL =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String GROQ_API_KEY =
      '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';
  static const String MODEL = 'meta-llama/llama-4-scout-17b-16e-instruct';

  // Function to find medicines by condition or symptom
  List<Map<String, dynamic>> _findMedicinesForCondition(String condition) {
    try {
      // Simple mapping between conditions and medicine types
      final conditionToMedicineType = {
        'headache': ['pain', 'analgesic', 'migraine'],
        'fever': ['fever', 'paracetamol', 'ibuprofen'],
        'cough': ['cough', 'expectorant', 'antitussive'],
        'pain': ['pain', 'analgesic', 'anti-inflammatory'],
        'dizziness': ['vertigo', 'dizziness'],
        'breath': ['asthma', 'bronchodilator'],
        'chest': ['heart', 'angina'],
        'joint': ['arthritis', 'pain', 'anti-inflammatory'],
        'throat': ['throat', 'antibiotic', 'lozenge'],
        'stomach': ['antacid', 'stomach', 'digestion'],
      };

      // Find the most relevant medicine types
      List<String> medicineTypes = ['general'];
      for (var key in conditionToMedicineType.keys) {
        if (condition.toLowerCase().contains(key)) {
          medicineTypes = conditionToMedicineType[key]!;
          break;
        }
      }

      // Find medicines that match any of the relevant types
      List<Map<String, dynamic>> matchingMedicines = [];

      for (var med in _allMedicines) {
        // Check if medicine name or composition contains any of the relevant keywords
        bool matches = medicineTypes.any(
            (type) =>
                med['Medicine Name'].toString().toLowerCase().contains(type) ||
                med['Composition'].toString().toLowerCase().contains(type));

        if (matches) {
          matchingMedicines.add(med);
        }

        // Limit to 10 medicines
        if (matchingMedicines.length >= 10) break;
      }

      return matchingMedicines;
    } catch (e) {
      print('Error finding medicines: $e');
      return [];
    }
  }

  // Function to find similar medicines by composition
  List<Map<String, dynamic>> _findSimilarMedicines(String medicineName) {
    try {
      // Find the original medicine
      final originalMedicine = _allMedicines.firstWhere(
          (med) => med['Medicine Name']
              .toString()
              .toLowerCase()
              .contains(medicineName.toLowerCase()),
          orElse: () => <String, dynamic>{});

      if (originalMedicine.isEmpty) return [];

      // Get the composition of the original medicine
      final composition = originalMedicine['Composition'] as String;

      // Find all medicines with similar composition
      final similarMedicines = _allMedicines.where((med) {
        return med['Composition'] == composition &&
            med['Medicine Name'] != originalMedicine['Medicine Name'];
      }).toList();

      // Take up to 5 random similar medicines
      similarMedicines.shuffle();
      return similarMedicines.take(5).toList();
    } catch (e) {
      print('Error finding similar medicines: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _findDoctorsBySpecialization(
      List<String> specializations) {
    try {
      // Find doctors with matching specialization and city
      List<Map<String, dynamic>> matchingDoctors = [];
      
      for (var doc in _allDoctors) {
        // Check if any of the specializations partially matches the doctor's specialization
        bool matches = specializations.any((spec) {
          // Split both strings into words and check for any word matches
          List<String> specWords = spec.toLowerCase().split(' ');
          List<String> docSpecWords = doc['Specialization'].toString().toLowerCase().split(' ');
          
          // Check if any word from the specialization matches any word in doctor's specialization
          return specWords.any((specWord) => 
              docSpecWords.any((docWord) => docWord.contains(specWord) || specWord.contains(docWord)));
        });

        if (matches) {
          matchingDoctors.add(doc);
        }

        // Limit to 5 doctors
        if (matchingDoctors.length >= 5) break;
      }

      // Filter by city if we have the current city
      if (_currentCity.isNotEmpty) {
        matchingDoctors = matchingDoctors.where((doc) {
          return doc['City']
              .toString()
              .toLowerCase()
              .contains(_currentCity.toLowerCase());
        }).toList();
      }

      return matchingDoctors;
    } catch (e) {
      print('Error finding doctors: $e');
      return [];
    }
  }

  Future<void> _submitSymptom() async {
    if (_symptomController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _analysisResult = '';
      _possibleConditions = [];
      _recommendedActions = [];
      _medicationSuggestions = [];
      _doctorSuggestions = [];
      _recommendedSpecializations = [];
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
  "recommended_specializations": ["Specialist 1", "Specialist 2"],
  "medication_suggestions": [
    {
      "name": "Medicine 1",
      "composition": "Active ingredients",
      "purpose": "What it treats",
      "prescription_required": true/false
    },
    {
      "name": "Medicine 2",
      "composition": "Active ingredients",
      "purpose": "What it treats",
      "prescription_required": true/false
    }
  ]
}

Important:
- Suggest 2-3 most relevant medical Specialization flied like Dermatologist, Gastroenterologist, etc.
- For medications, provide exact composition details when possible
- Clearly mark prescription requirements
- Only suggest common OTC medications when appropriate
- Always include "consult doctor" for serious symptoms
""";

      // Add user message to chat history
      _chatHistory.add({"role": "user", "content": prompt});

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
          "max_completion_tokens": 500,
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
            _analysisResult =
                parsedResponse['analysis'] ?? 'No specific condition identified';
            _possibleConditions =
                List<String>.from(parsedResponse['possible_conditions'] ?? []);
            _recommendedActions =
                List<String>.from(parsedResponse['recommended_actions'] ?? []);
            _recommendedSpecializations = List<String>.from(
                parsedResponse['recommended_specializations'] ?? []);

            // Process medication suggestions
            if (parsedResponse['medication_suggestions'] != null) {
              final List<dynamic> medSuggestions =
                  parsedResponse['medication_suggestions'];
              _medicationSuggestions = [];

              for (var med in medSuggestions) {
                // Try to find exact matches from our medicines.json
                try {
                  final exactMatch = _allMedicines.firstWhere((m) =>
                      m['Medicine Name']
                          .toString()
                          .toLowerCase()
                          .contains(med['name'].toString().toLowerCase()));

                  _medicationSuggestions.add({
                    'name': exactMatch['Medicine Name'],
                    'composition': exactMatch['Composition'],
                    'purpose': med['purpose'] ?? 'For ${_possibleConditions.isNotEmpty ? _possibleConditions[0] : 'symptom relief'}',
                    'prescription_required': med['prescription_required'] ?? false,
                    'similar': _findSimilarMedicines(exactMatch['Medicine Name']),
                  });
                } catch (e) {
                  // If no exact match, try to find by composition
                  try {
                    final compositionMatch = _allMedicines.firstWhere((m) =>
                        m['Composition']
                            .toString()
                            .toLowerCase()
                            .contains(med['composition'].toString().toLowerCase()));

                    _medicationSuggestions.add({
                      'name': compositionMatch['Medicine Name'],
                      'composition': compositionMatch['Composition'],
                      'purpose': med['purpose'] ?? 'For ${_possibleConditions.isNotEmpty ? _possibleConditions[0] : 'symptom relief'}',
                      'prescription_required': med['prescription_required'] ?? false,
                      'similar': _findSimilarMedicines(compositionMatch['Medicine Name']),
                    });
                  } catch (e) {
                    // If still no match, add the AI-suggested medicine as is
                    _medicationSuggestions.add({
                      'name': med['name'],
                      'composition': med['composition'],
                      'purpose': med['purpose'] ?? 'For ${_possibleConditions.isNotEmpty ? _possibleConditions[0] : 'symptom relief'}',
                      'prescription_required': med['prescription_required'] ?? false,
                      'similar': [],
                    });
                  }
                }
              }
            }

            // If no medications from AI, try to find based on condition
            if (_medicationSuggestions.isEmpty && _possibleConditions.isNotEmpty) {
              final conditionBasedMeds =
                  _findMedicinesForCondition(_possibleConditions[0]);
              for (var med in conditionBasedMeds) {
                _medicationSuggestions.add({
                  'name': med['Medicine Name'],
                  'composition': med['Composition'],
                  'purpose': 'For ${_possibleConditions[0]}',
                  'prescription_required': false,
                  'similar': _findSimilarMedicines(med['Medicine Name']),
                });
              }
            }

            // Find doctors for the recommended specializations
            if (_recommendedSpecializations.isNotEmpty) {
              print('receommended specializations: ${_recommendedSpecializations}');
              _doctorSuggestions =
                  _findDoctorsBySpecialization(_recommendedSpecializations);
            } else if (_possibleConditions.isNotEmpty) {
              // Fallback if no specializations were provided
              _doctorSuggestions =
                  _findDoctorsBySpecialization(_possibleConditions);
            }
          });
        } catch (e) {
          // If JSON parsing fails, use the raw response
          setState(() {
            _analysisResult = cleanResponse;
          });
        }

        // Add AI response to chat history
        _chatHistory.add({"role": "assistant", "content": aiResponse});
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
      backgroundColor: Colors.white,
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.location_on_outlined, color: Colors.white),
            onPressed: _showCitySearch,
          ),
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Disclaimer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryDark,
                    ),
                  ),
                  content: Text(
                    'This tool provides preliminary health information only. Medication suggestions are for reference and must be approved by a healthcare professional. Never self-medicate without proper medical advice.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'I Understand',
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
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Indicator
              if (_locationLoading)
                Padding(
                  padding: EdgeInsets.only(bottom: 15),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primary),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Detecting your location...',
                        style: TextStyle(color: primary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else if (_currentCity.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 15),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Showing results for $_currentCity',
                        style: TextStyle(color: primary, fontSize: 14),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showCitySearch,
                        child: Text(
                          '(Change)',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                        Icon(
                          Icons.medical_services_outlined,
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
                          borderSide: BorderSide(
                            color: primaryLight,
                            width: 1.5,
                          ),
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
                          backgroundColor: accent,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
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
                                      fontWeight: FontWeight.w500,
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
                          .map(
                            (condition) => Padding(
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
                            ),
                          )
                          .toList(),
                    ),
                    color: primary,
                  ),
                ],

                // Recommended Specializations
                if (_recommendedSpecializations.isNotEmpty) ...[
                  SizedBox(height: 20),
                  _buildResultCard(
                    icon: Icons.medical_services_rounded,
                    title: 'Recommended Specialists',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Based on your symptoms, you should consult with:',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 10),
                        ..._recommendedSpecializations
                            .map(
                              (spec) => Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.medical_information_rounded,
                                      size: 20,
                                      color: primaryLight,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        spec,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ],
                    ),
                    color: secondaryDark,
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
                          .map(
                            (action) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
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
                            ),
                          )
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
                          .map(
                            (med) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Main medicine
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        med['prescription_required']
                                            ? Icons.medical_information_rounded
                                            : Icons.medication_liquid_rounded,
                                        size: 20,
                                        color: med['prescription_required']
                                            ? Colors.orange
                                            : primaryLight,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med['name'],
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Composition: ${med['composition']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Purpose: ${med['purpose']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              med['prescription_required']
                                                  ? '⚠️ Prescription required'
                                                  : '✅ Over-the-counter',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: med['prescription_required']
                                                    ? Colors.orange
                                                    : accent,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Similar medicines
                                if ((med['similar'] as List).isNotEmpty) ...[
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 32,
                                      top: 4,
                                      bottom: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Similar medicines:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        ...(med['similar'] as List<dynamic>)
                                            .map(
                                              (similar) => Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Text(
                                                  '• ${similar['Medicine Name']} (${similar['Composition']})',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ],
                                    ),
                                  ),
                                ],

                                Divider(
                                  color: Colors.grey.shade300,
                                  height: 16,
                                  thickness: 1,
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                    color: secondary,
                    warning: true,
                  ),
                ],

                // Doctor Suggestions
                if (_doctorSuggestions.isNotEmpty) ...[
                  SizedBox(height: 20),
                  _buildResultCard(
                    icon: Icons.medical_services_rounded,
                    title: 'Available Specialists Nearby',
                    content: Column(
                      children: _doctorSuggestions
                          .map(
                            (doc) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc['Doctor Name'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: primaryDark,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${doc['Specialization']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: secondary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${doc['Clinic / Hospital']}, ${doc['City']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Contact: ${doc['Phone Number']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  if (doc['Address'] != null &&
                                      doc['Address'].toString().isNotEmpty)
                                    Text(
                                      'Address: ${doc['Address']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  Divider(
                                    color: Colors.grey.shade300,
                                    height: 16,
                                    thickness: 1,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    color: primaryDark,
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
                          text:
                              'This analysis is not a substitute for professional medical care. Always consult a qualified healthcare provider for diagnosis and treatment, especially before taking any medication.',
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
                  ]
                      .map(
                        (symptom) => GestureDetector(
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
                        ),
                      )
                      .toList(),
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
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: primaryLight,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'For accurate results: Describe symptom duration, severity, location, and any accompanying symptoms.',
                          style: TextStyle(color: secondaryDark, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
            ? Border.all(color: secondary.withOpacity(0.3), width: 1.5)
            : null,
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
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