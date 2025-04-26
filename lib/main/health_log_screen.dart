import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class HealthLogScreen extends StatefulWidget {
  @override
  _HealthLogScreenState createState() => _HealthLogScreenState();
}

class _HealthLogScreenState extends State<HealthLogScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _recentEntries = [];
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _perPage = 5;
  DocumentSnapshot? _lastDocument;

  // Controllers for all health metrics
  final _weightController = TextEditingController();
  final _bpController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _waterIntakeController = TextEditingController();
  final _sleepController = TextEditingController();
  final _moodController = TextEditingController();
  final _notesController = TextEditingController();

  // Define theme colors matching your design
  final Color primaryColor = Color(0xFF0A4DA3); // Dark blue
  final Color accentColor = Color(0xFF1DB9C3); // Teal
  final Color backgroundColor = Color(0xFFF5F9FF); // Very light blue
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _loadInitialEntries();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bpController.dispose();
    _glucoseController.dispose();
    _temperatureController.dispose();
    _waterIntakeController.dispose();
    _sleepController.dispose();
    _moodController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialEntries() async {
    setState(() => _isLoading = true);
    try {
      final query = FirebaseFirestore.instance
          .collection('health_logs')
          .orderBy('timestamp', descending: true)
          .limit(_perPage);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      setState(() {
        _recentEntries = snapshot.docs;
        _hasMore = snapshot.docs.length == _perPage;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading entries: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreEntries() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final query = FirebaseFirestore.instance
          .collection('health_logs')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_perPage);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      setState(() {
        _recentEntries.addAll(snapshot.docs);
        _hasMore = snapshot.docs.length == _perPage;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading more entries: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      _loadMoreEntries();
    }
  }

  Future<void> _submitHealthData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        await FirebaseFirestore.instance.collection('health_logs').add({
          'weight': _weightController.text,
          'blood_pressure': _bpController.text,
          'glucose': _glucoseController.text,
          'temperature': _temperatureController.text,
          'water_intake': _waterIntakeController.text,
          'sleep': _sleepController.text,
          'mood': _moodController.text,
          'notes': _notesController.text,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'timestamp': FieldValue.serverTimestamp(),
          'user_id': 'current_user_id', // Replace with actual user ID
        });

        // Clear all fields after successful submission
        _weightController.clear();
        _bpController.clear();
        _glucoseController.clear();
        _temperatureController.clear();
        _waterIntakeController.clear();
        _sleepController.clear();
        _moodController.clear();
        _notesController.clear();

        // Refresh the recent entries
        await _loadInitialEntries();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Health data saved successfully!'),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildMetricInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: primaryColor,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: primaryColor),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: accentColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: cardColor,
          helperText: helperText,
          helperStyle: TextStyle(color: Colors.grey.shade600),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(3, (index) => 
          Container(
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            height: 100,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentEntriesList() {
    if (_recentEntries.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No entries yet. Log your first health data!',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _recentEntries.length,
          itemBuilder: (context, index) {
            var doc = _recentEntries[index];
            var data = doc.data() as Map<String, dynamic>;
            
            return Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['date'] ?? 'No date',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (data['weight'] != null && data['weight'].isNotEmpty)
                          _buildMetricChip('${data['weight']} kg', Icons.monitor_weight),
                        if (data['blood_pressure'] != null && data['blood_pressure'].isNotEmpty)
                          _buildMetricChip(data['blood_pressure'], Icons.favorite),
                        if (data['glucose'] != null && data['glucose'].isNotEmpty) 
                          _buildMetricChip('${data['glucose']} mg/dL', Icons.bloodtype),
                        if (data['temperature'] != null && data['temperature'].isNotEmpty) 
                          _buildMetricChip('${data['temperature']}°C', Icons.thermostat),
                        if (data['mood'] != null && data['mood'].isNotEmpty) 
                          _buildMetricChip('Mood: ${data['mood']}/10', Icons.mood),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_isLoadingMore)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Daily Health Log', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF03045E),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        // shape: RoundedRectangleBorder(
        //   borderRadius: BorderRadius.vertical(
        //     bottom: Radius.circular(20),
        //   ),
        // ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Track Your Health Metrics',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Enter your daily health measurements',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 20),
              
              // Weight Input
              _buildMetricInput(
                label: 'Weight (kg)',
                hint: 'Enter your weight',
                controller: _weightController,
                icon: Icons.monitor_weight,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter weight';
                  if (double.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
                keyboardType: TextInputType.number,
              ),
              
              // Blood Pressure Input
              _buildMetricInput(
                label: 'Blood Pressure (mmHg)',
                hint: 'e.g. 120/80',
                controller: _bpController,
                icon: Icons.favorite_border,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter BP';
                  if (!RegExp(r'^\d{2,3}\/\d{2,3}$').hasMatch(value)) {
                    return 'Format: XXX/XX';
                  }
                  return null;
                },
                helperText: 'Format: Systolic/Diastolic',
              ),
              
              // Glucose Input
              _buildMetricInput(
                label: 'Blood Glucose (mg/dL)',
                hint: 'Enter glucose level',
                controller: _glucoseController,
                icon: Icons.bloodtype,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter glucose';
                  if (int.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
                keyboardType: TextInputType.number,
              ),
              
              // Temperature Input
              _buildMetricInput(
                label: 'Temperature (°C)',
                hint: 'Enter body temperature',
                controller: _temperatureController,
                icon: Icons.thermostat,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter temp';
                  if (double.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
                keyboardType: TextInputType.number,
              ),
              
              // Water Intake Input
              _buildMetricInput(
                label: 'Water Intake (L)',
                hint: 'Enter water consumed',
                controller: _waterIntakeController,
                icon: Icons.local_drink,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter amount';
                  if (double.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
                keyboardType: TextInputType.number,
              ),
              
              // Sleep Input
              _buildMetricInput(
                label: 'Sleep (hours)',
                hint: 'Enter sleep duration',
                controller: _sleepController,
                icon: Icons.bedtime,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter hours';
                  if (double.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
                keyboardType: TextInputType.number,
              ),
              
              // Mood Input
              _buildMetricInput(
                label: 'Mood (1-10)',
                hint: 'Rate your mood',
                controller: _moodController,
                icon: Icons.mood,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please rate mood';
                  final num = int.tryParse(value);
                  if (num == null || num < 1 || num > 10) {
                    return 'Enter number 1-10';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
              ),
              
              // Notes Input
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  cursorColor: primaryColor,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    labelStyle: TextStyle(color: primaryColor),
                    hintText: 'Any additional notes...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.note, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: cardColor,
                  ),
                ),
              ),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _submitHealthData,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('SAVE DAILY LOG', style: TextStyle(fontSize: 16)),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Recent Entries Section
              Text(
                'Recent Entries',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 10),
              _isLoading 
                  ? _buildShimmerLoader()
                  : _buildRecentEntriesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip(String text, IconData icon) {
    return Chip(
      backgroundColor: accentColor.withOpacity(0.1),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primaryColor),
          SizedBox(width: 4),
          Text(text, style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}