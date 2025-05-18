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
  bool _isLoading = true;
  bool _isRequestingPermission = false;

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
    _initLocationCheck();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initLocationCheck() async {
    // First check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    if (!serviceEnabled) {
      setState(() {
        _isLocationServiceEnabled = false;
        _isLoading = false;
      });
      return;
    }

    // Then check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    setState(() {
      _isPermissionGranted = permission == LocationPermission.whileInUse || 
                            permission == LocationPermission.always;
      _isLoading = false;
    });

    // If permission already granted, proceed after delay
    if (_isPermissionGranted) {
      _proceedAfterPermission();
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isRequestingPermission = true;
    });

    LocationPermission permission = await Geolocator.requestPermission();
    
    setState(() {
      _isPermissionGranted = permission == LocationPermission.whileInUse || 
                           permission == LocationPermission.always;
      _isRequestingPermission = false;
    });

    if (_isPermissionGranted) {
      _proceedAfterPermission();
    }
  }

  void _proceedAfterPermission() {
    // Wait 2 seconds then navigate
    Future.delayed(const Duration(seconds: 2), () {
      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
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
                    const SizedBox(height: 40),
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
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeInAnimation,
                        child: _isLoading
                            ? _buildLoadingUI()
                            : _isPermissionGranted
                                ? _buildPermissionGrantedUI()
                                : _buildPermissionDeniedUI(),
                      ),
                    ),
                    if (!_isPermissionGranted && !_isLoading)
                      _buildActionButton(
                        isLoading: _isRequestingPermission,
                        text: 'Allow Location Access',
                        onPressed: _requestLocationPermission,
                      ),
                    if (_isPermissionGranted && !_isLoading)
                      const SizedBox(height: 20), // Spacer when permission granted
                  ],
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
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
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
                    width: 60,
                    height: 60,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.8),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ],
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
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedUI() {
    return SingleChildScrollView(
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Container(
                //   padding: const EdgeInsets.all(25),
                //   decoration: BoxDecoration(
                //     color: accent.withOpacity(0.2),
                //     shape: BoxShape.circle,
                //     boxShadow: [
                //       BoxShadow(
                //         color: primaryDark.withOpacity(0.3),
                //         blurRadius: 30,
                //         spreadRadius: 5,
                //       ),
                //     ],
                //   ),
                //   child: SvgPicture.asset(
                //     'assets/svg/location.svg',
                //     width: 60,
                //     height: 60,
                //     color: Colors.white.withOpacity(0.95),
                //   ),
                // ),
                Icon(Icons.check_circle, 
                  color: highlight, 
                  size: 40,
                ),
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(highlight),
                  backgroundColor: Colors.transparent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Location access granted!\nTaking you to the app...',
            style: TextStyle(
              fontSize: 18,
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
              style: TextStyle(color: Colors.white.withOpacity(0.9))),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isLoading ? accent.withOpacity(0.7) : accent,
            foregroundColor: primaryDark,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: primaryDark.withOpacity(0.3),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
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
}