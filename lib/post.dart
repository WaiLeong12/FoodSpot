import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostPage extends StatefulWidget {
  final VoidCallback onPostCreated; // Callback to potentially refresh home page

  const PostPage({Key? key, required this.onPostCreated}) : super(key: key);

  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>(); // Add form key

  Future<void> _pickImage() async {
    final XFile? selectedImage = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = selectedImage;
    });
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final String fileName = 'posts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(image);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: ${e.toString()}')),
      );
      return null;
    }
  }

  Future<void> _submitPost() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    String? imageUrl;
    if (_imageFile != null) {
      imageUrl = await _uploadImage(File(_imageFile!.path));
    }

    if (imageUrl == null && _imageFile != null) {
      // Image upload failed
      setState(() => _isLoading = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'userEmail': user.email, // Optional: store user email for display
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [], // Initialize likes as an empty list
        'commentsCount': 0, // Initialize comments count
        // Add other fields like rating, location if needed later
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );
      widget.onPostCreated(); // Call the callback
      // Optionally clear fields and navigate away or reset state
      _titleController.clear();
      _contentController.clear();
      setState(() {
        _imageFile = null;
      });
      // Consider navigating back or to the home page
      // Navigator.pop(context); // Example: Navigate back

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create post: ${e.toString()}')),
      );
    } finally {
      if(mounted){
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
        child: Form( // Wrap content in a Form
          key: _formKey,
          child: SingleChildScrollView( // Make content scrollable
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _imageFile == null
                        ? const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey))
                        : ClipRRect( // Clip the image to rounded corners
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(_imageFile!.path), fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) { // Add validator
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Content Field
                TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 5,
                  validator: (value) { // Add validator
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter content';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Post', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}