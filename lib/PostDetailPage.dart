import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'OtherUserProfilePage.dart';
import 'PostCommentPage.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> initialPostData;
  final String postId;

  const PostDetailPage({
    Key? key,
    required Map<String, dynamic> postData,
    required this.postId,
  })  : initialPostData = postData,
        super(key: key);

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late List<Uint8List> _imageBytesList;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  User? _currentUser;

  Uint8List? _authorProfileImageBytes;
  String? _authorUsernameCurrent;
  bool _isBookmarked = false; // State for bookmark status

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _processImagesFromInitialData();
    _fetchAuthorDetails();
    _initializeBookmarkState(); // Initialize bookmark status
    // Like state is handled by StreamBuilder
  }

  void _processImagesFromInitialData() {
    var imagesData = widget.initialPostData['imagesBase64'];
    List<String> imagesBase64Strings = [];

    if (imagesData is List) {
      imagesBase64Strings =
      List<String>.from(imagesData.map((item) => item.toString()));
    } else if (imagesData is String && imagesData.isNotEmpty) {
      imagesBase64Strings = [imagesData];
    } else {
      imagesBase64Strings = [];
    }

    _imageBytesList = [];
    for (String base64String in imagesBase64Strings) {
      if (base64String.isNotEmpty) {
        try {
          _imageBytesList.add(base64Decode(base64String));
        } catch (e) {
          print("Error decoding base64 image in detail page: $e.");
        }
      }
    }
  }

  Future<void> _fetchAuthorDetails() async {
    final String? authorId = widget.initialPostData['userId'] as String?;
    if (authorId != null && authorId.isNotEmpty) {
      try {
        DocumentSnapshot authorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(authorId)
            .get();
        if (mounted && authorDoc.exists) {
          final authorData = authorDoc.data() as Map<String, dynamic>;
          setState(() {
            _authorUsernameCurrent = authorData['username'] ??
                widget.initialPostData['username'] ??
                'Anonymous';
            if (authorData['profileImageBase64'] != null &&
                authorData['profileImageBase64'].toString().isNotEmpty) {
              try {
                _authorProfileImageBytes =
                    base64Decode(authorData['profileImageBase64']);
              } catch (e) {
                print("Error decoding author's profileImageBase64: $e");
              }
            }
          });
        } else if (mounted) {
          setState(() => _authorUsernameCurrent =
              widget.initialPostData['username'] ?? 'Anonymous');
        }
      } catch (e) {
        print("Error fetching author's profile for detail page: $e");
        if (mounted)
          setState(() => _authorUsernameCurrent =
              widget.initialPostData['username'] ?? 'Anonymous');
      }
    } else if (mounted) {
      setState(() => _authorUsernameCurrent =
          widget.initialPostData['username'] ?? 'Anonymous');
    }
  }

  Future<void> _initializeBookmarkState() async {
    if (_currentUser == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (mounted && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final List<dynamic> savedPosts = userData['savedPosts'] ?? [];
        setState(() {
          _isBookmarked = savedPosts.contains(widget.postId);
        });
      }
    } catch (e) {
      print("Error initializing bookmark state: $e");
    }
  }

  Future<void> _toggleLike(bool currentIsLikedState) async {
    if (_currentUser == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login to like posts.')));
      return;
    }
    final postRef =
    FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final String currentUserId = _currentUser!.uid;
    try {
      if (currentIsLikedState) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([currentUserId])
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([currentUserId])
        });
      }
    } catch (e) {
      print("Error updating like status from DetailPage: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to update like. Please try again.')));
    }
  }

  Future<void> _toggleBookmark() async {
    final userRef =
    FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
    final String currentPostId = widget.postId;
    final bool newBookmarkState = !_isBookmarked;

    if (mounted) setState(() => _isBookmarked = newBookmarkState);

    try {
      if (newBookmarkState) {
        // If we are bookmarking
        await userRef.update({
          'savedPosts': FieldValue.arrayUnion([currentPostId])
        });
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Post saved!')));
      } else {
        // If we are unbookmarking
        await userRef.update({
          'savedPosts': FieldValue.arrayRemove([currentPostId])
        });
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Post unsaved.')));
      }
    } catch (e) {
      print("Error updating bookmark status: $e");
      if (mounted) {
        // Revert UI on error
        setState(() => _isBookmarked = !newBookmarkState);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update save status.')));
      }
    }
  }

  Widget _buildRatingStars(double rating) {
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      stars.add(Icon(i <= rating ? Icons.star : Icons.star_border,
          color: Colors.amber, size: 20));
    }
    if (rating == 0)
      return const Text("Not rated",
          style: TextStyle(fontSize: 14, color: Colors.grey));
    return Row(children: stars);
  }

  Widget _buildImageIndicator() {
    if (_imageBytesList.length <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _imageBytesList.asMap().entries.map((entry) {
        int index = entry.key;
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentImageIndex == index
                ? Colors.orange
                : Colors.grey.shade400,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Timestamp? timestamp =
    widget.initialPostData['timestamp'] as Timestamp?;
    final String formattedDate = timestamp != null
        ? DateFormat('d MMM yyyy hh:mm a').format(timestamp.toDate())
        : 'Date unavailable';
    final String postAuthorId = widget.initialPostData['userId'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Food.png',
              width: 70,
              height: 70,
            ),
            const SizedBox(width: 10),
            const Text(
              'FoodSpot',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.white : Colors.white70,
            ),
            onPressed: _toggleBookmark,
            tooltip: _isBookmarked ? 'Unsave Post' : 'Save Post',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author Info Header
            InkWell(
              onTap: () {
                if (postAuthorId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            OtherUserProfilePage(userId: postAuthorId)),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.orange[100],
                      backgroundImage: _authorProfileImageBytes != null
                          ? MemoryImage(_authorProfileImageBytes!)
                          : null,
                      child: _authorProfileImageBytes == null
                          ? Icon(Icons.person,
                          color: Colors.orange[700], size: 25)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _authorUsernameCurrent ??
                                widget.initialPostData['username'] ??
                                'Anonymous',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          Text('Posted at ' + formattedDate,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Title
            Text(
              widget.initialPostData['title'] ?? 'No Title',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Images (if any)
            if (_imageBytesList.isNotEmpty)
              Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _imageBytesList.length,
                      onPageChanged: (index) {
                        if (mounted) setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.memory(
                              _imageBytesList[index],
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                      decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                          BorderRadius.circular(12.0)),
                                      child: const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 50, color: Colors.grey))),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildImageIndicator(),
                  const SizedBox(height: 16),
                ],
              )
            else
              Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12.0)),
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 60, color: Colors.grey[600])),

            const SizedBox(height: 16),
            Text(
              widget.initialPostData['content'] ?? 'No content available.',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
            Divider(
              color: Colors.grey[400],
              thickness: 0.5,
              indent: 8,
              endIndent: 8,
            ),
            const SizedBox(height: 20),

            // Restaurant Info
            if (widget.initialPostData['restaurant'] != null &&
                widget.initialPostData['restaurant'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.restaurant, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialPostData['restaurant'],
                      style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),

            // Location
            if (widget.initialPostData['location'] != null &&
                widget.initialPostData['location'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialPostData['location'],
                      style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),

            // Rating
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  Text('Rating: ',
                      style: TextStyle(fontSize: 15, color: Colors.grey[800])),
                  _buildRatingStars(
                      widget.initialPostData['rating']?.toDouble() ?? 0.0),
                ],
              ),
            ),

            // Like and Comment Buttons
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                          icon: Icon(Icons.favorite_border,
                              color: Colors.grey[700]),
                          label: Text("Like (0)",
                              style: TextStyle(color: Colors.grey[700])),
                          onPressed: null),
                      TextButton.icon(
                        icon: Icon(Icons.comment_outlined,
                            color: Colors.grey[700]),
                        label: Text(
                            "Comment (${widget.initialPostData['commentsCount'] ?? 0})",
                            style: TextStyle(color: Colors.grey[700])),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostCommentPage(
                                postId: widget.postId,
                                postAuthorId: postAuthorId,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }

                final postDataFromStream =
                    snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final List<dynamic> likes = postDataFromStream['likes'] ?? [];
                final bool isCurrentlyLiked = _currentUser != null &&
                    likes
                        .map((l) => l.toString())
                        .contains(_currentUser!.uid.toString());
                final int currentLikeCount = likes.length;
                final int commentsCount =
                    postDataFromStream['commentsCount'] ?? 0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                          isCurrentlyLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isCurrentlyLiked
                              ? Colors.pink
                              : Colors.grey[700]),
                      label: Text("Like ($currentLikeCount)",
                          style: TextStyle(
                              color: isCurrentlyLiked
                                  ? Colors.pink
                                  : Colors.grey[700])),
                      onPressed: () => _toggleLike(isCurrentlyLiked),
                    ),
                    TextButton.icon(
                      icon:
                      Icon(Icons.comment_outlined, color: Colors.grey[700]),
                      label: Text("Comment ($commentsCount)",
                          style: TextStyle(color: Colors.grey[700])),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostCommentPage(
                              postId: widget.postId,
                              postAuthorId: postAuthorId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
