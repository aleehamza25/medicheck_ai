import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health_assistant/main/dashboard_screen.dart';
import 'package:health_assistant/welcome/login_screen.dart';

class LocationPermissionScreen extends StatefulWidget {
  @override
  _LocationPermissionScreenState createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with SingleTickerProviderStateMixin {
  bool _isLocationServiceEnabled = false;
  bool _isPermissionGranted = false;
  bool _isLocationLoading = false;

  // Color Scheme matching your splash screen
  final Color primaryDark = const Color(0xFF03045E);
  final Color primary = const Color(0xFF0077B6);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentLight = const Color(0xFF90E0EF);
  final Color secondaryDark = const Color(0xFF05668D);
  final Color secondary = const Color(0xFF028090);
  final Color highlight = const Color(0xFFF0F3BD);
  final Color accent = const Color(0xFF02C39A);

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    setState(() {
      _isLocationLoading = true;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLocationServiceEnabled = false;
        _isLocationLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    setState(() {
      _isLocationLoading = false;
      _isPermissionGranted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    });

    if (_isPermissionGranted) {
      await Future.delayed(const Duration(milliseconds: 3000));
      _checkAuthState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryLight, primary, primaryDark],
                stops: const [0.1, 0.5, 0.9],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child:
                    _isLocationLoading
                        ? _buildLoadingUI()
                        : FadeTransition(
                          opacity: _fadeInAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              ScaleTransition(
                                scale: _scaleAnimation,
                                child: Text(
                                  'Location Access',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                    shadows: [
                                      Shadow(
                                        color: primaryDark.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We need your location to provide personalized health recommendations',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              SizedBox(height: 40),
                              Center(
                                child: ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: Container(
                                    padding: const EdgeInsets.all(25),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryDark.withOpacity(0.3),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/svg/location.svg',
                                      width: 100,
                                      height: 100,
                                      color: Colors.white.withOpacity(0.95),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                              if (!_isPermissionGranted) ...[
                                _buildPermissionDeniedUI(),
                              ] else ...[
                                _buildPermissionGrantedUI(),
                              ],
                              const Spacer(),
                              if (!_isPermissionGranted)
                                _buildActionButton(
                                  text: 'Allow Location Access',
                                  onPressed: () async {
                                    LocationPermission permission =
                                        await Geolocator.requestPermission();
                                    if (permission ==
                                            LocationPermission.whileInUse ||
                                        permission ==
                                            LocationPermission.always) {
                                      setState(() {
                                        _isPermissionGranted = true;
                                      });
                                      _checkAuthState();
                                    }
                                  },
                                ),
                              if (_isPermissionGranted)
                                _buildActionButton(
                                  text: 'Continue',
                                  onPressed: _checkAuthState,
                                ),
                            ],
                          ),
                        ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryDark.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SvgPicture.asset(
              'assets/svg/location.svg',
              width: 80,
              height: 80,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Checking location services...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.8),
              ),
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedUI() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: highlight),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Location access is required for full functionality',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            icon: Icons.location_pin,
            text: 'Get accurate health recommendations based on your location',
          ),
          _buildFeatureItem(
            icon: Icons.medical_services,
            text: 'Find nearby healthcare providers when needed',
          ),
          _buildFeatureItem(
            icon: Icons.warning,
            text: 'Enable emergency location services for critical situations',
          ),
          const SizedBox(height: 20),
          Text(
            'Your location data is encrypted and never shared with third parties.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionGrantedUI() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.4), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: highlight),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Location access granted! You can change this anytime in settings.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Ready to get started with personalized health recommendations!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: primaryDark,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: primaryDark.withOpacity(0.3),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkAuthState() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => LoginScreen()));
    }
  }
}
