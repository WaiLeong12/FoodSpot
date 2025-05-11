import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'OtherUserProfilePage.dart';

class PostCommentPage extends StatefulWidget {
  final String postId;
  final String postAuthorId;

  const PostCommentPage({
    Key? key,
    required this.postId,
    required this.postAuthorId,
  }) : super(key: key);

  @override
  _PostCommentPageState createState() => _PostCommentPageState();
}

class _PostCommentPageState extends State<PostCommentPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  User? _currentUser;
  bool _isPostingComment = false;
  DocumentSnapshot? _currentUserDoc;
  bool _isLoadingMore = false;
  bool _hasMoreComments = true;
  DocumentSnapshot? _lastCommentSnapshot;
  final int _commentsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadCurrentUserDoc();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserDoc() async {
    if (_currentUser != null) {
      _currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreComments();
    }
  }

  Future<void> _loadMoreComments() async {
    if (!_hasMoreComments || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .limit(_commentsPerPage);

      if (_lastCommentSnapshot != null) {
        query = query.startAfterDocument(_lastCommentSnapshot!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < _commentsPerPage) {
        _hasMoreComments = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastCommentSnapshot = snapshot.docs.last;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more comments: $e')),
      );
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _currentUser == null || _currentUserDoc == null) return;

    setState(() => _isPostingComment = true);

    try {
      final userData = _currentUserDoc!.data() as Map<String, dynamic>;
      final username = userData['username'] ?? _currentUser?.displayName ?? 'Anonymous';
      final profileImageBase64 = userData['profileImageBase64'] as String?;

      // Add comment
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': _currentUser!.uid,
        'username': username,
        if (profileImageBase64 != null) 'profileImageBase64': profileImageBase64,
        'text': commentText,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      // Update comment count
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'commentsCount': FieldValue.increment(1)});

      _commentController.clear();
      FocusScope.of(context).unfocus();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    } finally {
      setState(() => _isPostingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: false)
                  .limit(_commentsPerPage)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first to comment!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: snapshot.data!.docs.length + (_hasMoreComments ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= snapshot.data!.docs.length) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final commentDoc = snapshot.data!.docs[index];
                    return CommentCardItem(
                      commentSnapshot: commentDoc,
                      postId: widget.postId,
                      currentUserId: _currentUser?.uid,
                    );
                  },
                );
              },
            ),
          ),
          if (_currentUser != null)
            _buildCommentInputField(),
        ],
      ),
    );
  }

  Widget _buildCommentInputField() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          IconButton(
            icon: _isPostingComment
                ? const CircularProgressIndicator()
                : const Icon(Icons.send, color: Colors.orange),
            onPressed: _isPostingComment ? null : _addComment,
          ),
        ],
      ),
    );
  }
}

class CommentCardItem extends StatefulWidget {
  final DocumentSnapshot commentSnapshot;
  final String postId;
  final String? currentUserId;

  const CommentCardItem({
    Key? key,
    required this.commentSnapshot,
    required this.postId,
    this.currentUserId,
  }) : super(key: key);

  @override
  _CommentCardItemState createState() => _CommentCardItemState();
}

class _CommentCardItemState extends State<CommentCardItem> {
  late Map<String, dynamic> _commentData;
  bool _isLiked = false;
  int _likeCount = 0;
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _commentData = widget.commentSnapshot.data() as Map<String, dynamic>;
    _initializeLikeState();
    _loadProfileImage();
  }

  void _initializeLikeState() {
    final likes = _commentData['likes'] as List? ?? [];
    _isLiked = widget.currentUserId != null &&
        likes.contains(widget.currentUserId);
    _likeCount = likes.length;
  }

  void _loadProfileImage() {
    final imageBase64 = _commentData['profileImageBase64'] as String?;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        _profileImageBytes = base64Decode(imageBase64);
      } catch (e) {
        print("Error decoding profile image: $e");
      }
    }
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      await widget.commentSnapshot.reference.update({
        'likes': _isLiked
            ? FieldValue.arrayUnion([widget.currentUserId])
            : FieldValue.arrayRemove([widget.currentUserId])
      });
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? -1 : 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update like')),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 7) return DateFormat('MMM d, yyyy').format(date);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final userId = _commentData['userId'];
                  if (userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OtherUserProfilePage(userId: userId),
                      ),
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: _profileImageBytes != null
                      ? MemoryImage(_profileImageBytes!)
                      : null,
                  child: _profileImageBytes == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _commentData['username'] ?? 'Anonymous',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(_commentData['timestamp'] as Timestamp?),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_commentData['text'] ?? ''),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: _isLiked ? Colors.pink : Colors.grey,
                ),
                onPressed: _toggleLike,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                _likeCount.toString(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}