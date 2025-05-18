import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Controllers for health metrics
  final _weightController = TextEditingController();
  final _bpController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _notesController = TextEditingController();

  // Color scheme based on primary color
  final Color primaryColor = const Color(0xFF03045E);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentColor = const Color(0xFF02C39A);
  final Color backgroundColor = Colors.white;
  final Color textColor = Colors.black87;
  final Color accentLight = Color(0xFF90E0EF);

  // Current user
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadInitialEntries();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bpController.dispose();
    _glucoseController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialEntries() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final query = FirebaseFirestore.instance
          .collection('health_logs')
          .where('user_id', isEqualTo: _currentUser!.uid)
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
      _showError('Error loading entries: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreEntries() async {
    if (_currentUser == null || !_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final query = FirebaseFirestore.instance
          .collection('health_logs')
          .where('user_id', isEqualTo: _currentUser!.uid)
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
      _showError('Error loading more entries: $e');
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
    if (_currentUser == null) {
      _showError('Not authenticated');
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await FirebaseFirestore.instance.collection('health_logs').add({
          'weight': _weightController.text,
          'blood_pressure': _bpController.text,
          'glucose': _glucoseController.text,
          'notes': _notesController.text,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'timestamp': FieldValue.serverTimestamp(),
          'user_id': _currentUser!.uid,
        });

        // Clear fields
        _weightController.clear();
        _bpController.clear();
        _glucoseController.clear();
        _notesController.clear();

        // Refresh entries
        await _loadInitialEntries();

        _showSuccess('Health data saved!');
      } catch (e) {
        _showError('Error saving data: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: accentColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true, // This property enables the background color
          fillColor: Colors.white, // Set the background color to white
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildRecentEntriesList() {
    if (_isLoading) {
      return _buildShimmerLoader();
    }

    if (_recentEntries.isEmpty) {
      return Center(
        child: Text(
          'No entries yet. Add your first health log!',
          style: TextStyle(color: Colors.grey),
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
            final entry = _recentEntries[index].data() as Map<String, dynamic>;
            return _buildEntryCard(entry);
          },
        ),
        if (_isLoadingMore)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry['date'] ?? 'No date',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 16,
                  ),
                ),
                Icon(Icons.calendar_today, size: 16, color: primaryColor),
              ],
            ),
            SizedBox(height: 10),
            if (entry['weight'] != null)
              _buildMetricRow(
                'Weight',
                '${entry['weight']} kg',
                Icons.monitor_weight,
              ),
            if (entry['blood_pressure'] != null)
              _buildMetricRow(
                'Blood Pressure',
                entry['blood_pressure'],
                Icons.favorite,
              ),
            if (entry['glucose'] != null)
              _buildMetricRow(
                'Glucose',
                '${entry['glucose']} mg/dL',
                Icons.bloodtype,
              ),
            if (entry['notes'] != null && entry['notes'].isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Notes: ${entry['notes']}',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryColor),
          SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('My Health Logs', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
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
          controller: _scrollController,
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  'Daily Health Check',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 20),

                // Health metrics form
                _buildInputField(
                  label: 'Weight (kg)',
                  hint: 'Enter your weight',
                  controller: _weightController,
                  icon: Icons.monitor_weight,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                  keyboardType: TextInputType.number,
                ),

                _buildInputField(
                  label: 'Blood Pressure',
                  hint: 'e.g. 120/80',
                  controller: _bpController,
                  icon: Icons.favorite,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),

                _buildInputField(
                  label: 'Glucose (mg/dL)',
                  hint: 'Enter glucose level',
                  controller: _glucoseController,
                  icon: Icons.bloodtype,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                  keyboardType: TextInputType.number,
                ),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Any additional notes...',
                    prefixIcon: Icon(Icons.notes, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true, // Enables the background color
                    fillColor:
                        Colors.white, // Sets the background color to white
                  ),
                ),

                SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submitHealthData,
                    child:
                        _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                              'SAVE LOG',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),

                SizedBox(height: 30),

                // Recent Entries Section
                Text(
                  'Your Recent Entries',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 16),
                _buildRecentEntriesList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
