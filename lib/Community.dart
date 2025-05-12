import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'OtherUserProfilePage.dart';
import 'PostCommentPage.dart';
import 'PostDetailPage.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  int _selectedIndex = 3;
  String _currentFilter = 'recent'; // 'recent', 'likes', or 'comments'
  Stream<QuerySnapshot>? _postsStream;

  @override
  void initState() {
    super.initState();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _changeFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      switch (filter) {
        case 'likes':
          _postsStream = FirebaseFirestore.instance
              .collection('posts')
              .orderBy('likes', descending: true)
              .snapshots();
          break;
        case 'comments':
          _postsStream = FirebaseFirestore.instance
              .collection('posts')
              .orderBy('commentsCount', descending: true)
              .snapshots();
          break;
        default: // 'recent'
          _postsStream = FirebaseFirestore.instance
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .snapshots();
      }
    });
  }

  void _onItemTapped(int index, BuildContext context) {
    if (index == _selectedIndex && index == 3) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0: // Home
        Navigator.pushNamedAndRemoveUntil(context, '/main', (Route<dynamic> route) => false);
        break;
      case 1: // Saved
        Navigator.pushNamed(context, '/save');
        break;
      case 2: // Post
        Navigator.pushNamed(context, '/post');
        break;
      case 3: // Community
        Navigator.pushNamed(context, '/community');
        break;
      case 4: // Me
        Navigator.pushNamed(context, '/me');
        break;
    }
  }

  BottomNavigationBarItem _buildBottomNavItem(String assetPath, String label, int itemIndex, int currentIndex) {
    final bool isSelected = itemIndex == currentIndex;
    return BottomNavigationBarItem(
      icon: Image.asset(
        assetPath,
        width: 40,
        height: 40,
        color: isSelected ? Colors.black : Colors.black87,
      ),
      label: label,
    );
  }

  Widget _buildFilterButton(String text, String filter) {
    final isActive = _currentFilter == filter;
    return TextButton(
      onPressed: () => _changeFilter(filter),
      style: TextButton.styleFrom(
        backgroundColor: isActive ? Colors.orange : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.orange[800],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        automaticallyImplyLeading: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/Food.png', width: 70, height: 70),
            const SizedBox(width: 10),
            const Text('FoodSpot', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CommunityPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter buttons row
          Container(
            color: Colors.orange[100],
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterButton('Recent', 'recent'),
                _buildFilterButton('Most Likes', 'likes'),
                _buildFilterButton('Most Comments', 'comments'),
              ],
            ),
          ),
          // Posts list
          Expanded(
            child: Container(
              color: Colors.orange[50],
              child: StreamBuilder<QuerySnapshot>(
                stream: _postsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.orange));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error.toString()}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No posts yet. Be the first to share!', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    );
                  }
                  final posts = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final postDocument = posts[index];
                      return PostCardItem(postSnapshot: postDocument);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.orange,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black87,
        currentIndex: _selectedIndex,
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          _buildBottomNavItem('assets/images/homelogo.png', 'Home', 0, _selectedIndex),
          _buildBottomNavItem('assets/images/foodspotlogo.png', 'Saved', 1, _selectedIndex),
          _buildBottomNavItem('assets/images/add.png', 'Post', 2, _selectedIndex),
          _buildBottomNavItem('assets/images/community.png', 'Community', 3, _selectedIndex),
          _buildBottomNavItem('assets/images/me.png', 'Me', 4, _selectedIndex),
        ],
      ),
    );
  }
}

class PostCardItem extends StatefulWidget {
  final DocumentSnapshot postSnapshot;
  const PostCardItem({Key? key, required this.postSnapshot}) : super(key: key);

  @override
  _PostCardItemState createState() => _PostCardItemState();
}

class _PostCardItemState extends State<PostCardItem> {
  User? _currentUser;
  bool _isLikedLocal = false;
  int _likeCountLocal = 0;
  bool _isBookmarkedLocal = false;
  Uint8List? _authorProfileImageBytes;
  String? _authorUsernameCurrent;
  bool _isFollowingAuthor = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadPostCardStates();
  }

  @override
  void didUpdateWidget(covariant PostCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postSnapshot.id != oldWidget.postSnapshot.id ||
        !mapEquals(widget.postSnapshot.data() as Map<String, dynamic>?, oldWidget.postSnapshot.data() as Map<String, dynamic>?)) {
      _loadPostCardStates();
    }
  }

  bool mapEquals(Map<String, dynamic>? map1, Map<String, dynamic>? map2) {
    if (map1 == null && map2 == null) return true;
    if (map1 == null || map2 == null) return false;
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key)) return false;
      if (map1[key] is List && map2[key] is List) {
        if (!listEquals(map1[key] as List, map2[key] as List)) return false;
      } else if (map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadPostCardStates() async {
    if (!widget.postSnapshot.exists) return;
    final postData = widget.postSnapshot.data() as Map<String, dynamic>;
    bool currentBookmarkStatus = false;
    Uint8List? authorImgBytes;
    String? fetchedAuthorUsername = postData['username'];
    bool currentFollowingStatus = false;

    final String? authorId = postData['userId'] as String?;
    if (authorId != null && authorId.isNotEmpty) {
      try {
        DocumentSnapshot authorDoc = await FirebaseFirestore.instance.collection('users').doc(authorId).get();
        if (authorDoc.exists) {
          final authorData = authorDoc.data() as Map<String, dynamic>;
          fetchedAuthorUsername = authorData['username'] ?? postData['username'] ?? 'Anonymous';
          if (authorData['profileImageBase64'] != null && authorData['profileImageBase64'].toString().isNotEmpty) {
            try {
              authorImgBytes = base64Decode(authorData['profileImageBase64']);
            } catch (e) { print("Error decoding author profileImage for card ${widget.postSnapshot.id}: $e"); }
          }
        }
      } catch (e) { print("Error fetching author's profile for card ${widget.postSnapshot.id}: $e"); }
    }

    if (_currentUser != null) {
      final List<dynamic> likes = postData['likes'] ?? [];
      _isLikedLocal = likes.map((like) => like.toString()).contains(_currentUser!.uid.toString());
      try {
        DocumentSnapshot currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
        if (currentUserDoc.exists) {
          final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
          final List<dynamic> savedPosts = currentUserData['savedPosts'] ?? [];
          currentBookmarkStatus = savedPosts.contains(widget.postSnapshot.id);
          if (authorId != null && authorId.isNotEmpty) {
            final List<dynamic> followingList = currentUserData['following'] ?? [];
            currentFollowingStatus = followingList.contains(authorId);
          }
        }
      } catch (e) { print("Error fetching current user's data for card ${widget.postSnapshot.id}: $e"); }
    }

    if (mounted) {
      setState(() {
        _likeCountLocal = (postData['likes'] as List?)?.length ?? 0;
        _isBookmarkedLocal = currentBookmarkStatus;
        _authorProfileImageBytes = authorImgBytes;
        _authorUsernameCurrent = fetchedAuthorUsername;
        _isFollowingAuthor = currentFollowingStatus;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login to like posts.')));
      return;
    }
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postSnapshot.id);
    final String currentUserId = _currentUser!.uid;

    try {
      if (_isLikedLocal) {
        await postRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
      } else {
        await postRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
      }
    } catch (e) {
      print("Error updating like status for card: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update like status.')));
      }
    }
  }

  Future<void> _toggleBookmark() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login to save posts.')));
      return;
    }
    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
    final String postId = widget.postSnapshot.id;
    final bool newBookmarkState = !_isBookmarkedLocal;

    if (mounted) setState(() => _isBookmarkedLocal = newBookmarkState);

    try {
      if (newBookmarkState) {
        await userRef.update({'savedPosts': FieldValue.arrayUnion([postId])});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post saved!')));
      } else {
        await userRef.update({'savedPosts': FieldValue.arrayRemove([postId])});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post unsaved.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBookmarkedLocal = !newBookmarkState);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update save status.')));
      }
    }
  }

  Future<void> _toggleFollowUser(String targetUserId) async {
    if (_currentUser == null || _currentUser!.uid == targetUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot follow yourself.')),
        );
      }
      return;
    }

    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetUserId);
    final bool newFollowingState = !_isFollowingAuthor;

    try {
      final targetUserDoc = await targetUserRef.get();
      if (!targetUserDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target user does not exist.')),
          );
        }
        return;
      }
    } catch (e) {
      print("Error checking target user existence: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error verifying user profile.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isFollowingAuthor = newFollowingState;
      });
    }

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      if (newFollowingState) {
        batch.update(currentUserRef, {'following': FieldValue.arrayUnion([targetUserId])});
        batch.update(targetUserRef, {'followers': FieldValue.arrayUnion([_currentUser!.uid])});
      } else {
        batch.update(currentUserRef, {'following': FieldValue.arrayRemove([targetUserId])});
        batch.update(targetUserRef, {'followers': FieldValue.arrayRemove([_currentUser!.uid])});
      }
      await batch.commit();
    } catch (e) {
      print("Error updating follow status: $e");
      String errorMessage = 'Failed to update follow status.';
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'Permission denied. Check Firestore rules.';
      } else if (e.toString().contains('NOT_FOUND')) {
        errorMessage = 'Target user document not found.';
      }
      if (mounted) {
        setState(() { _isFollowingAuthor = !newFollowingState; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Widget _buildRatingStarsList(double rating, {double size = 18.0}) {
    if (rating == 0) return const Text("Not Rated", style: TextStyle(fontSize: 12, color: Colors.grey));
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool halfStar = (rating - fullStars) >= 0.3;
    for (int i = 0; i < fullStars; i++) stars.add(Icon(Icons.star, color: Colors.amber, size: size));
    if (halfStar && fullStars < 5) stars.add(Icon(Icons.star_half, color: Colors.amber, size: size));
    for (int i = (fullStars + (halfStar ? 1 : 0)); i < 5; i++) stars.add(Icon(Icons.star_border, color: Colors.amber, size: size));
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final DateTime dateTime = timestamp.toDate();
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) return DateFormat('MMM d, yyyy').format(dateTime);
    if (diff.inDays > 30) return DateFormat('MMM d').format(dateTime);
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final postDataFromSnapshot = widget.postSnapshot.data() as Map<String, dynamic>;
    final postId = widget.postSnapshot.id;
    final String postAuthorId = postDataFromSnapshot['userId'] ?? '';
    final bool canFollow = _currentUser != null && _currentUser!.uid != postAuthorId;

    Uint8List? displayImageBytes;
    if (postDataFromSnapshot['imagesBase64'] != null && postDataFromSnapshot['imagesBase64'] is List && (postDataFromSnapshot['imagesBase64'] as List).isNotEmpty) {
      try { displayImageBytes = base64Decode((postDataFromSnapshot['imagesBase64'] as List)[0].toString()); } catch (e) {}
    } else if (postDataFromSnapshot['imageBase64'] != null && postDataFromSnapshot['imageBase64'].toString().isNotEmpty) {
      try { displayImageBytes = base64Decode(postDataFromSnapshot['imageBase64'].toString()); } catch (e) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(postData: postDataFromSnapshot, postId: postId),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (postAuthorId.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfilePage(userId: postAuthorId)));
                      }
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.orange[100],
                      backgroundImage: _authorProfileImageBytes != null ? MemoryImage(_authorProfileImageBytes!) : null,
                      child: _authorProfileImageBytes == null ? Icon(Icons.person, color: Colors.orange[700]) : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (postAuthorId.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfilePage(userId: postAuthorId)));
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_authorUsernameCurrent ?? postDataFromSnapshot['username'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(_timeAgo(postDataFromSnapshot['timestamp'] as Timestamp?), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ),
                  if (canFollow)
                    TextButton(
                      onPressed: () => _toggleFollowUser(postAuthorId),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(70, 30),
                          backgroundColor: _isFollowingAuthor ? Colors.orange.withOpacity(0.1) : Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: _isFollowingAuthor ? Colors.orange.shade300 : Colors.orange.shade700)
                          )
                      ),
                      child: Text(
                        _isFollowingAuthor ? 'Following' : 'Follow',
                        style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Text(postDataFromSnapshot['title'] ?? 'No Title', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(postDataFromSnapshot['content'] ?? '', style: TextStyle(fontSize: 14, color: Colors.grey[800]), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Text("Read More", style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w500)),
            ),
            if (displayImageBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Image.memory(displayImageBytes, height: 220, width: double.infinity, fit: BoxFit.cover),
              )
            else
              Container(
                height: 200,
                margin: const EdgeInsets.only(top: 8.0),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200]),
                child: Icon(Icons.image_search_outlined, size: 60, color: Colors.grey[400]),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isLikedLocal ? Icons.favorite : Icons.favorite_border,
                          color: _isLikedLocal ? Colors.pink : Colors.grey[600],
                          size: 22,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text(_likeCountLocal.toString(), style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[700], size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostCommentPage(
                                postId: postId,
                                postAuthorId: postAuthorId,
                              ),
                            ),
                          );
                        },
                      ),
                      Text(postDataFromSnapshot['commentsCount']?.toString() ?? '0', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  _buildRatingStarsList(postDataFromSnapshot['rating']?.toDouble() ?? 0.0, size: 20.0),
                  IconButton(
                    icon: Icon(
                      _isBookmarkedLocal ? Icons.bookmark : Icons.bookmark_border,
                      color: _isBookmarkedLocal ? Colors.orange[700] : Colors.grey[600],
                      size: 22,
                    ),
                    onPressed: _toggleBookmark,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
