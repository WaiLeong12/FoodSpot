import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'OtherUserProfilePage.dart';

enum FollowListType { followers, following }

class FollowListPage extends StatefulWidget {
  final String targetUserId; // The user whose followers/following list we are viewing
  final FollowListType initialListType;

  const FollowListPage({
    Key? key,
    required this.targetUserId,
    required this.initialListType, required String currentUsername,
  }) : super(key: key);

  @override
  _FollowListPageState createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  User? _currentUser;

  List<String> _followerIds = [];
  List<String> _followingIds = [];
  Map<String, Map<String, dynamic>> _userDataCache = {}; // Cache for user details
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialListType == FollowListType.followers ? 0 : 1
    );
    _fetchFollowLists();
  }

  Future<void> _fetchFollowLists() async {
    if (!mounted) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .get();

      if (mounted && userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _followerIds = List<String>.from(data['followers'] ?? []);
            _followingIds = List<String>.from(data['following'] ?? []);
          });
        }
        // Pre-fetch user data for these IDs
        await _fetchUserDetails(_followerIds, FollowListType.followers);
        await _fetchUserDetails(_followingIds, FollowListType.following);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Target user profile not found.")));
      }
    } catch (e) {
      print("Error fetching follow lists: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading lists: ${e.toString()}")));
      }
    }
    if (mounted) {
      // isLoading flags are set within _fetchUserDetails
    }
  }

  Future<void> _fetchUserDetails(List<String> userIds, FollowListType type) async {
    if (!mounted) return;
    if (type == FollowListType.followers) setState(() => _isLoadingFollowers = true);
    if (type == FollowListType.following) setState(() => _isLoadingFollowing = true);

    Map<String, Map<String, dynamic>> fetchedUsers = {};
    if (userIds.isNotEmpty) {
      // Batch fetch user details (Firestore 'in' queries are limited to 10 items)
      List<List<String>> chunks = [];
      for (var i = 0; i < userIds.length; i += 10) {
        chunks.add(
            userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10)
        );
      }
      for (var chunk in chunks) {
        if (chunk.isNotEmpty) {
          QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var doc in usersSnapshot.docs) {
            fetchedUsers[doc.id] = doc.data() as Map<String, dynamic>;
          }
        }
      }
    }
    if (mounted) {
      setState(() {
        _userDataCache.addAll(fetchedUsers); // Add to cache
        if (type == FollowListType.followers) _isLoadingFollowers = false;
        if (type == FollowListType.following) _isLoadingFollowing = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.orange[100],
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_followerIds, _isLoadingFollowers, FollowListType.followers),
          _buildUserList(_followingIds, _isLoadingFollowing, FollowListType.following),
        ],
      ),
    );
  }

  Widget _buildUserList(List<String> userIds, bool isLoading, FollowListType type) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }
    if (userIds.isEmpty) {
      return Center(
        child: Text(
          type == FollowListType.followers ? 'No followers yet.' : 'Not following anyone yet.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: userIds.length,
      itemBuilder: (context, index) {
        final userId = userIds[index];
        final userData = _userDataCache[userId]; // Get from cache

        if (userData == null) {
          // This can happen if data is still loading for a specific user,
          // or if a user ID in followers/following list doesn't exist in users collection.
          return ListTile(title: Text('Loading user... $userId'));
        }
        return UserListTile(userData: userData, userId: userId);
      },
    );
  }
}

// Helper Widget for displaying each user in the list
class UserListTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId; // Needed for navigation

  const UserListTile({Key? key, required this.userData, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String username = userData['username'] ?? 'Unknown User';
    Uint8List? profileImageBytes;
    if (userData['profileImageBase64'] != null &&
        userData['profileImageBase64'].toString().isNotEmpty) {
      try {
        profileImageBytes = base64Decode(userData['profileImageBase64']);
      } catch (e) {
        print("Error decoding profile image for tile: $e");
      }
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.orange[100],
        backgroundImage: profileImageBytes != null ? MemoryImage(profileImageBytes) : null,
        child: profileImageBytes == null
            ? Icon(Icons.person, color: Colors.orange[700], size: 28)
            : null,
      ),
      title: Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
      // subtitle: Text('@$username'), // Optional: if you have a unique handle
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtherUserProfilePage(userId: userId),
          ),
        );
      },
      // You could add a Follow/Unfollow button here too if needed, similar to OtherUserProfilePage
    );
  }
}