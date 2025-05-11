import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add this import for DateFormat
import 'PostDetailPage.dart'; // Your post detail page

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: query + 'z')
          .orderBy('title')
          .limit(20)
          .get();

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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search posts by title...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _searchPosts('');
              _searchFocusNode.requestFocus();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
        ),
        onChanged: (value) {
          _searchPosts(value);
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Search for posts by title',
          style: TextStyle(fontSize: 18, color: Colors.grey),
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        final postData = post.data() as Map<String, dynamic>;
        final timestamp = postData['timestamp'] as Timestamp?;
        final formattedDate = timestamp != null
            ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
            : '';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
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
            title: Text(
              postData['title'] ?? 'No title',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  postData['content'] != null
                      ? postData['content'].length > 50
                      ? '${postData['content'].substring(0, 50)}...'
                      : postData['content']
                      : '',
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      postData['username'] ?? 'Anonymous',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const Spacer(),
                    Text(
                      formattedDate,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Posts'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }
}