import 'dart:io';

import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailVerifier {
  /// Checks MX records using Google's DNS-over-HTTPS API
  static Future<bool> hasValidMxRecords(String email) async {
    try {
      final domain = _extractDomain(email);
      if (domain.isEmpty) return false;

      final response = await http.get(
        Uri.parse('https://dns.google/resolve?name=$domain&type=MX'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['Answer'] != null && (data['Answer'] as List).isNotEmpty;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Alternative method using system calls (works on mobile/desktop)
  static Future<bool> hasValidMxRecordsAlt(String email) async {
    try {
      final domain = _extractDomain(email);
      if (domain.isEmpty) return false;

      final result = await Process.run('nslookup', ['-query=mx', domain]);
      final output = result.stdout.toString().toLowerCase();

      return output.contains('mail exchanger') ||
          output.contains('mx preference');
    } catch (e) {
      return false;
    }
  }

  static String _extractDomain(String email) {
    final parts = email.split('@');
    return parts.length == 2 ? parts[1] : '';
  }
}