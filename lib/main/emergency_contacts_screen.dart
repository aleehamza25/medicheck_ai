import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> emergencyContacts = [
    {
      'name': 'Emergency Medical',
      'number': '911',
      'icon': Icons.local_hospital,
      'color': Colors.red
    },
    {
      'name': 'Poison Control',
      'number': '1-800-222-1222',
      'icon': Icons.warning,
      'color': Colors.orange
    },
    {
      'name': 'Mental Health',
      'number': '1-800-273-8255',
      'icon': Icons.psychology,
      'color': Colors.blue
    },
    {
      'name': 'Suicide Prevention',
      'number': '988',
      'icon': Icons.health_and_safety,
      'color': Colors.purple
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency Contacts'),
        backgroundColor: Colors.red.shade700,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              color: Colors.red.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 50, color: Colors.red),
                    SizedBox(height: 10),
                    Text(
                      'For life-threatening emergencies, call 911 immediately',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: emergencyContacts.length,
              itemBuilder: (context, index) {
                return _buildContactCard(
                  context,
                  emergencyContacts[index]['name'],
                  emergencyContacts[index]['number'],
                  emergencyContacts[index]['icon'],
                  emergencyContacts[index]['color'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, String name, String number,
      IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(number),
        trailing: IconButton(
          icon: Icon(Icons.phone, color: Colors.green),
          onPressed: () => _makePhoneCall(number),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $phoneNumber';
    }
  }
}