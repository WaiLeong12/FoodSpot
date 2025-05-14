import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'OtherUserProfilePage.dart';

enum FollowListType { followers, following }

class FollowListPage extends StatefulWidget {
  final String targetUserId;
  final FollowListType initialListType;
  final String currentUsername;

  const FollowListPage({
    Key? key,
    required this.targetUserId,
    required this.initialListType,
    required this.currentUsername,
  }) : super(key: key);

  @override
  _FollowListPageState createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  User? _currentUser;
  List<String> _followerIds = [];
  List<String> _followingIds = [];
  Map<String, Map<String, dynamic>> _userDataCache = {};
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialListType == FollowListType.followers ? 0 : 1,
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
        await _fetchUserDetails(_followerIds, FollowListType.followers);
        await _fetchUserDetails(_followingIds, FollowListType.following);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Target user profile not found.")));
      }
    } catch (e) {
      print("Error fetching follow lists: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading lists: ${e.toString()}")));
      }
    }
  }

  Future<void> _fetchUserDetails(
      List<String> userIds, FollowListType type) async {
    if (!mounted) return;
    if (type == FollowListType.followers) {
      setState(() => _isLoadingFollowers = true);
    }
    if (type == FollowListType.following) {
      setState(() => _isLoadingFollowing = true);
    }

// Only fetch users not already in cache
    List<String> usersToFetch =
    userIds.where((id) => !_userDataCache.containsKey(id)).toList();
    Map<String, Map<String, dynamic>> fetchedUsers = {};

    if (usersToFetch.isNotEmpty) {
      List<List<String>> chunks = [];
      for (var i = 0; i < usersToFetch.length; i += 10) {
        chunks.add(usersToFetch.sublist(
            i, i + 10 > usersToFetch.length ? usersToFetch.length : i + 10));
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
        _userDataCache.addAll(fetchedUsers);
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
        title: const Text('Followers & Following', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.black),
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
          _buildUserList(
              _followerIds, _isLoadingFollowers, FollowListType.followers),
          _buildUserList(
              _followingIds, _isLoadingFollowing, FollowListType.following),
        ],
      ),
    );
  }

  Widget _buildUserList(
      List<String> userIds, bool isLoading, FollowListType type) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.orange));
    }
    if (userIds.isEmpty) {
      return Center(
        child: Text(
          type == FollowListType.followers
              ? 'No followers yet.'
              : 'Not following anyone yet.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: userIds.length,
      itemBuilder: (context, index) {
        final userId = userIds[index];
        final userData = _userDataCache[userId];
        if (userData == null) {
          return ListTile(title: Text('Loading user... $userId'));
        }
        return UserListTile(
          userData: userData,
          userId: userId,
          onNavigateBack: _fetchFollowLists,
        );
      },
      separatorBuilder: (context, index) => Divider(
        height: 10,
        thickness: 0.9,
        color: Colors.grey[500],
        indent: 16,
        endIndent: 16,
      ),
    );
  }
}

class UserListTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId;
  final VoidCallback onNavigateBack;

  const UserListTile({
    Key? key,
    required this.userData,
    required this.userId,
    required this.onNavigateBack,
  }) : super(key: key);

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
        backgroundImage:
        profileImageBytes != null ? MemoryImage(profileImageBytes) : null,
        child: profileImageBytes == null
            ? Icon(Icons.person, color: Colors.orange[700], size: 28)
            : null,
      ),
      title:
      Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtherUserProfilePage(userId: userId),
          ),
        ).then((_) {
          onNavigateBack();
        });
      },
    );
  }
}
