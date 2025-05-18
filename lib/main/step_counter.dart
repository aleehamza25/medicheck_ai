import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _isLoading = false;
  int _currentSteps = 0;
  int _todaySteps = 0;
  String _currentDate = '';
  late StreamSubscription<StepCount> _stepCountSubscription;
  late StreamSubscription<PedestrianStatus> _pedestrianStatusSubscription;
  String _status = 'Waiting for steps...';
  DateTime? _lastUpdated;
  int _lastStoredSteps = 0; // Track last stored steps to calculate difference

  // History variables
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _recentEntries = [];
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _perPage = 5;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _initStepsCounter();
    _loadInitialEntries();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _stepCountSubscription.cancel();
    _pedestrianStatusSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initStepsCounter() async {
    setState(() => _isLoading = true);
    
    try {
      // Check and request permissions
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        _showError("Activity recognition permission is required to count steps");
        return;
      }

      // Initialize step stream
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepError,
      );

      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatusChanged,
        onError: _onStepError,
      );

      // Load today's steps from Firestore
      await _loadTodaySteps();
    } catch (e) {
      _showError("Failed to initialize step counter: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onStepCount(StepCount event) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    
    setState(() {
      _lastUpdated = now;
      _currentSteps = event.steps.toInt(); // Explicit conversion to int
      
      // Reset if it's a new day
      if (today != _currentDate) {
        _currentDate = today;
        _todaySteps = 0;
        _lastStoredSteps = 0;
      }
    });

    _updateTodaySteps();
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    setState(() {
      _status = event.status;
    });
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
          _todaySteps = (doc['steps'] as num).toInt(); // Ensure int type
          _lastStoredSteps = _todaySteps;
        });
      }
    } catch (e) {
      _showError('Error loading today\'s steps: $e');
    }
  }

  Future<void> _updateTodaySteps() async {
    if (_currentUser == null) return;

    try {
      // Calculate the difference since last update
      final stepsDifference = _currentSteps - _lastStoredSteps;
      
      // Only update if there's a significant change (to prevent too many writes)
      if (stepsDifference.abs() > 5) {
        final newSteps = _todaySteps + stepsDifference;
        
        await FirebaseFirestore.instance
            .collection('steps_logs')
            .doc('${_currentUser!.uid}_$_currentDate')
            .set({
          'steps': newSteps,
          'date': _currentDate,
          'timestamp': FieldValue.serverTimestamp(),
          'user_id': _currentUser!.uid,
        }, SetOptions(merge: true));

        setState(() {
          _todaySteps = newSteps;
          _lastStoredSteps = _currentSteps;
        });
      }
    } catch (e) {
      print('Error updating steps: $e');
    }
  }

  Future<void> _loadInitialEntries() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final query = FirebaseFirestore.instance
          .collection('steps_logs')
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
          .collection('steps_logs')
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.directions_walk, 'Today', '$_todaySteps'),
          _buildStatItem(Icons.calendar_view_week, 'Avg Weekly', 'Calculating...'),
          _buildStatItem(Icons.emoji_events, 'Record', 'Loading...'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 30, color: primaryColor),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentEntriesList() {
    if (_isLoading) {
      return _buildShimmerLoader();
    }

    if (_recentEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No step history yet. Start walking to record your steps!',
            style: TextStyle(color: Colors.grey),
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
    final date = entry['date'] ?? '';
    final steps = (entry['steps'] as num).toInt(); // Ensure int type
    final progress = steps / 10000;

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
                  date,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$steps steps',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress > 1 ? 1 : progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(primaryLight),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}% of goal',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (progress >= 1)
                  Icon(Icons.check_circle, color: accentColor, size: 16),
              ],
            ),
          ],
        ),
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
            margin: EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
        title: Text('Step Counter', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTodaySteps();
          await _loadInitialEntries();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildStepCounterCard(),
              SizedBox(height: 24),
              _buildStatsRow(),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1),
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'YOUR STEP HISTORY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildRecentEntriesList(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}