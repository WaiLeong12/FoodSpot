import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'PostDetailPage.dart';

class FoodMain extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const FoodMain({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<FoodMain> createState() => _FoodMainState();
}

class _FoodMainState extends State<FoodMain> {
  late final TextEditingController _searchController;
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _searchType = 'title';
  final Map<String, Uint8List> profileImageCache = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPosts(String query) async {
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
      Query queryRef;

      if (_searchType == 'restaurant') {
        queryRef = FirebaseFirestore.instance
            .collection('posts')
            .where('restaurant', isGreaterThanOrEqualTo: query)
            .where('restaurant', isLessThan: query + 'z')
            .orderBy('restaurant')
            .limit(20);
      } else {
        queryRef = FirebaseFirestore.instance
            .collection('posts')
            .where('title', isGreaterThanOrEqualTo: query)
            .where('title', isLessThan: query + 'z')
            .orderBy('title')
            .limit(20);
      }

      final querySnapshot = await queryRef.get();

      setState(() {
        _searchResults = querySnapshot.docs;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: ${e.toString()}')),
      );
    }
  }

  Future<Uint8List?> _getProfileImage(String userId) async {
    if (profileImageCache.containsKey(userId)) {
      return profileImageCache[userId];
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = userDoc.data();
      if (data != null && data['profileImageBase64'] != null) {
        final imageBytes = base64Decode(data['profileImageBase64']);
        profileImageCache[userId] = imageBytes;
        return imageBytes;
      }
    } catch (e) {
      print("Error fetching profile image: $e");
    }

    return null;
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Welcome to FoodSpot',
          style: TextStyle(
            fontSize: 24,
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No posts found',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        final postData = post.data() as Map<String, dynamic>;
        final timestamp = postData['timestamp'] as Timestamp?;
        final formattedDate = timestamp != null
            ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
            : '';
        final images = postData['imagesBase64'] as List<dynamic>?;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailPage(
                    postData: postData,
                    postId: post.id,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images != null && images.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(images[0]),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 150,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                    ),
                  const SizedBox(height: 12),
                  if (postData['restaurant'] != null)
                    Text(
                      postData['restaurant'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  Text(
                    postData['title'] ?? 'No title',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    postData['content'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (postData['rating'] != null)
                        Row(
                          children: List.generate(
                            5,
                                (starIndex) => Icon(
                              starIndex < (postData['rating']?.toInt() ?? 0)
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FutureBuilder<Uint8List?>(
                        future: _getProfileImage(postData['userId'] ?? ''),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          } else if (snapshot.hasData && snapshot.data != null) {
                            return CircleAvatar(
                              radius: 12,
                              backgroundImage: MemoryImage(snapshot.data!),
                            );
                          } else {
                            return const CircleAvatar(
                              radius: 12,
                              backgroundImage: AssetImage('assets/default_profile.png'),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        postData['username'] ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
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
        centerTitle: true,
      ),
      body: Container(
        color: Colors.orange[50],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Search by Title'),
                        selected: _searchType == 'title',
                        selectedColor: Colors.orange[300],
                        onSelected: (selected) {
                          setState(() {
                            _searchType = 'title';
                          });
                          if (_searchController.text.isNotEmpty) {
                            _searchPosts(_searchController.text);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Search by Restaurant'),
                        selected: _searchType == 'restaurant',
                        selectedColor: Colors.orange[300],
                        onSelected: (selected) {
                          setState(() {
                            _searchType = 'restaurant';
                          });
                          if (_searchController.text.isNotEmpty) {
                            _searchPosts(_searchController.text);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _searchType == 'restaurant'
                          ? 'Search by restaurant name...'
                          : 'Search by post title...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.black87),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.clear, color: Colors.black87),
                        onPressed: () {
                          _searchController.clear();
                          _searchPosts('');
                        },
                      ),
                    ),
                    onChanged: _searchPosts,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildSearchResults()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.orange,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black87,
        currentIndex: widget.selectedIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/save');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/post');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/community');
          } else if (index == 4) {
            Navigator.pushNamed(context, '/me');
          } else {
            widget.onItemTapped(index);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          _buildBottomNavItem('assets/images/homelogo.png', 'Home'),
          _buildBottomNavItem('assets/images/foodspotlogo.png', 'Saved'),
          _buildBottomNavItem('assets/images/add.png', 'Post'),
          _buildBottomNavItem('assets/images/community.png', 'Community'),
          _buildBottomNavItem('assets/images/me.png', 'Me'),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavItem(String assetPath, String label) {
    return BottomNavigationBarItem(
      icon: Image.asset(
        assetPath,
        width: 40,
        height: 40,
        color: Colors.black87,
      ),
      activeIcon: Image.asset(
        assetPath,
        width: 40,
        height: 40,
        color: Colors.black,
      ),
      label: label,
    );
  }
}