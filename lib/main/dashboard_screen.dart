import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:health_assistant/main/ai_chatbot.dart';
import 'package:health_assistant/main/health_log_screen.dart';
import 'package:health_assistant/main/medicineReminder.dart';
import 'package:health_assistant/main/profile_screen.dart';
import 'package:health_assistant/main/reportScanner.dart';
import 'package:health_assistant/main/report_generation_screen.dart';
import 'package:health_assistant/main/step_counter.dart';
import 'package:health_assistant/main/symptom_input_screen.dart';
import 'package:health_assistant/main/voice_assistant.dart';
import 'package:health_assistant/main/wellness_tips_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Color Scheme
  final Color primaryDark = const Color(0xFF03045E);
  final Color primary = const Color(0xFF0077B6);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentLight = const Color(0xFF90E0EF);
  final Color secondaryDark = const Color(0xFF05668D);
  final Color secondary = const Color(0xFF028090);
  final Color highlight = const Color(0xFFF0F3BD);
  final Color accent = const Color(0xFF02C39A);

  // Health summary data
  String _heartRate = '--';
  String _bloodPressure = '--/--';
  String _temperature = '--';
  String _healthStatus = 'Loading...';
  Color _healthStatusColor = Colors.grey;
  bool _isLoadingHealthData = true;

  @override
  void initState() {
    super.initState();
    _fetchLatestHealthData();
  }

  Future<void> _fetchLatestHealthData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('health_logs')
              .where(
                'user_id',
                isEqualTo: FirebaseAuth.instance.currentUser?.uid,
              ) // Add this line
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          _heartRate = data['heart_rate']?.toString() ?? '--';
          _bloodPressure = data['blood_pressure']?.toString() ?? '--/--';
          _temperature = data['temperature']?.toString() ?? '--';
          _updateHealthStatus(data);
          _isLoadingHealthData = false;
        });
      } else {
        setState(() {
          _healthStatus = 'No Data';
          _healthStatusColor = Colors.grey;
          _isLoadingHealthData = false;
        });
      }
    } catch (e) {
      print('Error fetching health data: $e');
      setState(() {
        _healthStatus = 'Error';
        _healthStatusColor = Colors.red;
        _isLoadingHealthData = false;
      });
    }
  }

  void _updateHealthStatus(Map<String, dynamic> data) {
    int abnormalCount = 0;

    // Analyze heart rate
    final heartRate = int.tryParse(data['pulse']?.toString() ?? '0') ?? 0;
    if (heartRate < 60 || heartRate > 100) abnormalCount++;

    // Analyze blood pressure
    final bp = data['blood_pressure']?.toString() ?? '0/0';
    final bpParts = bp.split('/');
    if (bpParts.length == 2) {
      final systolic = int.tryParse(bpParts[0]) ?? 0;
      final diastolic = int.tryParse(bpParts[1]) ?? 0;

      if (systolic > 140 || diastolic > 90 || systolic < 90 || diastolic < 60) {
        abnormalCount++;
      }
    }

    // Analyze temperature
    final temp = double.tryParse(data['temperature']?.toString() ?? '0') ?? 0;
    if (temp < 36.1 || temp > 37.2) abnormalCount++;

    // Determine overall status
    if (abnormalCount == 0) {
      _healthStatus = 'Excellent';
      _healthStatusColor = Colors.green;
    } else if (abnormalCount == 1) {
      _healthStatus = 'Good';
      _healthStatusColor = Colors.lightGreen;
    } else if (abnormalCount == 2) {
      _healthStatus = 'Fair';
      _healthStatusColor = Colors.orange;
    } else {
      _healthStatus = 'Needs Attention';
      _healthStatusColor = Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MediCheck AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryDark,
        elevation: 0,

        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
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
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHealthSummaryCard(context),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Health Services',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(height: 15),
              _buildServicesGrid(isLandscape),
              SizedBox(height: 25),
              _buildAIAssistantCard(context),
              SizedBox(height: 15),
              _buildVoiceAssistantCard(context),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryDark,
        child: Icon(Icons.chat, color: Colors.white, size: 30),
        onPressed: () {
          _showAIChatBottomSheet(context);
        },
      ),
    );
  }

  Widget _buildServicesGrid(bool isLandscape) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isLandscape ? 3 : 2;
        final childAspectRatio = isLandscape ? 1.2 : 1.0;

        return GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            _buildDashboardCard(
              context: context,
              title: 'Symptom Checker',
              icon: Icons.medical_services,
              color: primary,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SymptomInputScreen(),
                    ),
                  ),
            ),
            _buildDashboardCard(
              context: context,
              title: 'Health Log',
              icon: Icons.monitor_heart,
              color: secondary,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HealthLogScreen()),
                  ),
            ),
            _buildDashboardCard(
              context: context,
              title: 'Wellness Tips',
              icon: Icons.spa,
              color: accent,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WellnessTipsScreen(),
                    ),
                  ),
            ),
            // _buildDashboardCard(
            //   context: context,
            //   title: 'Generate Report',
            //   icon: Icons.insert_chart,
            //   color: secondaryDark,
            //   onTap: () => Navigator.push(
            //     context,
            //     MaterialPageRoute(
            //       builder: (context) => ReportGenerationScreen(),
            //     ),
            //   ),
            // ),
            _buildDashboardCard(
              context: context,
              title: 'Document Scanner',
              icon: Icons.document_scanner,
              color: Color(0xFF6A4C93),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ReportScanner()),
                  ),
            ),
            _buildDashboardCard(
              context: context,
              title:
                  'Set Reminder', // Changed from 'Voice Assistant' to 'Set Reminder'
              icon:
                  Icons
                      .notifications, // Changed from Icons.mic to Icons.notifications
              color: Color(
                0xFF4A6FA5,
              ), // You can change the color if needed (e.g., Colors.red for urgency)
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MedicineReminderScreen(),
                  ),
                );
              },
            ),
            _buildDashboardCard(
              context: context,
              title: 'Steps Counter',
              icon:
                  Icons
                      .directions_walk, // Changed to an appropriate icon for steps counter
              color: Color.fromARGB(
                255,
                42,
                132,
                143,
              ), // You can change the color if needed
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StepsCounterScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHealthSummaryCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
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
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Health Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _healthStatusColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _healthStatusColor, width: 1),
                ),
                child: Text(
                  _healthStatus,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _isLoadingHealthData
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHealthMetric(
                    icon: Icons.favorite,
                    value: _heartRate,
                    unit: 'bpm',
                    label: 'Heart Rate',
                    color: _getMetricColor(_heartRate, 60, 100),
                  ),
                  _buildHealthMetric(
                    icon: Icons.speed,
                    value: _bloodPressure,
                    unit: 'mmHg',
                    label: 'Blood Pressure',
                    color: _getBpColor(_bloodPressure),
                  ),
                  _buildHealthMetric(
                    icon: Icons.fitness_center,
                    value: _temperature,
                    unit: '°C',
                    label: 'Temperature',
                    color: _getMetricColor(
                      _temperature,
                      36.1,
                      37.2,
                      isDouble: true,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Color _getMetricColor(
    String value,
    num min,
    num max, {
    bool isDouble = false,
  }) {
    if (value == '--') return Colors.grey;

    try {
      final numVal = isDouble ? double.parse(value) : int.parse(value);
      if (numVal < min || numVal > max) {
        return Colors.red.shade100;
      }
      return Colors.green.shade100;
    } catch (e) {
      return Colors.grey;
    }
  }

  Color _getBpColor(String bp) {
    if (bp == '--/--') return Colors.grey;

    final parts = bp.split('/');
    if (parts.length != 2) return Colors.grey;

    try {
      final systolic = int.parse(parts[0]);
      final diastolic = int.parse(parts[1]);

      if (systolic > 140 || diastolic > 90) return Colors.red.shade100;
      if (systolic < 90 || diastolic < 60) return Colors.orange.shade100;
      return Colors.green.shade100;
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildHealthMetric({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(icon, color: color, size: 30)),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAssistantCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAIChatBottomSheet(context),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, primaryLight],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Health Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Chat with our AI for health advice and symptom analysis',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white, size: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAssistantCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => VoiceMedicalAssistant()),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, Color(0xFF02C39A).withOpacity(0.8)],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic, color: Colors.white, size: 24),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Talk to our voice assistant for hands-free health support',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white, size: 30),
          ],
        ),
      ),
    );
  }

  void _showAIChatBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MedicalAIChatScreen(),
    );
  }
}
