import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'PostDetailPage.dart';

class OtherUserProfilePage extends StatefulWidget {
  final String userId;

  const OtherUserProfilePage({Key? key, required this.userId})
      : super(key: key);

  @override
  _OtherUserProfilePageState createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  User? _currentUser;
  Map<String, dynamic>? _profileUserData;
  Uint8List? _profileImageBytes;
  bool _isLoadingProfile = true;
  bool _isFollowingThisUser = false;
  Stream<QuerySnapshot>? _userPostsStream;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    print("OtherUserProfilePage: Viewing profile for userId: ${widget.userId}");
    if (widget.userId.isNotEmpty) {
      _userPostsStream = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .snapshots();
      _loadUserProfileData();
    } else {
      print("Error: userId for OtherUserProfilePage is empty.");
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _profileUserData = null;
        });
      }
    }
  }

  Future<void> _loadUserProfileData() async {
    if (!mounted) return;
    if (_profileUserData == null) {
      setState(() => _isLoadingProfile = true);
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (mounted && userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        print(
            "OtherUserProfilePage: Loaded profile data for ${widget.userId}: ${data['username']}");
        setState(() {
          _profileUserData = data;
          if (data['profileImageBase64'] != null &&
              data['profileImageBase64'].toString().isNotEmpty) {
            try {
              _profileImageBytes = base64Decode(data['profileImageBase64']);
            } catch (e) {
              print(
                  "Error decoding profileImageBase64 for other user ${widget.userId}: $e");
              _profileImageBytes = null;
            }
          } else {
            _profileImageBytes = null;
          }
        });
        await _checkIfFollowing();
      } else if (mounted) {
        print(
            "OtherUserProfilePage: Profile not found for userId: ${widget.userId}");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User profile not found.")));
        _profileUserData = null;
      }
    } catch (e) {
      print("Error loading other user's profile data for ${widget.userId}: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading profile: ${e.toString()}")));
      }
      _profileUserData = null;
    }
    if (mounted) {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _checkIfFollowing() async {
    if (_currentUser == null || widget.userId.isEmpty) return;
    try {
      DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (mounted && currentUserDoc.exists) {
        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        final List<dynamic> followingList = currentUserData['following'] ?? [];
        setState(() {
          _isFollowingThisUser = followingList.contains(widget.userId);
          print(
              "OtherUserProfilePage: Current user is${_isFollowingThisUser ? '' : ' NOT'} following ${widget.userId}");
        });
      }
    } catch (e) {
      print("Error checking follow status for ${widget.userId}: $e");
    }
  }

  Future<void> _toggleFollowUser() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to follow users.')));
      return;
    }
    if (_currentUser!.uid == widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot follow yourself.')));
      return;
    }
    if (widget.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot follow user with empty ID.')));
      return;
    }

    final currentUserRef =
    FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
    final targetUserRef =
    FirebaseFirestore.instance.collection('users').doc(widget.userId);
    final bool newFollowingState = !_isFollowingThisUser;

    if (mounted) {
      setState(() {
        _isFollowingThisUser = newFollowingState;
      });
    }

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      if (newFollowingState) {
        print(
            "Attempting to follow: CurrentUser ${_currentUser!.uid} -> TargetUser ${widget.userId}");
        batch.update(currentUserRef, {
          'following': FieldValue.arrayUnion([widget.userId])
        });
        batch.update(targetUserRef, {
          'followers': FieldValue.arrayUnion([_currentUser!.uid])
        });
      } else {
        print(
            "Attempting to unfollow: CurrentUser ${_currentUser!.uid} -> TargetUser ${widget.userId}");
        batch.update(currentUserRef, {
          'following': FieldValue.arrayRemove([widget.userId])
        });
        batch.update(targetUserRef, {
          'followers': FieldValue.arrayRemove([_currentUser!.uid])
        });
      }
      await batch.commit();
      print(
          "Follow/Unfollow batch commit successful for ${widget.userId}. New state: $newFollowingState");
      await _loadUserProfileData();
    } catch (e) {
      print("Error updating follow status for ${widget.userId}: $e");
      String errorMessage = 'Failed to update follow status.';
      if (e.toString().toLowerCase().contains('permission_denied') ||
          e.toString().toLowerCase().contains('permission denied')) {
        errorMessage =
        'Permission denied. Please check Firestore rules and ensure you are logged in.';
      } else if (e.toString().toLowerCase().contains('not_found')) {
        errorMessage = 'User document not found during follow operation.';
      }
      if (mounted) {
        setState(() {
          _isFollowingThisUser = !newFollowingState;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey[700], size: 18),
            const SizedBox(width: 8)
          ],
          Text('$label: ',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500)),
          Expanded(
              child: Text(value,
                  style: TextStyle(fontSize: 15, color: Colors.grey[900]),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange)),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile && _profileUserData == null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('User Profile'), backgroundColor: Colors.orange),
        body: const Center(
            child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (_profileUserData == null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('User Profile'), backgroundColor: Colors.orange),
        body: const Center(child: Text('Profile not found or error loading.')),
      );
    }

    String username = _profileUserData!['username'] ?? 'User';
    String bio = _profileUserData!['bio'] ?? 'No bio available.';
    String gender = _profileUserData!['gender'] ?? 'Not specified';
    String joinedDate = (_profileUserData!['joinedDate'] as Timestamp?) != null
        ? DateFormat('MMM d, yyyy')
        .format((_profileUserData!['joinedDate'] as Timestamp).toDate())
        : 'N/A';

    String followersCount =
    ((_profileUserData!['followers'] as List?)?.length ?? 0).toString();
    String followingCount =
    ((_profileUserData!['following'] as List?)?.length ?? 0).toString();
    String myPostsCount = (_profileUserData!['myPostsCount'] ?? 0).toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.orange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
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
                  backgroundImage: _profileImageBytes != null
                      ? MemoryImage(_profileImageBytes!)
                      : null,
                  child: _profileImageBytes == null
                      ? Icon(Icons.person, size: 50, color: Colors.orange[700])
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(bio,
                          style:
                          TextStyle(fontSize: 14, color: Colors.grey[700]),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text("Gender: $gender",
                          style:
                          TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentUser != null && _currentUser!.uid != widget.userId)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(
                      _isFollowingThisUser
                          ? Icons.check_circle_outline
                          : Icons.person_add_alt_1_outlined,
                      color: Colors.white),
                  label: Text(_isFollowingThisUser ? 'Following' : 'Follow',
                      style:
                      const TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: _toggleFollowUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFollowingThisUser
                        ? Colors.grey[600]
                        : Colors.orange[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _userPostsStream,
                      builder: (context, snapshot) {
                        String totalLikesReceived = '0';
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          totalLikesReceived = 'Loading...';
                        } else if (snapshot.hasError) {
                          print(
                              "Error fetching total likes for ${widget.userId}: ${snapshot.error}");
                          totalLikesReceived = 'Error';
                        } else if (snapshot.hasData) {
                          int totalLikes = 0;
                          for (var doc in snapshot.data!.docs) {
                            final postData = doc.data() as Map<String, dynamic>;
                            final likes =
                            List<String>.from(postData['likes'] ?? []);
                            totalLikes += likes.length;
                          }
                          totalLikesReceived = totalLikes.toString();
                        }
                        return _buildInfoRow(
                            'Total Likes Received', totalLikesReceived,
                            icon: Icons.favorite_border);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow('Joined Date', joinedDate,
                        icon: Icons.calendar_today_outlined),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Followers', followersCount),
                        _buildStatItem('Following', followingCount),
                        _buildStatItem('Posts', myPostsCount),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("User's Posts",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            if (_userPostsStream == null)
              const Padding(
                  padding: EdgeInsets.all(20),
                  child:
                  Center(child: Text('Cannot load posts for this user.'))),
            if (_userPostsStream != null)
              StreamBuilder<QuerySnapshot>(
                stream: _userPostsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child:
                          CircularProgressIndicator(color: Colors.orange)),
                    );
                  }
                  if (snapshot.hasError) {
                    print(
                        "Error in User's Posts StreamBuilder for ${widget.userId}: ${snapshot.error}");
                    return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                            child: Text(
                                'Error loading posts: ${snapshot.error}')));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    print(
                        "User's Posts StreamBuilder: No posts found for userId: ${widget.userId} (hasData: ${snapshot.hasData})");
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('This user has no posts yet.')),
                    );
                  }
                  final userPosts = snapshot.data!.docs;
                  print(
                      "User's Posts StreamBuilder: Found ${userPosts.length} posts for userId: ${widget.userId}");

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: userPosts.length,
                    itemBuilder: (context, index) {
                      final postDoc = userPosts[index];
                      final postContent =
                      postDoc.data() as Map<String, dynamic>;
                      Uint8List? postImageBytes;
                      if (postContent['imagesBase64'] != null &&
                          (postContent['imagesBase64'] as List).isNotEmpty) {
                        try {
                          postImageBytes = base64Decode(
                              (postContent['imagesBase64'] as List)[0]);
                        } catch (e) {
                          print("Error decoding post image in list: $e");
                        }
                      } else if (postContent['imageBase64'] != null &&
                          postContent['imageBase64'].toString().isNotEmpty) {
                        try {
                          postImageBytes =
                              base64Decode(postContent['imageBase64']);
                        } catch (e) {
                          print("Error decoding single post image in list: $e");
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: postImageBytes != null
                              ? ClipRRect(
                              borderRadius: BorderRadius.circular(4.0),
                              child: Image.memory(postImageBytes,
                                  width: 60, height: 60, fit: BoxFit.cover))
                              : Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4.0)),
                              child: const Icon(Icons.image_not_supported,
                                  color: Colors.grey)),
                          title: Text(postContent['title'] ?? 'No Title',
                              style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            postContent['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[700]),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailPage(
                                    postData: postContent, postId: postDoc.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

