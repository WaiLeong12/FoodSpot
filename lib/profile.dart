import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:state_management/ForgotPassword.dart';
import 'editProfile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    return FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  }

  Future<void> _refreshData() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No profile data found'));
          }

          final data = snapshot.data!.data()!;
          final joinedDate = (data['joinedDate'] as Timestamp).toDate();
          final formattedDate = DateFormat('MMM d, y').format(joinedDate);

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Profile header section
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: data['profileImageUrl']?.isNotEmpty == true
                                    ? NetworkImage(data['profileImageUrl'])
                                    : const AssetImage('assets/default_profile.png') as ImageProvider,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                data['username'] ?? 'No username',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Text(
                                data['email'] ?? '',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  data['bio'] ?? 'No bio yet',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Stats row
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return SizedBox(
                                    width: constraints.maxWidth * 0.9,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Flexible(child: _buildStatItem('Posts', data['myPostsCount'] ?? 0)),
                                        Flexible(child: _buildStatItem('Followers', data['followers'] ?? 0)),
                                        Flexible(child: _buildStatItem('Following', data['following'] ?? 0)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Joined $formattedDate',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () => _editProfile(context),
                                  child: const Text('Edit Profile'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _changePassword(context),
                                  child: const Text('Change Password'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // User posts section
                        Flexible(
                          child: _buildUserPosts(data['uid']),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildUserPosts(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No posts yet'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            final postDate = (post['timestamp'] as Timestamp).toDate();
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.post_add),
                title: Text(post['title'] ?? 'No title'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post['content'] ?? ''),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, y • h:mm a').format(postDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editProfile(BuildContext context) {
    // Implement edit profile navigation
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => const EditProfilePage(),
    ));
  }

  void _changePassword(BuildContext context) {
    // Implement change password flow
    showDialog(
      context: context,
      builder: (context) => const ResetPasswordPage(),
    );
  }
}