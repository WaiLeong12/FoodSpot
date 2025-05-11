import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostPage extends StatefulWidget {
  final VoidCallback onPostCreated;

  const PostPage({Key? key, required this.onPostCreated}) : super(key: key);

  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _restaurantController = TextEditingController(); // New controller
  double _currentRating = 0.0;

  final ImagePicker _picker = ImagePicker();
  List<XFile> _imageFiles = [];
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickImages() async {
    try {
      final List<XFile> selectedImages = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (selectedImages.isNotEmpty) {
        setState(() {
          if (_imageFiles.length + selectedImages.length <= 5) {
            _imageFiles.addAll(selectedImages);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 5 images allowed')),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: ${e.toString()}')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image.')),
      );
      return;
    }

    if (_restaurantController.text.isEmpty) { // Validate restaurant name
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter restaurant name.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post.')),
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDocSnapshot.exists || userDocSnapshot.data() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not found.')),
        );
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final username = userDocSnapshot.data()!['username'] ?? user.email ?? 'Anonymous';

      List<String> imageBase64List = [];
      for (XFile imageFile in _imageFiles) {
        final bytes = await File(imageFile.path).readAsBytes();
        imageBase64List.add(base64Encode(bytes));
      }

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'userEmail': user.email,
        'username': username,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'imagesBase64': imageBase64List,
        'rating': _currentRating,
        'location': _locationController.text.trim(),
        'restaurant': _restaurantController.text.trim(), // Added restaurant name
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'commentsCount': 0,
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'myPostsCount': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        widget.onPostCreated();
        _titleController.clear();
        _contentController.clear();
        _locationController.clear();
        _restaurantController.clear(); // Clear restaurant field
        setState(() {
          _imageFiles = [];
          _currentRating = 0.0;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error submitting post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _restaurantController.dispose(); // Dispose restaurant controller
    super.dispose();
  }

  Widget _buildStar(int starIndex) {
    return IconButton(
      icon: Icon(
        _currentRating >= starIndex ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 30,
      ),
      onPressed: () {
        setState(() {
          _currentRating = starIndex.toDouble();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Picker Section
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (_imageFiles.isEmpty)
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 50,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text("Add Images", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageFiles.length + (_imageFiles.length < 5 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _imageFiles.length) {
                                return GestureDetector(
                                  onTap: _pickImages,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 25.0),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.add, color: Colors.grey[700], size: 40),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 25.0),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_imageFiles[index].path),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: -10,
                                      right: -10,
                                      child: IconButton(
                                        icon: const CircleAvatar(
                                          backgroundColor: Colors.black54,
                                          radius: 12,
                                          child: Icon(Icons.close, color: Colors.white, size: 14),
                                        ),
                                        onPressed: () => _removeImage(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Restaurant Name Field (NEW)
                TextFormField(
                  controller: _restaurantController,
                  decoration: InputDecoration(
                    labelText: 'Restaurant Name',
                    hintText: 'Enter the restaurant name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.restaurant),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter restaurant name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Post Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter a title for your post',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    if (value.trim().length < 3) {
                      return 'Title must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Post Content Field
                TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    hintText: 'Share your dining experience...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                  maxLines: 5,
                  maxLength: 1000,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter content for your post';
                    }
                    if (value.trim().length < 10) {
                      return 'Content must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Rating Section
                Text(
                  'Your Rating:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                ),
                Row(
                  children: List.generate(5, (index) => _buildStar(index + 1)),
                ),
                const SizedBox(height: 16),

                // Location Field
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    hintText: 'E.g., City, District',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isLoading
                      ? Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(2.0),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                      : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Posting...' : 'Post',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}