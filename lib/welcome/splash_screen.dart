import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:health_assistant/main/dashboard_screen.dart';
import 'package:health_assistant/welcome/location_persmission.dart';
import 'package:health_assistant/welcome/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Color Scheme matching your dashboard
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
  late Animation<double> _textScaleAnimation;
  late Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Fade animation for the entire content
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInCubic),
      ),
    );

    // Scale animation for the logo
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    // Text scale animation
    _textScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack),
      ),
    );

    // Text slide animation
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutQuad),
      ),
    );

    _animationController.forward();

    // Check auth state after animation completes
    Timer(const Duration(milliseconds: 4000), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LocationPermissionScreen()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with scale and fade animation
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeInAnimation,
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
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Main title with slide and scale animation
                  SlideTransition(
                    position: _textSlideAnimation,
                    child: ScaleTransition(
                      scale: _textScaleAnimation,
                      child: Text(
                        'MediCheck AI',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: primaryDark.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle with fade animation
                  FadeTransition(
                    opacity: _fadeInAnimation,
                    child: Text(
                      'Your Intelligent Health Companion',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Animated loading indicator
                  FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}