import 'package:flutter/material.dart';
import 'profile.dart';

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
  late TextEditingController _searchController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _currentIndex = widget.selectedIndex;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onItemTapped(index);
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return Center(child: Text('Home Page (coming soon)'));
      case 1:
        return Center(child: Text('Saved Page (coming soon)'));
      case 2:
        return Center(child: Text('Post Page (coming soon)'));
      case 3:
        return Center(child: Text('Community Page (coming soon)'));
      case 4:
        return const ProfilePage();
      default:
        return Center(child: Text('Unknown page'));
    }
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
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.orange[50],
        child: _getCurrentPage(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.orange,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black87,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
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
