import 'dart:convert'; // For base64Decode
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'EditProfilePage.dart';
import 'MyPostsPage.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  Uint8List? _profileImageBytes; // To hold decoded image bytes

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        if (mounted && userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userData = data;
            // Decode profile image Base64 string if it exists
            if (data['profileImageBase64'] != null &&
                data['profileImageBase64'].toString().isNotEmpty) {
              try {
                _profileImageBytes = base64Decode(data['profileImageBase64']);
              } catch (e) {
                print("Error decoding profileImageBase64: $e");
                _profileImageBytes = null; // Reset if decoding fails
              }
            } else {
              _profileImageBytes = null; // No image string
            }
          });
        }
      } catch (e) {
        print("Error loading user data: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error loading profile: ${e.toString()}")));
        }
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey[700], size: 18),
            const SizedBox(width: 8),
          ],
          Text('$label: ', style: TextStyle(fontSize: 15, color: Colors.grey[800], fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: Colors.grey[900]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (_currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Please log in to view your profile.', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                child: const Text('Go to Login', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    // Use _userData safely, providing defaults
    String username = _userData?['username'] ?? _currentUser?.displayName ?? 'User';
    String bio = _userData?['bio'] ?? 'No bio yet. Tap edit to add one!';
    String gender = _userData?['gender'] ?? 'Not specified';

    String joinedDate = (_userData?['joinedDate'] as Timestamp?) != null
        ? DateFormat('MMM d, yyyy').format((_userData!['joinedDate'] as Timestamp).toDate())
        : 'N/A';
    String lastLoginDate = (_userData?['lastLogin'] as Timestamp?) != null
        ? DateFormat('MMM d, yyyy hh:mm a').format((_userData!['lastLogin'] as Timestamp).toDate())
        : 'N/A';

    String totalLikesReceived = (_userData?['totalLikesReceived'] ?? 0).toString();
    String followersCount = ((_userData?['followers'] as List?)?.length ?? 0).toString();
    String followingCount = ((_userData?['following'] as List?)?.length ?? 0).toString();
    String myPostsCount = (_userData?['myPostsCount'] ?? 0).toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.orange[200],
                // Use MemoryImage if _profileImageBytes is available
                backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                child: _profileImageBytes == null
                    ? Icon(Icons.person, size: 50, color: Colors.orange[700])
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(bio, style: TextStyle(fontSize: 14, color: Colors.grey[700]), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("Gender: $gender", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Total Likes Received', totalLikesReceived, icon: Icons.favorite_outline),
                  _buildInfoRow('Last Signed In', lastLoginDate, icon: Icons.access_time_outlined),
                  _buildInfoRow('Joined Date', joinedDate, icon: Icons.calendar_today_outlined),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Followers', followersCount, onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Followers list page coming soon!")));
                      }),
                      _buildStatItem('Following', followingCount, onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Following list page coming soon!")));
                      }),
                      _buildStatItem('My Posts', myPostsCount, onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyPostsPage()),
                        );
                      }),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            context,
            label: 'Edit Profile',
            icon: Icons.edit_outlined,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfilePage(currentUserData: _userData ?? {})),
              );
              if (result == true && mounted) {
                _loadUserData(); // Reload data if profile was updated
              }
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            context,
            label: 'Reset Password',
            icon: Icons.lock_reset_outlined,
            onPressed: () {
              Navigator.pushNamed(context, '/forgotPassword');
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            context,
            label: 'Logout',
            icon: Icons.logout_outlined,
            color: Colors.red[400],
            textColor: Colors.white,
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required String label, required IconData icon, VoidCallback? onPressed, Color? color, Color? textColor}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: textColor ?? Colors.orange[800]),
        label: Text(label, style: TextStyle(color: textColor ?? Colors.orange[800], fontSize: 16)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.orange[100],
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 1,
        ),
      ),
    );
  }
}
