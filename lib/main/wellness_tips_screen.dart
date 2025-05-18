import 'package:flutter/material.dart';

class WellnessTipsScreen extends StatelessWidget {
  // Define theme colors based on HealthLogScreen palette
  final Color primaryColor = const Color(0xFF03045E);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentColor = const Color(0xFF02C39A);
  final Color backgroundColor = Colors.white;
  final Color accentLight = const Color(0xFF90E0EF);

  final List<Map<String, dynamic>> wellnessCategories = [
    {
      'title': 'Nutrition',
      'icon': Icons.restaurant,
      'color': const Color(0xFF00B4D8), // Using primaryLight
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
      'icon': Icons.directions_run,
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
      'icon': Icons.bedtime,
      'color': const Color(0xFF03045E), // Using primaryDark
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
      'icon': Icons.self_improvement,
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
      'icon': Icons.psychology,
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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Wellness Tips',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
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
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [accentLight.withOpacity(0.3), primaryLight.withOpacity(0.3)],
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
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.health_and_safety, 
                            size: 40, 
                            color: primaryColor),
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Daily Wellness Guide',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Small daily habits lead to big health improvements. '
                        'Explore tips to enhance your wellbeing in different areas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: primaryColor.withOpacity(0.8),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 25),
              
              // Section title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Wellness Categories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              SizedBox(height: 15),
              
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
      ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, String title, IconData icon, Color color, List<String> tips) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: primaryColor,
            ),
          ),
          trailing: Icon(
            Icons.expand_more,
            color: primaryColor,
            size: 28,
          ),
          children: [
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.grey.shade200,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tips
                    .map((tip) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: 5),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade800,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 50),
                  elevation: 0,
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  // Action for "Learn More" button
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Learn More'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}