import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  // Color Scheme matching your login screen
  final Color primaryDark = const Color(0xFF03045E);
  final Color primary = const Color(0xFF03045E);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentLight = const Color(0xFF90E0EF);
  final Color secondaryDark = const Color(0xFF05668D);
  final Color secondary = const Color(0xFF028090);
  final Color highlight = const Color(0xFFF0F3BD);
  final Color accent = const Color(0xFF02C39A);

  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _errorMessage = '';
  String _successMessage = '';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = '';
      _successMessage = '';
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      setState(() {
        _successMessage = 'Password reset email sent successfully';
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: "Password reset email sent!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: primary,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg = _getErrorMessage(e.code);
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: errorMsg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      String errorMsg = 'An unexpected error occurred';
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: errorMsg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'invalid-email':
        return 'Please enter a valid email';
      default:
        return 'Password reset failed. Please try again';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accentLight.withOpacity(0.1), Colors.white, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header Section
                  _buildHeaderSection(),

                  // Reset Password Form
                  _buildResetForm(theme),

                  // Footer Section
                  _buildFooterSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          Animate(
            effects: [
              FadeEffect(duration: 300.ms),
              ScaleEffect(begin: Offset(0.9, 0.9), end: Offset(1, 1)),
            ],
            child: Icon(
              Icons.lock_reset,
              size: 80,
              color: primary,
            ),
          ),
          SizedBox(height: 20),
          Animate(
            effects: [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
            child: Text(
              'Forgot Password',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryDark,
              ),
            ),
          ),
          SizedBox(height: 10),
          Animate(
            effects: [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
            child: Text(
              'Enter your email to receive a reset link',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetForm(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          // Email Field
          Animate(
            effects: [FadeEffect(), SlideEffect(begin: Offset(-0.2, 0))],
            child: TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: primary),
                prefixIcon: Icon(Icons.email, color: primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: TextStyle(color: primaryDark),
              cursorColor: primary,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ),

          SizedBox(height: 20),

          // Error Message
          if (_errorMessage.isNotEmpty)
            Animate(
              effects: [FadeEffect(), ScaleEffect()],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                ),
              ),
            ),

          // Success Message
          if (_successMessage.isNotEmpty)
            Animate(
              effects: [FadeEffect(), ScaleEffect()],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _successMessage,
                  style: TextStyle(color: Colors.green.shade600, fontSize: 14),
                ),
              ),
            ),

          SizedBox(height: 20),

          // Reset Button
          Animate(
            effects: [FadeEffect(), ScaleEffect()],
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  shadowColor: accentLight,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'SEND RESET LINK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 40),
      child: Animate(
        effects: [FadeEffect()],
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Back to Login',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}