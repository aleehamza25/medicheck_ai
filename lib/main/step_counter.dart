import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepsCounterScreen extends StatefulWidget {
  @override
  _StepsCounterScreenState createState() => _StepsCounterScreenState();
}

class _StepsCounterScreenState extends State<StepsCounterScreen> {
  // Color scheme
  final Color primaryColor = const Color(0xFF03045E);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentColor = const Color(0xFF02C39A);
  final Color backgroundColor = Colors.white;
  final Color textColor = Colors.black87;
  final Color accentLight = Color(0xFF90E0EF);
  final Color primaryDark = const Color(0xFF03045E);
  final Color primary = const Color(0xFF0077B6);

  // Firebase and state variables
  User? _currentUser;
  bool _isLoading = true; // Initialize as true to show loader initially
  int _todaySteps = 0;
  String _currentDate = '';
  late StreamSubscription<StepCount> _stepCountSubscription;
  String _status = 'Initializing...';
  DateTime? _lastUpdated;
  bool _isSyncing = false;

  // For tracking steps since midnight
  int _stepsAtMidnight = 0;
  bool _gotInitialSteps = false;
  bool _initializationComplete = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _initStepsCounter();
      await _checkDailyReset();
    } catch (e) {
      _showError("Initialization failed: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
        _initializationComplete = true;
      });
    }
  }

  @override
  void dispose() {
    _stepCountSubscription.cancel();
    super.dispose();
  }

  Future<void> _initStepsCounter() async {
    // Check and request permissions
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      throw Exception("Activity recognition permission denied");
    }

    // Initialize step stream
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepError,
    );

    // Load today's steps from Firestore
    await _loadTodaySteps();
  }

  Future<void> _checkDailyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDate = prefs.getString('lastResetDate');
    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastResetDate != currentDate) {
      // New day - reset steps
      final initialSteps = await Pedometer.stepCountStream.first;
      await prefs.setString('lastResetDate', currentDate);
      setState(() {
        _stepsAtMidnight = initialSteps.steps;
        _todaySteps = 0;
        _gotInitialSteps = true;
        _status = 'Ready';
      });
      await _updateTodaySteps();
    } else if (!_gotInitialSteps) {
      // Not a new day, but we need initial steps
      final initialSteps = await Pedometer.stepCountStream.first;
      setState(() {
        _stepsAtMidnight = initialSteps.steps - _todaySteps;
        _gotInitialSteps = true;
        _status = 'Ready';
      });
    }
  }

  void _onStepCount(StepCount event) {
    if (!_gotInitialSteps) return;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    
    // Calculate steps taken since midnight
    final currentStepsSinceMidnight = event.steps - _stepsAtMidnight;
    
    // Ensure steps can't be negative
    final todaySteps = currentStepsSinceMidnight > 0 ? currentStepsSinceMidnight : 0;

    setState(() {
      _lastUpdated = now;
      _todaySteps = todaySteps;
      _status = 'Counting steps...';
      
      // Reset if it's a new day
      if (today != _currentDate) {
        _currentDate = today;
        _todaySteps = 0;
        _stepsAtMidnight = event.steps;
        _checkDailyReset();
      }
    });

    _updateTodaySteps();
  }

  void _onStepError(error) {
    print('Step counter error: $error');
    setState(() {
      _status = 'Error: ${error.toString()}';
    });
  }

  Future<void> _loadTodaySteps() async {
    if (_currentUser == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('steps_logs')
          .doc('${_currentUser!.uid}_$_currentDate')
          .get();

      if (doc.exists) {
        setState(() {
          _todaySteps = (doc['steps'] as num).toInt();
        });
      }
    } catch (e) {
      _showError('Error loading today\'s steps: $e');
    }
  }

  Future<void> _updateTodaySteps() async {
    if (_currentUser == null || _isSyncing) return;

    setState(() => _isSyncing = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('steps_logs')
          .doc('${_currentUser!.uid}_$_currentDate')
          .set({
        'steps': _todaySteps,
        'date': _currentDate,
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': _currentUser!.uid,
        'formatted_date': DateFormat('MMMM d, y').format(DateTime.now()),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating steps: $e');
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStepCounterCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryDark, primary],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5)),
          ],
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'TODAY\'S STEPS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '$_todaySteps',
              style: TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              _status,
              style: TextStyle(color: Colors.white70),
            ),
            if (_lastUpdated != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Last updated: ${DateFormat('h:mm a').format(_lastUpdated!)}',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            SizedBox(height: 20),
            LinearProgressIndicator(
              value: _todaySteps / 10000,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
            SizedBox(height: 10),
            Text(
              '${(_todaySteps / 10000 * 100).toStringAsFixed(1)}% of daily goal',
              style: TextStyle(color: Colors.white),
            ),
            if (_isSyncing)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Syncing...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Step Counter', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _initializeApp();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Initializing step counter...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _initializeApp();
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildStepCounterCard(),
                    SizedBox(height: 20),
                    if (!_gotInitialSteps && !_isLoading)
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}