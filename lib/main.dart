import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  static const TextStyle optionStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.bold
  );

  static const List<Widget> _widgetOptions = <Widget>[
    Text('Index 0: Home', style: optionStyle),
    Text('Index 1: Saved', style: optionStyle),
    Text('Index 2: Post', style: optionStyle),
    Text('Index 3: Community', style: optionStyle),
    Text('Index 4: Me', style: optionStyle),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Row(
            children: <Widget>[
              Image.asset(
                'assets/images/foodspotlogo.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 10),
              const Text('FoodSpot'),
            ],
          ),
        ),

        body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.orange,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black87, // Darker gray for unselected items
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,

          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Image.asset('assets/images/homelogo.png', width: 40, height: 40),
              label: 'Home',
              backgroundColor: Colors.orange,
            ),

            BottomNavigationBarItem(
              icon: Image.asset('assets/images/foodspotlogo.png', width: 40, height: 40),
              label: 'FoodSpot',
              backgroundColor: Colors.orange,
            ),

            BottomNavigationBarItem(
              icon: Image.asset('assets/images/add.png', width: 40, height: 40),
              label: 'Post',
              backgroundColor: Colors.orange,
            ),

            BottomNavigationBarItem(
              icon: Image.asset('assets/images/community.png', width: 40, height: 40),
              label: 'Community',
              backgroundColor: Colors.orange,
            ),

            BottomNavigationBarItem(
              icon: Image.asset('assets/images/me.png', width: 40, height: 40),
              label: 'Me',
              backgroundColor: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}


