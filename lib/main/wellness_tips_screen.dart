import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WellnessTipsScreen extends StatelessWidget {
  // Define theme colors based on provided palette
  final Color primaryDark = const Color(0xFF03045E);
  final Color primary = const Color(0xFF0077B6);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color secondaryDark = const Color(0xFF05668D);
  final Color secondary = const Color(0xFF028090);
  final Color accentLight = const Color(0xFF90E0EF);
  final Color accent = const Color(0xFF02C39A);
  final Color highlight = const Color(0xFFF0F3BD);

  final List<Map<String, dynamic>> wellnessCategories = [
    {
      'title': 'Nutrition',
      'icon': 'assets/nutrition.svg',
      'color': const Color(0xFF0077B6), // Using primary color
      'tips': [
        'Eat 5 servings of fruits and vegetables daily',
        'Stay hydrated - drink at least 8 glasses of water',
        'Limit processed foods and added sugars',
        'Include lean proteins in every meal',
        'Choose whole grains over refined grains'
      ]
    },
    {
      'title': 'Exercise',
      'icon': 'assets/exercise.svg',
      'color': const Color(0xFF028090), // Using secondary color
      'tips': [
        'Aim for 150 minutes of moderate exercise weekly',
        'Include strength training 2-3 times per week',
        'Take short movement breaks every hour',
        'Try yoga or stretching for flexibility',
        'Walk 10,000 steps daily'
      ]
    },
    {
      'title': 'Sleep',
      'icon': 'assets/sleep.svg',
      'color': const Color(0xFF00B4D8), // Using primaryLight
      'tips': [
        'Maintain consistent sleep schedule',
        'Create a relaxing bedtime routine',
        'Aim for 7-9 hours of quality sleep',
        'Avoid screens 1 hour before bedtime',
        'Keep bedroom cool and dark'
      ]
    },
    {
      'title': 'Stress Management',
      'icon': 'assets/stress.svg',
      'color': const Color(0xFF02C39A), // Using accent color
      'tips': [
        'Practice deep breathing exercises',
        'Try 10-minute daily meditation',
        'Maintain work-life balance',
        'Connect with loved ones regularly',
        'Engage in hobbies you enjoy'
      ]
    },
    {
      'title': 'Mental Wellness',
      'icon': 'assets/mind.svg',
      'color': const Color(0xFF90E0EF), // Using accentLight
      'tips': [
        'Practice gratitude daily',
        'Challenge negative thoughts',
        'Set realistic goals',
        'Take breaks when needed',
        'Seek professional help if struggling'
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: accentLight.withOpacity(0.3), // Light background using accentLight
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Wellness Tips',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryDark, // Using primaryDark for app bar
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
              color: primary.withOpacity(0.1), // Using primary color with opacity
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.health_and_safety, size: 40, color: primary),
                    SizedBox(height: 10),
                    Text(
                      'Daily Wellness Guide',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Small daily habits lead to big health improvements',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: secondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            
            // Categories List
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: wellnessCategories.length,
              itemBuilder: (context, index) {
                return _buildCategoryCard(
                  context,
                  wellnessCategories[index]['title'],
                  wellnessCategories[index]['icon'],
                  wellnessCategories[index]['color'],
                  wellnessCategories[index]['tips'],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, String title, String icon, Color color, List<String> tips) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: SvgPicture.asset(
              icon,
              height: 24,
              color: color,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryDark, // Using primaryDark for text
          ),
        ),
        trailing: Icon(
          Icons.expand_more,
          color: primary, // Using primary color for icon
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tips
                  .map((tip) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.fiber_manual_record,
                                size: 12, color: color),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size(double.infinity, 40),
              ),
              onPressed: () {
                // Action for "Learn More" button
              },
              child: Text('Learn More'),
            ),
          ),
        ],
      ),
    );
  }
}