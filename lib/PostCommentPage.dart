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
  final FocusNode _mainCommentFocusNode = FocusNode();
  User? _currentUser;
  bool _isPostingComment = false;
  Map<String, dynamic>? _currentUserProfileData;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadCurrentUserProfileData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _mainCommentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserProfileData() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        if (mounted && userDoc.exists) {
          _currentUserProfileData = userDoc.data() as Map<String, dynamic>;
        } else {
          print("Current user document not found in Firestore.");
        }
      } catch (e) {
        print("Error loading current user profile: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error loading your profile: ${e.toString()}")));
        }
      }
    }
    if (mounted) {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot be empty.')),
      );
      return;
    }
    if (_currentUser == null || _currentUserProfileData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in and profile loaded to comment.')),
      );
      return;
    }

    setState(() => _isPostingComment = true);

    final String username = _currentUserProfileData!['username'] ?? _currentUser?.displayName ?? 'Anonymous';
    final String? profileImageBase64 = _currentUserProfileData!['profileImageBase64'] as String?;

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': _currentUser!.uid,
        'username': username,
        if (profileImageBase64 != null && profileImageBase64.isNotEmpty)
          'profileImageBase64': profileImageBase64,
        'text': commentText,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'replyCount': 0,
      });

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'commentsCount': FieldValue.increment(1)});

      _commentController.clear();
      if (mounted) _mainCommentFocusNode.unfocus();
    } catch (e) {
      print("Error adding comment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading comments: ${snapshot.error.toString()}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first to comment!',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  );
                }
                final comments = snapshot.data!.docs;
                return ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final commentDoc = comments[index];
                    return CommentCardItem(
                      key: ValueKey(commentDoc.id),
                      commentSnapshot: commentDoc, // This is widget.commentSnapshot in CommentCardItem
                      postId: widget.postId,
                      currentUserProfileData: _currentUserProfileData,
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
      padding: EdgeInsets.only(left: 16.0, right: 8.0, top: 10.0, bottom: MediaQuery.of(context).viewInsets.bottom + 10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _mainCommentFocusNode,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(color: Colors.orange.shade400, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => (_isPostingComment || _isLoadingProfile) ? null : _addComment(),
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(width: 8.0),
          (_isPostingComment || _isLoadingProfile)
              ? const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.orange)),
          )
              : IconButton(
            icon: Icon(Icons.send_rounded, color: Colors.orange[700], size: 28),
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }
}

class CommentCardItem extends StatefulWidget {
  final DocumentSnapshot commentSnapshot; // Property to hold the comment data
  final String postId;
  final Map<String, dynamic>? currentUserProfileData;

  const CommentCardItem({
    Key? key,
    required this.commentSnapshot, // Make sure this is passed correctly
    required this.postId,
    this.currentUserProfileData,
  }) : super(key: key);

  @override
  _CommentCardItemState createState() => _CommentCardItemState();
}

class _CommentCardItemState extends State<CommentCardItem> {
  User? _currentUser;
  Map<String, dynamic>? _commenterData;
  Uint8List? _commenterProfileImageBytes;
  bool _isCommentLiked = false;
  int _commentLikeCount = 0;
  bool _isLoadingCommenterProfile = true;
  bool _showReplies = false;
  // bool _isReplying = false; // Not needed for AlertDialog approach
  // final TextEditingController _replyController = TextEditingController(); // Moved to dialog
  // final FocusNode _replyFocusNode = FocusNode(); // Moved to dialog

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadCommenterDataAndInitializeLike();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCommenterDataAndInitializeLike() async {
    if (!mounted || !widget.commentSnapshot.exists) return;
    // Access comment data using widget.commentSnapshot
    final commentData = widget.commentSnapshot.data() as Map<String, dynamic>;
    final String? commenterId = commentData['userId'] as String?;

    if (commenterId != null && commenterId.isNotEmpty) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(commenterId).get();
        if (mounted && userDoc.exists) {
          _commenterData = userDoc.data() as Map<String, dynamic>;
          if (_commenterData!['profileImageBase64'] != null && _commenterData!['profileImageBase64'].toString().isNotEmpty) {
            try { _commenterProfileImageBytes = base64Decode(_commenterData!['profileImageBase64']); } catch (e) {}
          }
        }
      } catch (e) { print("Error fetching commenter data for comment ${widget.commentSnapshot.id}: $e"); }
    }

    if (_currentUser != null) {
      final List<dynamic> likes = commentData['likes'] ?? [];
      _isCommentLiked = likes.map((like) => like.toString()).contains(_currentUser!.uid.toString());
    }
    _commentLikeCount = (commentData['likes'] as List?)?.length ?? 0;

    if (mounted) setState(() => _isLoadingCommenterProfile = false);
  }

  Future<void> _toggleCommentLike() async {
    if (_currentUser == null) { return; }
    // Use widget.commentSnapshot.id for the comment's ID
    final commentRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').doc(widget.commentSnapshot.id);
    final String currentUserId = _currentUser!.uid;
    final bool newIsLikedState = !_isCommentLiked;
    if (mounted) {
      setState(() {
        _isCommentLiked = newIsLikedState;
        if (newIsLikedState) _commentLikeCount++; else _commentLikeCount--;
      });
    }
    try {
      if (newIsLikedState) await commentRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
      else await commentRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCommentLiked = !newIsLikedState;
          if (newIsLikedState) _commentLikeCount--; else _commentLikeCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update like.')));
      }
    }
  }

  void _showReplyDialog() {
    final commentDataForDialog = widget.commentSnapshot.data() as Map<String, dynamic>?;
    final String commenterNameForDialog = _commenterData?['username'] ?? commentDataForDialog?['username'] ?? 'Comment';

    final replyController = TextEditingController();
    final replyFocusNode = FocusNode();
    bool isPostingReply = false;

    replyController.clear();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: Text('Reply to $commenterNameForDialog'),
              contentPadding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 0),
              content: TextField(
                controller: replyController,
                focusNode: replyFocusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Write your reply...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  onPressed: isPostingReply ? null : () async {
                    final replyText = replyController.text.trim();
                    if (replyText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reply cannot be empty.')),
                      );
                      return;
                    }

                    // Close dialog immediately
                    Navigator.of(dialogContext).pop();

                    // Post reply in background
                    try {
                      await _postReply(replyText, widget.commentSnapshot.id);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to post reply: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Post Reply'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Clean up when dialog is dismissed
      replyController.clear();
      replyFocusNode.unfocus();
    });
  }

  void _toggleShowReplies(int currentReplyCount) {
    if (currentReplyCount > 0) {
      setState(() {
        _showReplies = !_showReplies;
      });
    } else {
      _showReplyDialog();
    }
  }

  Future<void> _postReply(String replyText, String parentCommentId) async {
    if (_currentUser == null || widget.currentUserProfileData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login and profile data needed to reply.')));
      return;
    }

    final String username = widget.currentUserProfileData!['username'] ?? _currentUser?.displayName ?? 'Anonymous';
    final String? profileImageBase64 = widget.currentUserProfileData!['profileImageBase64'] as String?;

    try {
      print("Attempting to post REPLY by user: $username to comment: $parentCommentId for post: ${widget.postId}");
      await FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .collection('comments').doc(parentCommentId)
          .collection('replies').add({
        'userId': _currentUser!.uid,
        'username': username,
        if (profileImageBase64 != null && profileImageBase64.isNotEmpty)
          'profileImageBase64': profileImageBase64,
        'text': replyText,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      await FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .collection('comments').doc(parentCommentId)
          .update({'replyCount': FieldValue.increment(1)});

      if(mounted) setState(() {
        _showReplies = true;
      });
    } catch (e) {
      print("Error posting reply: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post reply: $e')));
    }
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final DateTime dateTime = timestamp.toDate();
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) return DateFormat('MMM d, yy').format(dateTime);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCommenterProfile && _commenterData == null) {
      return Card(margin: const EdgeInsets.symmetric(vertical: 6.0), child: const SizedBox(height: 70, child: Center(child: SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2)))));
    }

    // Use widget.commentSnapshot to access data for the current comment
    final commentData = widget.commentSnapshot.data() as Map<String, dynamic>;
    final String commenterUserId = commentData['userId'] ?? '';
    final String commenterName = _commenterData?['username'] ?? commentData['username'] ?? 'Anonymous';
    final String commentText = commentData['text'] ?? '';
    final Timestamp? timestamp = commentData['timestamp'] as Timestamp?;
    final int replyCount = commentData['replyCount'] ?? 0;

    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row( // Main Comment Content
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (commenterUserId.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfilePage(userId: commenterUserId)));
                    }
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.orange[100],
                    backgroundImage: _commenterProfileImageBytes != null ? MemoryImage(_commenterProfileImageBytes!) : null,
                    child: _commenterProfileImageBytes == null ? Icon(Icons.person, size: 18, color: Colors.orange[600]) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                if (commenterUserId.isNotEmpty) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfilePage(userId: commenterUserId)));
                                }
                              },
                              child: Text(commenterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text("· ${_timeAgo(timestamp)}", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(commentText, style: const TextStyle(fontSize: 14.5, height: 1.35)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: _toggleCommentLike,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0, top:2, bottom: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_isCommentLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 17, color: _isCommentLiked ? Colors.pink : Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(_commentLikeCount.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: _showReplyDialog,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                              child: Text('Reply', style: TextStyle(fontSize: 12, color: Colors.blueAccent[700], fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // "View/Hide Replies" Toggle and Replies List
            if (replyCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 48.0, top: 10.0),
                child: InkWell(
                  onTap: () => _toggleShowReplies(replyCount),
                  child: Text(
                    _showReplies ? 'Hide replies' : 'View $replyCount ${replyCount == 1 ? "reply" : "replies"}',
                    style: TextStyle(fontSize: 12.5, color: Colors.blueAccent[700], fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (_showReplies && replyCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 38.0, top: 6.0, right: 0.0),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts').doc(widget.postId)
                      .collection('comments').doc(widget.commentSnapshot.id) // Use widget.commentSnapshot.id here
                      .collection('replies')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, replySnapshot) {
                    if (replySnapshot.connectionState == ConnectionState.waiting && !(replySnapshot.hasData && replySnapshot.data!.docs.isNotEmpty) ) {
                      return const Padding(padding: EdgeInsets.symmetric(vertical: 4.0), child: SizedBox(height:10, child: Center(child: LinearProgressIndicator(color: Colors.orange, minHeight: 2,))));
                    }
                    if (replySnapshot.hasError) return Text(" Error loading replies", style: TextStyle(fontSize: 11, color: Colors.red[700]));
                    if (!replySnapshot.hasData || replySnapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final replies = replySnapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: replies.length,
                      itemBuilder: (context, index) {
                        return ReplyCardItem(
                          key: ValueKey(replies[index].id),
                          replySnapshot: replies[index],
                          postId: widget.postId,
                          parentCommentId: widget.commentSnapshot.id, // Use widget.commentSnapshot.id here
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReplyCardItem extends StatefulWidget {
  final DocumentSnapshot replySnapshot;
  final String postId;
  final String parentCommentId;

  const ReplyCardItem({
    Key? key,
    required this.replySnapshot,
    required this.postId,
    required this.parentCommentId,
  }) : super(key: key);

  @override
  _ReplyCardItemState createState() => _ReplyCardItemState();
}

class _ReplyCardItemState extends State<ReplyCardItem> {
  User? _currentUser;
  Map<String, dynamic>? _replierData;
  Uint8List? _replierProfileImageBytes;
  bool _isReplyLiked = false;
  int _replyLikeCount = 0;
  bool _isLoadingReplierProfile = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadReplyAuthorDataAndInitializeLike();
  }

  @override
  void didUpdateWidget(covariant ReplyCardItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replySnapshot.id != oldWidget.replySnapshot.id) {
      _loadReplyAuthorDataAndInitializeLike();
    }
  }

  Future<void> _loadReplyAuthorDataAndInitializeLike() async {
    if (!mounted || !widget.replySnapshot.exists) return;
    final replyData = widget.replySnapshot.data() as Map<String, dynamic>;
    final String? replierId = replyData['userId'] as String?;

    if (replierId != null && replierId.isNotEmpty) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(replierId).get();
        if (mounted && userDoc.exists) {
          _replierData = userDoc.data() as Map<String, dynamic>;
          if (_replierData!['profileImageBase64'] != null && _replierData!['profileImageBase64'].toString().isNotEmpty) {
            try { _replierProfileImageBytes = base64Decode(_replierData!['profileImageBase64']); } catch (e) {}
          }
        }
      } catch (e) { print("Error fetching replier data for reply ${widget.replySnapshot.id}: $e"); }
    }

    if (_currentUser != null) {
      final List<dynamic> likes = replyData['likes'] ?? [];
      _isReplyLiked = likes.map((like) => like.toString()).contains(_currentUser!.uid.toString());
    }
    _replyLikeCount = (replyData['likes'] as List?)?.length ?? 0;

    if (mounted) setState(() => _isLoadingReplierProfile = false);
  }

  Future<void> _toggleReplyLike() async {
    if (_currentUser == null) { /* ... */ return; }
    final replyRef = FirebaseFirestore.instance
        .collection('posts').doc(widget.postId)
        .collection('comments').doc(widget.parentCommentId)
        .collection('replies').doc(widget.replySnapshot.id);
    final String currentUserId = _currentUser!.uid;
    final bool newIsLikedState = !_isReplyLiked;

    if (mounted) {
      setState(() {
        _isReplyLiked = newIsLikedState;
        if (newIsLikedState) _replyLikeCount++; else _replyLikeCount--;
      });
    }
    try {
      if (newIsLikedState) await replyRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
      else await replyRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReplyLiked = !newIsLikedState;
          if (newIsLikedState) _replyLikeCount--; else _replyLikeCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update like for reply.')));
      }
    }
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final DateTime dateTime = timestamp.toDate();
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) return DateFormat('MMM d').format(dateTime);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingReplierProfile && _replierData == null) {
      return const SizedBox(height: 30, child: Center(child: SizedBox(width:12, height:12, child: CircularProgressIndicator(strokeWidth: 1.5))));
    }
    final replyData = widget.replySnapshot.data() as Map<String, dynamic>;
    final String replierUserId = replyData['userId'] ?? '';
    final String replierName = _replierData?['username'] ?? replyData['username'] ?? 'Anonymous';
    final String replyText = replyData['text'] ?? '';
    final Timestamp? timestamp = replyData['timestamp'] as Timestamp?;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      margin: const EdgeInsets.only(top: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (replierUserId.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfilePage(userId: replierUserId)));
              }
            },
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.orange[100],
              backgroundImage: _replierProfileImageBytes != null ? MemoryImage(_replierProfileImageBytes!) : null,
              child: _replierProfileImageBytes == null ? Icon(Icons.person, size: 14, color: Colors.orange[700]) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          if (replierUserId.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfilePage(userId: replierUserId)));
                          }
                        },
                        child: Text(replierName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text("· ${_timeAgo(timestamp)}", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 3),
                Text(replyText, style: const TextStyle(fontSize: 13.5, height: 1.3)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    InkWell(
                      onTap: _toggleReplyLike,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0, top: 1.0, bottom: 1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isReplyLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 15, color: _isReplyLiked ? Colors.pinkAccent : Colors.grey[600]),
                            const SizedBox(width: 3),
                            Text(_replyLikeCount.toString(), style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

