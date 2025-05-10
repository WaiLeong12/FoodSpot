import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

enum PasswordStrength {
  weak,
  medium,
  strong,
  veryStrong,
}

class PasswordRequirements {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  PasswordRequirements({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  bool get allMet => hasMinLength && hasUppercase && hasNumber && hasSpecialChar;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PasswordStrength checkPasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasSpecialChars = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    bool hasMinLength = password.length >= 8;

    int strength = 0;
    if (hasMinLength) strength++;
    if (hasUppercase) strength++;
    if (hasDigits) strength++;
    if (hasLowercase) strength++;
    if (hasSpecialChars) strength++;

    return switch (strength) {
      0 || 1 => PasswordStrength.weak,
      2 => PasswordStrength.medium,
      3 => PasswordStrength.strong,
      _ => PasswordStrength.veryStrong,
    };
  }

  PasswordRequirements checkPasswordRequirements(String password) {
    return PasswordRequirements(
      hasMinLength: password.length >= 8,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasNumber: password.contains(RegExp(r'[0-9]')),
      hasSpecialChar: password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    );
  }

  Future<User?> login({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        _showWarning(
          context,
          'Please verify your email before logging in. Check your inbox.',
        );
        return null;
      }

      _showSuccess(context, 'Login successful!');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      _showError(context, _getErrorMessage(e.code));
      return null;
    }
  }

  Future<void> sendPasswordResetEmail({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSuccess(
          context,
          'Password reset link sent to $email. Please check your inbox.'
      );
    } on FirebaseAuthException catch (e) {
      _showError(context, _getErrorMessage(e.code));
    }
  }

  // Update password (when user knows current password)
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required BuildContext context,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Re-authenticate first
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // Then update password
      await user.updatePassword(newPassword);
      _showSuccess(context, 'Password updated successfully!');
    } on FirebaseAuthException catch (e) {
      _showError(context, _getErrorMessage(e.code));
    }
  }

  Future<bool> _verifyEmailDomain(String email) async {
    try {
      final domain = _extractDomain(email);
      if (domain.isEmpty) return false;

      // Try Google's DNS-over-HTTPS API first
      try {
        final response = await http.get(
          Uri.parse('https://dns.google/resolve?name=$domain&type=MX'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['Answer'] != null && (data['Answer'] as List).isNotEmpty;
        }
      } catch (e) {
        // Fall back to system call if HTTP request fails
        return await _verifyEmailDomainWithSystemCall(domain);
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _verifyEmailDomainWithSystemCall(String domain) async {
    try {
      final result = await Process.run('nslookup', ['-query=mx', domain]);
      final output = result.stdout.toString().toLowerCase();
      return output.contains('mail exchanger') || output.contains('mx preference');
    } catch (e) {
      return false;
    }
  }

  String _extractDomain(String email) {
    final parts = email.split('@');
    return parts.length == 2 ? parts[1] : '';
  }

  Future<User?> register({
    required String email,
    required String password,
    required BuildContext context,
    required String username,
  }) async {
    // 1. Basic email validation
    if (!_isValidEmail(email)) {
      _showError(context, 'Please enter a valid email address');
      return null;
    }

    // 2. Domain verification
    try {
      final domainValid = await _verifyEmailDomain(email);
      if (!domainValid) {
        _showWarning(
          context,
          'We couldn\'t verify your email domain. '
              'Please check your email address or use a different provider.',
        );
        return null;
      }
    } catch (e) {
      _showWarning(context, 'Email verification skipped. Please verify your email later.');
    }

    // 3. Firebase registration
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to Firestore
      User? user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'username': username,
          'bio': '', // Empty bio initially
          'followers': 0,
          'following': 0,
          'joinedDate': Timestamp.now(),
          'lastLogin': Timestamp.now(),
          'myPostsCount': 0,
          'profileImageUrl': '', // Empty initially, can be updated later
        });
      }

      // Send verification email
      await user?.sendEmailVerification();

      _showSuccess(
        context,
        'Registration successful! Please check your email for verification.',
      );

      return user;
    } on FirebaseAuthException catch (e) {
      _showError(context, _getErrorMessage(e.code));
      return null;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getErrorMessage(String code) {
    return switch (code) {
      'invalid-email' => 'Invalid email format',
      'weak-password' => 'Password too weak',
      'email-already-in-use' => 'Email already registered',
      'user-not-found' => 'No account found with this email',
      'wrong-password' => 'Incorrect password',
      'user-disabled' => 'This account has been disabled',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'requires-recent-login' => 'Please login again to change password',
      _ => 'An error occurred. Please try again.',
    };
  }
}
