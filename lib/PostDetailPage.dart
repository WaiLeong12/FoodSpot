import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'PostCommentPage.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId;

  const PostDetailPage({
    Key? key,
    required this.postData,
    required this.postId,
  }) : super(key: key);

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late List<String> _imagesBase64;
  late List<Uint8List> _imageBytesList;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  User? _currentUser;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _processImages();
    _initializeLikeState();
    _loadCommentCount();
  }

  void _processImages() {
    var imagesData = widget.postData['imagesBase64'];
    if (imagesData is List) {
      _imagesBase64 = List<String>.from(imagesData.map((item) => item.toString()));
    } else if (imagesData is String && imagesData.isNotEmpty) {
      _imagesBase64 = [imagesData];
    } else {
      _imagesBase64 = [];
    }

    _imageBytesList = _imagesBase64
        .where((base64String) => base64String.isNotEmpty)
        .map((base64String) {
      try {
        return base64Decode(base64String);
      } catch (e) {
        print("Error decoding image: $e");
        return Uint8List(0);
      }
    })
        .where((bytes) => bytes.isNotEmpty)
        .toList();

    setState(() => _isLoading = false);
  }

  void _initializeLikeState() {
    if (_currentUser != null) {
      final List<dynamic> likes = widget.postData['likes'] ?? [];
      _isLiked = likes.map((like) => like.toString()).contains(_currentUser!.uid);
    }
    _likeCount = (widget.postData['likes'] as List?)?.length ?? 0;
  }

  Future<void> _loadCommentCount() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (doc.exists) {
        setState(() {
          _commentCount = doc.data()?['commentsCount'] ?? 0;
        });
      }
    } catch (e) {
      print("Error loading comment count: $e");
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like posts.')),
      );
      return;
    }

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final String currentUserId = _currentUser!.uid;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      await postRef.update({
        'likes': _isLiked
            ? FieldValue.arrayUnion([currentUserId])
            : FieldValue.arrayRemove([currentUserId])
      });
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? -1 : 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update like status.')),
      );
    }
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) => Icon(
        index < rating ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 20,
      )),
    );
  }

  Widget _buildImageIndicator() {
    if (_imageBytesList.length <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _imageBytesList.asMap().entries.map((entry) {
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentImageIndex == entry.key
                ? Colors.orange
                : Colors.grey.shade400,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Timestamp? timestamp = widget.postData['timestamp'] as Timestamp?;
    final String formattedDate = timestamp != null
        ? DateFormat('MMM d, yyyy hh:mm a').format(timestamp.toDate())
        : 'Date unavailable';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.postData['title'] ?? 'Post Details'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery
            if (_imageBytesList.isNotEmpty)
              Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _imageBytesList.length,
                      onPageChanged: (index) => setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.memory(
                              _imageBytesList[index],
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(child: Icon(Icons.broken_image)),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildImageIndicator(),
                ],
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Icon(Icons.image_not_supported_outlined, size: 60),
              ),

            // Post Title
            const SizedBox(height: 16),
            Text(
              widget.postData['title'] ?? 'No Title',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            // Author and Date
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'By: ${widget.postData['username'] ?? 'Anonymous'}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),

            // Restaurant Information
            if (widget.postData['restaurant'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant, size: 18),
                    const SizedBox(width: 8),
                    Text(widget.postData['restaurant']),
                  ],
                ),
              ),

            // Location
            if (widget.postData['location'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(widget.postData['location']),
                  ],
                ),
              ),

            // Rating
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Text('Rating: '),
                  _buildRatingStars(widget.postData['rating']?.toDouble() ?? 0.0),
                ],
              ),
            ),

            // Divider and Content
            const Divider(height: 24, thickness: 1),
            Text(
              widget.postData['content'] ?? 'No content available.',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),

            // Action Buttons
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.pink : Colors.grey[700],
                  ),
                  label: Text("Like ($_likeCount)"),
                  onPressed: _toggleLike,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.comment_outlined),
                  label: Text("Comment ($_commentCount)"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostCommentPage(
                          postId: widget.postId,
                          postAuthorId: widget.postData['userId'] ?? '',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}