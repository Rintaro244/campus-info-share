import 'package:flutter/material.dart';
import 'past_exam_screen.dart';
import 'features/spot/spot_search_screen.dart';  // import追加

class MainScreen extends StatefulWidget{
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>{
  int currentIndex = 0; //current tab number

  final List<Widget> _screens = [
    const Center(child: Text('講義情報', style: TextStyle(fontSize: 20))),
    const PastExamListScreen(),
    const SpotSearchScreen(),  // SPOT検索画面を表示
    const Center(child: Text('部活・サークル', style: TextStyle(fontSize: 20))),
    const Center(child: Text('教材取引', style: TextStyle(fontSize: 20))),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[600],
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '講義情報'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: '過去問'),
          BottomNavigationBarItem(icon: Icon(Icons.place), label: 'SPOT'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'サークル'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: '教材取引'),
        ],
      ),
    );
    
  }

}
