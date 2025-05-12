import 'dart:convert'; // For base64Decode
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'EditProfilePage.dart';
import 'FollowListPage.dart';
import 'MyPostsPage.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  User? _currentUser;
  Stream<DocumentSnapshot>? _userStream; // Stream for real-time user data

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .snapshots(); // Listen to real-time changes
    }
    // _loadUserData(); // Replaced by StreamBuilder
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0), // Adjusted padding
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey[600], size: 18), // Slightly smaller icon
            const SizedBox(width: 10),
          ],
          Text('$label: ', style: TextStyle(fontSize: 14.5, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14.5, color: valueColor ?? Colors.black87, fontWeight: FontWeight.w500),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange[700])),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This page is typically a body within FoodMain, so no Scaffold/AppBar here
    // unless it's pushed as a full independent page.
    // The background color should ideally be set by FoodMain's Scaffold.
    // Adding a Container with color here if MePage is used as a direct body.
    // return Container(
    //   color: Colors.orange[50], // Match the desired background
    //   child: _buildProfileContent(),
    // );
    if (_currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 20),
              const Text('Please log in to view your profile.', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
                child: const Text('Go to Login', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }
        if (snapshot.hasError) {
          print("Error in MePage StreamBuilder: ${snapshot.error}");
          return Center(child: Text("Error loading profile: ${snapshot.error}"));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // This might happen if the user document is deleted or uid is incorrect
          return const Center(child: Text("Profile data not found. Please try logging out and in again."));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        Uint8List? profileImageBytes;
        if (userData['profileImageBase64'] != null &&
            userData['profileImageBase64'].toString().isNotEmpty) {
          try {
            profileImageBytes = base64Decode(userData['profileImageBase64']);
          } catch (e) {
            print("Error decoding profileImageBase64 in MePage: $e");
          }
        }

        String username = userData['username'] ?? _currentUser?.displayName ?? 'User';
        String bio = userData['bio'] ?? 'No bio yet. Tap edit to add one!';
        String gender = userData['gender'] ?? 'Not specified';
        String joinedDate = (userData['joinedDate'] as Timestamp?) != null
            ? DateFormat('MMM d, yyyy').format((userData['joinedDate'] as Timestamp).toDate()) // Changed format
            : 'N/A';
        String lastLoginDate = (userData['lastLogin'] as Timestamp?) != null
            ? DateFormat('MMM d, yyyy hh:mm a').format((userData['lastLogin'] as Timestamp).toDate()) // Changed format
            : 'N/A';

        // For "Total Likes Received", this field needs to be calculated and stored in the user's document,
        // possibly using Cloud Functions that aggregate likes from all their posts.
        // For now, we'll assume it's there or default to 0.
        String totalLikesReceived = (userData['totalLikesReceived'] ?? 0).toString();
        String followersCount = ((userData['followers'] as List?)?.length ?? 0).toString();
        String followingCount = ((userData['following'] as List?)?.length ?? 0).toString();
        String myPostsCount = (userData['myPostsCount'] ?? 0).toString();

        return Container( // Added container for background color
          color: Colors.orange[50], // Match the design's light orange background
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Header Section
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white, // White background for this section
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.orange[100],
                        backgroundImage: profileImageBytes != null ? MemoryImage(profileImageBytes) : null,
                        child: profileImageBytes == null ? Icon(Icons.person, size: 50, color: Colors.orange[700]) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text(bio, style: TextStyle(fontSize: 14, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text("Gender: $gender", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stats Card
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 0), // Match width
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Total Likes Received', totalLikesReceived, icon: Icons.favorite_border),
                        _buildInfoRow('Last Signed In', lastLoginDate, icon: Icons.access_time),
                        _buildInfoRow('Joined Date', joinedDate, icon: Icons.calendar_today),
                        const Divider(height: 20, thickness: 0.5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Followers', followersCount, onTap: () {
                              if (_currentUser != null) {
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => FollowListPage(
                                      targetUserId: _currentUser!.uid,
                                      initialListType: FollowListType.followers,
                                      currentUsername: username, // Pass current user's name
                                    )
                                ));
                              }
                            }),
                            _buildStatItem('Following', followingCount, onTap: () {
                              if (_currentUser != null) {
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => FollowListPage(
                                      targetUserId: _currentUser!.uid,
                                      initialListType: FollowListType.following,
                                      currentUsername: username, // Pass current user's name
                                    )
                                ));
                              }
                            }),
                            _buildStatItem('My Posts', myPostsCount, onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostsPage()));
                            }),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                _buildActionButton(
                  context,
                  label: 'Edit Profile',
                  icon: Icons.edit_outlined,
                  onPressed: () async {
                    // Pass the full userData map to EditProfilePage
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditProfilePage(currentUserData: userData)),
                    );
                    // StreamBuilder will automatically handle UI updates if data changes
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
                  color: Colors.red[400], // Red color for logout
                  textColor: Colors.white,
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, {required String label, required IconData icon, VoidCallback? onPressed, Color? color, Color? textColor}) {
    return SizedBox(
      width: double.infinity, // Make buttons full width
      child: ElevatedButton.icon(
        icon: Icon(icon, color: textColor ?? Colors.orange[800], size: 20),
        label: Text(label, style: TextStyle(color: textColor ?? Colors.orange[800], fontSize: 16, fontWeight: FontWeight.w500)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.white, // White background for edit/reset
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: color == null ? 1.5 : 2, // Slight elevation
          side: color == null ? BorderSide(color: Colors.orange.shade200, width: 0.5) : null,
        ),
      ),
    );
  }
}