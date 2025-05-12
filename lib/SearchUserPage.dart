import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'OtherUserProfilePage.dart';

class SearchUserPage extends StatefulWidget {
  @override
  _SearchUserPageState createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  final Map<String, Uint8List?> _profileImageCache = {};

  Future<Uint8List?> _getProfileImage(String userId) async {
    if (_profileImageCache.containsKey(userId)) {
      return _profileImageCache[userId];
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data['profileImageBase64'] != null) {
          Uint8List imageBytes = base64Decode(data['profileImageBase64']);
          _profileImageCache[userId] = imageBytes;
          return imageBytes;
        }
      }
    } catch (e) {
      print("Error fetching profile image: $e");
    }
    return null;
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + 'z')
          .limit(10)
          .get();

      setState(() {
        _searchResults = result.docs;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildUserCard(DocumentSnapshot user) {
    final userData = user.data() as Map<String, dynamic>;
    final userId = user.id;
    final username = userData['username'] ?? 'Anonymous';
    final email = userData['email'] ?? '';
    final String? profileImageBase64 = userData['profileImageBase64'] as String?;

    Uint8List? profileImageBytes;
    if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
      try {
        profileImageBytes = base64Decode(profileImageBase64);
      } catch (e) {
        print("Error decoding profileImageBase64 for user $userId: $e");
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.orange[100],
          backgroundImage: profileImageBytes != null ? MemoryImage(profileImageBytes) : null,
          child: profileImageBytes == null
              ? Icon(
            Icons.person,
            color: Colors.orange[700],
            size: 32,
          )
              : null,
        ),
        title: Text(
          username,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          email,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtherUserProfilePage(
                userId: userId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (!_hasSearched) {
      return Center(
        child: Text(
          'Search for users by username',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_searchResults[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Users'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.black87),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  icon: Icon(Icons.clear, color: Colors.black87),
                  onPressed: () {
                    _searchController.clear();
                    _searchUsers('');
                  },
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }
}