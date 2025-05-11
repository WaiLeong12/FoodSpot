import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'PostDetailPage.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _deletePost(String postId, List<dynamic>? imageBase64List) async {
    // Confirmation dialog
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    if (_currentUser == null) return;

    try {
      // 1. Delete post document from Firestore
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

      // 2. Decrement myPostsCount in user's profile
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
        'myPostsCount': FieldValue.increment(-1),
      });

      // 3. TODO: Delete images from Firebase Storage if you switch from Base64
      // If you were storing image URLs from Firebase Storage, you'd iterate through
      // the list of URLs and delete each file from Storage.
      // Since you are using Base64, there are no separate files in Storage to delete for the post images.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully.')),
        );
      }
    } catch (e) {
      print("Error deleting post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildRatingStarsList(double rating, {double size = 16.0}) {
    if (rating == 0) return const Text("Not Rated", style: TextStyle(fontSize: 11, color: Colors.grey));
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      stars.add(Icon(i <= rating ? Icons.star : Icons.star_border, color: Colors.amber, size: size));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Date unknown';
    return DateFormat('MMM d, yyyy').format(timestamp.toDate());
  }


  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Posts'), backgroundColor: Colors.orange),
        body: const Center(child: Text('Please log in to see your posts.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: Colors.orange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        color: Colors.orange[50],
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: _currentUser!.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.orange));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error.toString()}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('You haven\'t created any posts yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
              );
            }

            final posts = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final postDocument = posts[index];
                final data = postDocument.data() as Map<String, dynamic>;
                final postId = postDocument.id;

                Uint8List? displayImageBytes;
                List<dynamic>? imagesBase64List = data['imagesBase64'] as List<dynamic>?;
                if (imagesBase64List != null && imagesBase64List.isNotEmpty) {
                  try {
                    displayImageBytes = base64Decode(imagesBase64List[0].toString());
                  } catch (e) {
                    print("Error decoding first image for MyPostsPage: $e");
                  }
                } else if (data['imageBase64'] != null && data['imageBase64'].toString().isNotEmpty) { // Fallback for single image
                  try {
                    displayImageBytes = base64Decode(data['imageBase64'].toString());
                  } catch (e) {
                    print("Error decoding single imageBase64 for MyPostsPage: $e");
                  }
                }


                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailPage(postData: data, postId: postId),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (displayImageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                displayImageBytes,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 40),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? 'No Title',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _timeAgo(data['timestamp'] as Timestamp?),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.favorite, color: Colors.pink[300], size: 16),
                                    const SizedBox(width: 4),
                                    Text((data['likes'] as List?)?.length.toString() ?? '0', style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 10),
                                    Icon(Icons.chat_bubble, color: Colors.grey[600], size: 16),
                                    const SizedBox(width: 4),
                                    Text(data['commentsCount']?.toString() ?? '0', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildRatingStarsList(data['rating']?.toDouble() ?? 0.0),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                            onPressed: () => _deletePost(postId, imagesBase64List),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

