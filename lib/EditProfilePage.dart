import 'dart:io';
import 'dart:convert'; // For base64Encode/Decode
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // No longer needed for profile image

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> currentUserData;

  const EditProfilePage({Key? key, required this.currentUserData}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _genderController;

  XFile? _pickedImageFileX;
  Uint8List? _pickedImageBytes;
  String? _existingProfileImageBase64;

  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _usernameController = TextEditingController(text: widget.currentUserData['username'] ?? _currentUser?.displayName ?? '');
    _bioController = TextEditingController(text: widget.currentUserData['bio'] ?? '');
    _genderController = TextEditingController(text: widget.currentUserData['gender'] ?? '');
    // Assuming the image is stored as 'profileImageBase64' in Firestore
    _existingProfileImageBase64 = widget.currentUserData['profileImageBase64'];
  }

  Future<void> _pickImage() async {
    try {
      final XFile? selectedImage = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
      if (selectedImage != null) {
        final bytes = await File(selectedImage.path).readAsBytes();
        setState(() {
          _pickedImageFileX = selectedImage; // Keep XFile if needed for re-encoding, or just path
          _pickedImageBytes = bytes; // For immediate display
          _existingProfileImageBase64 = null; // Clear existing image if new one is picked
        });
      }
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error picking image: ${e.toString()}")));
      }
    }
  }

  // No longer uploading to Firebase Storage for profile image
  // Future<String?> _uploadProfileImage(String userId, File image) async { ... }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_currentUser == null) {
      if(mounted){
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("User not logged in.")));
      }
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> updatedData = {
      'username': _usernameController.text.trim(),
      'bio': _bioController.text.trim(),
      'gender': _genderController.text.trim(),
    };

    String? finalImageBase64;

    if (_pickedImageFileX != null) { // A new image was picked
      final File imageFile = File(_pickedImageFileX!.path);
      final bytes = await imageFile.readAsBytes();
      finalImageBase64 = base64Encode(bytes);
      updatedData['profileImageBase64'] = finalImageBase64;
    } else if (_existingProfileImageBase64 != null) { // No new image, keep existing one
      updatedData['profileImageBase64'] = _existingProfileImageBase64;
      finalImageBase64 = _existingProfileImageBase64; // For Firebase Auth update
    } else { // No new image and no existing image (or it was cleared)
      updatedData['profileImageBase64'] = ''; // Store empty string or null
      finalImageBase64 = '';
    }

    // Firestore document size check for the image (approximate)
    if (finalImageBase64 != null && finalImageBase64.length > 700000) { // ~0.7MB for Base64 string
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image is too large. Please select a smaller image.')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }


    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updatedData);

      // Update Firebase Auth display name if username changed
      if (_currentUser!.displayName != updatedData['username']) {
        await _currentUser!.updateDisplayName(updatedData['username']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully!")));
        Navigator.pop(context, true); // Pop with true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update profile: ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  ImageProvider? _getDisplayImage() {
    if (_pickedImageBytes != null) {
      return MemoryImage(_pickedImageBytes!);
    }
    if (_existingProfileImageBase64 != null && _existingProfileImageBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_existingProfileImageBase64!));
      } catch (e) {
        print("Error decoding existing Base64 image: $e");
        return null; // Fallback to placeholder
      }
    }
    return null; // No image
  }


  @override
  Widget build(BuildContext context) {
    ImageProvider? displayImage = _getDisplayImage();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.orange,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.orange[100],
                      backgroundImage: displayImage,
                      child: displayImage == null
                          ? Icon(Icons.person, size: 60, color: Colors.orange[700])
                          : null,
                    ),
                    MaterialButton(
                      onPressed: _pickImage,
                      color: Colors.orange,
                      textColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                      shape: const CircleBorder(),
                      child: const Icon(Icons.camera_alt_outlined, size: 20),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a username';
                    }
                    if (value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell us about yourself...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  maxLines: 3,
                  maxLength: 150,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _genderController,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    hintText: 'e.g., Male, Female',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wc_outlined),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_alt_outlined, color: Colors.white),
                  label: Text(_isLoading ? 'Saving...' : 'Save Changes', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
