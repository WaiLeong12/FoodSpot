import 'package:flutter/material.dart';
import 'auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthService _authService = AuthService();
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  PasswordStrength _passwordStrength = PasswordStrength.weak;
  PasswordRequirements _requirements = PasswordRequirements(
    hasMinLength: false,
    hasUppercase: false,
    hasNumber: false,
    hasSpecialChar: false,
  );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String _getStrengthText(PasswordStrength strength) {
    return switch (strength) {
      PasswordStrength.weak => 'Weak',
      PasswordStrength.medium => 'Medium',
      PasswordStrength.strong => 'Strong',
      PasswordStrength.veryStrong => 'Very Strong',
    };
  }

  Color _getStrengthColor(PasswordStrength strength) {
    return switch (strength) {
      PasswordStrength.weak => Colors.red,
      PasswordStrength.medium => Colors.orange,
      PasswordStrength.strong => Colors.lightGreen,
      PasswordStrength.veryStrong => Colors.green,
    };
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_requirements.allMet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fulfill all password requirements'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to terms and conditions')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        context: context,
      );

      if (user != null && mounted) {
        // Navigate to email verification page instead of home
        Navigator.pushReplacementNamed(context, '/verify-email');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[300],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                      ),
                      Image.asset(
                        'assets/images/foodspot.png',
                        height: 40,
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 30),

                  const Text(
                    'Account Registration',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  // Email Field
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Email:',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Username Field
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Username:',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.length < 4) {
                        return 'Username must be at least 4 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    onChanged: (value) {
                      setState(() {
                        _passwordStrength = _authService.checkPasswordStrength(value);
                        _requirements = _authService.checkPasswordRequirements(value);
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Password:',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 8),

                  // Password Strength Indicator
                  LinearProgressIndicator(
                    value: _passwordStrength.index / PasswordStrength.veryStrong.index,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStrengthColor(_passwordStrength),
                    ),
                    minHeight: 4,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _getStrengthText(_passwordStrength),
                      style: TextStyle(
                        color: _getStrengthColor(_passwordStrength),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Password Requirements
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RequirementCheck(
                        met: _requirements.hasMinLength,
                        text: '• 8+ characters',
                      ),
                      _RequirementCheck(
                        met: _requirements.hasUppercase,
                        text: '• 1 uppercase letter',
                      ),
                      _RequirementCheck(
                        met: _requirements.hasNumber,
                        text: '• 1 number',
                      ),
                      _RequirementCheck(
                        met: _requirements.hasSpecialChar,
                        text: '• 1 special character',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Confirm Password:',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordCtrl.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),

                  // Terms Agreement
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() {
                            _agreeToTerms = value!;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I agree to the Terms of Use, Privacy Policy, and Data Notification Settings.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'SIGN UP',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequirementCheck extends StatelessWidget {
  final bool met;
  final String text;

  const _RequirementCheck({required this.met, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.error,
            color: met ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
