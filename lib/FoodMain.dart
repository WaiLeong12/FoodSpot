import 'package:flutter/material.dart';

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
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search posts...',
                  filled: true,
                  fillColor: Colors.orange[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  prefixIcon: const Icon(Icons.search, color: Colors.black87),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.black87),
                    onPressed: () => setState(() => _searchController.clear()),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Welcome to FoodSpot',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.orange,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black87,
        currentIndex: widget.selectedIndex,
        onTap: widget.onItemTapped,
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