import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'PostDetailPage.dart';

class SavedPostPage extends StatefulWidget {
  const SavedPostPage({super.key});

  @override
  State<SavedPostPage> createState() => _SavedPostPageState();
}

class _SavedPostPageState extends State<SavedPostPage> {
  User? _currentUser;
  List<String> _savedPostIds = [];
  bool _isLoading = true;
  Map<String, DocumentSnapshot> _loadedPosts = {};

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchSavedPostIdsAndPosts();
  }

  Future<void> _fetchSavedPostIdsAndPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (_currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _savedPostIds = List<String>.from(userData['savedPosts'] ?? []);
      } else {
        _savedPostIds = [];
      }

      if (_savedPostIds.isNotEmpty) {
        List<DocumentSnapshot> fetchedDocs = [];
        List<List<String>> chunks = [];
        for (var i = 0; i < _savedPostIds.length; i += 10) {
          chunks.add(
              _savedPostIds.sublist(i, i + 10 > _savedPostIds.length ? _savedPostIds.length : i + 10)
          );
        }

        for (var chunk in chunks) {
          if (chunk.isNotEmpty) {
            QuerySnapshot postsSnapshot = await FirebaseFirestore.instance
                .collection('posts')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            fetchedDocs.addAll(postsSnapshot.docs);
          }
        }

        Map<String, DocumentSnapshot> postsMap = { for (var doc in fetchedDocs) doc.id : doc };
        Map<String, DocumentSnapshot> orderedPostsMap = {};
        for(String id in _savedPostIds.reversed){ // Show most recently saved first
          if(postsMap.containsKey(id)){
            orderedPostsMap[id] = postsMap[id]!;
          }
        }
        _loadedPosts = orderedPostsMap;
      } else {
        _loadedPosts = {};
      }
    } catch (e) {
      print("Error fetching saved posts: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved posts: ${e.toString()}')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _handleUnsavePost(String postId) {
    if (_currentUser == null) return;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);

    userDocRef.update({
      'savedPosts': FieldValue.arrayRemove([postId])
    }).then((_) {
      if (mounted) {
        setState(() {
          _savedPostIds.remove(postId);
          _loadedPosts.remove(postId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post unsaved successfully.')),
        );
      }
    }).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unsave post: $error')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      // AppBar is managed by FoodMain.dart (or the parent navigator)
      // appBar: AppBar(
      //   title: const Text('Saved Posts'),
      //   backgroundColor: Colors.orange,
      // ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange));
    }
    if (_currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login, size: 50, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Please log in to see your saved posts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                child: const Text('Go to Login', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    // Use the _loadedPosts.values directly as it's already ordered or filtered
    // final orderedPostSnapshots = _savedPostIds.map((id) => _loadedPosts[id]).where((doc) => doc != null).toList();
    // If _loadedPosts is already ordered by _savedPostIds.reversed:
    final postSnapshotsToDisplay = _loadedPosts.values.toList();


    if (postSnapshotsToDisplay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border_outlined, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'You haven\'t saved any posts yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the bookmark icon on posts to save them here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      itemCount: postSnapshotsToDisplay.length,
      itemBuilder: (context, index) {
        final postSnapshot = postSnapshotsToDisplay[index];
        return SavedPostCardItemStateful(
            postSnapshot: postSnapshot,
            onUnsave: () => _handleUnsavePost(postSnapshot.id),
            onNavigateBack: () {
              if (mounted) {
                _fetchSavedPostIdsAndPosts();
              }
            }
        );
      },
    );
  }
}

class SavedPostCardItemStateful extends StatefulWidget {
  final DocumentSnapshot postSnapshot;
  final VoidCallback onUnsave;
  final VoidCallback? onNavigateBack;

  const SavedPostCardItemStateful({
    Key? key,
    required this.postSnapshot,
    required this.onUnsave,
    this.onNavigateBack,
  }) : super(key: key);

  @override
  _SavedPostCardItemStatefulState createState() =>
      _SavedPostCardItemStatefulState();
}

class _SavedPostCardItemStatefulState extends State<SavedPostCardItemStateful> {
  User? _currentUser;
  bool _isLiked = false;
  int _likeCount = 0;
  // For author's details
  Uint8List? _authorProfileImageBytes;
  String? _authorUsername;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadInitialStates();
  }

  @override
  void didUpdateWidget(covariant SavedPostCardItemStateful oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postSnapshot.id != oldWidget.postSnapshot.id ||
        !_arePostDataLikesEqual(
            widget.postSnapshot.data() as Map<String, dynamic>?,
            oldWidget.postSnapshot.data() as Map<String, dynamic>?)) {
      _loadInitialStates();
    }
  }

  bool _arePostDataLikesEqual(
      Map<String, dynamic>? newData, Map<String, dynamic>? oldData) {
    if (newData == null && oldData == null) return true;
    if (newData == null || oldData == null) return false;
    return listEquals(newData['likes'] as List?, oldData['likes'] as List?);
  }

  Future<void> _loadInitialStates() async {
    final data = widget.postSnapshot.data() as Map<String, dynamic>;
    Uint8List? authorImgBytes;
    String? fetchedAuthorUsername = data['username']; // Default to stored username

    // Load author's profile image and current username
    final String? authorId = data['userId'] as String?;
    if (authorId != null && authorId.isNotEmpty) {
      try {
        DocumentSnapshot authorDoc = await FirebaseFirestore.instance.collection('users').doc(authorId).get();
        if (authorDoc.exists) {
          final authorData = authorDoc.data() as Map<String, dynamic>;
          fetchedAuthorUsername = authorData['username'] ?? data['username'] ?? 'Anonymous';
          if (authorData['profileImageBase64'] != null && authorData['profileImageBase64'].toString().isNotEmpty) {
            try {
              authorImgBytes = base64Decode(authorData['profileImageBase64']);
            } catch (e) {
              print("Error decoding author profileImageBase64 for saved post ${widget.postSnapshot.id}: $e");
            }
          }
        }
      } catch (e) {
        print("Error fetching author's profile for saved post ${widget.postSnapshot.id}: $e");
      }
    }

    if (_currentUser != null) {
      final List<dynamic> likes = data['likes'] ?? [];
      _isLiked = likes.map((like) => like.toString()).contains(_currentUser!.uid.toString());
    }

    if(mounted){
      setState(() {
        _likeCount = (data['likes'] as List?)?.length ?? 0;
        _authorProfileImageBytes = authorImgBytes;
        _authorUsername = fetchedAuthorUsername;
      });
    } else {
      // If not mounted, just set instance variables directly
      _likeCount = (data['likes'] as List?)?.length ?? 0;
      _authorProfileImageBytes = authorImgBytes;
      _authorUsername = fetchedAuthorUsername;
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like posts.')),
      );
      return;
    }
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postSnapshot.id);
    final String currentUserId = _currentUser!.uid;
    final bool newIsLikedState = !_isLiked;

    if (mounted) {
      setState(() {
        _isLiked = newIsLikedState;
        if (newIsLikedState) _likeCount++; else _likeCount--;
      });
    }

    try {
      if (newIsLikedState) {
        await postRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
      } else {
        await postRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
      }
    } catch (e) {
      print("Error updating like status on saved page: $e");
      if (mounted) {
        setState(() {
          _isLiked = !newIsLikedState;
          if (newIsLikedState) _likeCount--; else _likeCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like status.')),
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
    final data = widget.postSnapshot.data() as Map<String, dynamic>;
    final postId = widget.postSnapshot.id;

    Uint8List? displayImageBytes;
    if (data['imagesBase64'] != null && data['imagesBase64'] is List && (data['imagesBase64'] as List).isNotEmpty) {
      try {
        displayImageBytes = base64Decode((data['imagesBase64'] as List)[0].toString());
      } catch (e) {
        print("Error decoding first image from list for saved post: $e");
      }
    } else if (data['imageBase64'] != null && data['imageBase64'].toString().isNotEmpty) {
      try {
        displayImageBytes = base64Decode(data['imageBase64'].toString());
      } catch (e) {
        print("Error decoding single imageBase64 for saved post: $e");
      }
    }

    final String timeAgo = _timeAgo(data['timestamp'] as Timestamp?);
    final String postAuthorId = data['userId'] ?? '';
    final bool canFollow = _currentUser != null && _currentUser!.uid != postAuthorId;

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
              builder: (context) => PostDetailPage(postData: data, postId: postId),
            ),
          ).then((value) {
            widget.onNavigateBack?.call();
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange[100],
                    backgroundImage: _authorProfileImageBytes != null ? MemoryImage(_authorProfileImageBytes!) : null,
                    child: _authorProfileImageBytes == null ? Icon(Icons.person, color: Colors.orange[700]) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_authorUsername ?? data['username'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(timeAgo, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  if (canFollow)
                    TextButton(
                      onPressed: () { /* TODO: Implement Follow logic */ },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50,30)),
                      child: Text(
                        'Follow',
                        style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Text(data['title'] ?? 'No Title', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(data['content'] ?? '', style: TextStyle(fontSize: 14, color: Colors.grey[800]), maxLines: 2, overflow: TextOverflow.ellipsis),
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
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.pink : Colors.grey[600],
                          size: 22,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text(_likeCount.toString(), style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline, color: Colors.grey[700], size: 18),
                      const SizedBox(width: 4),
                      Text(data['commentsCount']?.toString() ?? '0', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  _buildRatingStarsList(data['rating']?.toDouble() ?? 0.0, size: 20.0),
                  IconButton(
                    icon: Icon(Icons.bookmark, color: Colors.orange[700], size: 22),
                    onPressed: widget.onUnsave,
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
