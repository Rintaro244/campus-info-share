import 'package:flutter/material.dart';
import 'past_exam_screen.dart';
import 'features/spot/spot_search_screen.dart';  // import追加
import 'lecture/lecture_list_screen.dart'; //import追加
import 'past/past_exam_screen.dart';
import 'features/spot/spot_search_screen.dart'; 
import 'C1/circle_search_screen.dart'; 
import 'C1/market_search_screen.dart'; 
import 'C1/profile_screen.dart';  

class MainScreen extends StatefulWidget{
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>{
  int currentIndex = 0; //current tab number
  int refreshKey = 0; //refresh tab number

  final List<Widget> _screens = [
    const LectureListScreen(), //講義検索画面
    const PastExamListScreen(),
    const SpotSearchScreen(),  // SPOT検索画面を表示
    const CircleSearchScreen(),  // サークル投稿画面を表示
    const MarketSearchScreen(),  // 教材取引投稿画面を表示
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'キャンパスアプリ', // アプリ名やタブ名など好きな文字でOK
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1, // 少しだけ影をつけてバーを区切る
        
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.blue, size: 32), // プロフィールっぽいアイコン
              onPressed: () async{
                // アイコンを押したらプロフィール画面へ遷移する処理
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
                setState(() {
                  refreshKey++; // プロフィール画面から戻ってきたときに画面を更新するためのキーをインクリメント
                });
              },
            ),
          ),
        ],
      ),
      //body: _screens[currentIndex],
      body: KeyedSubtree(
        key: ValueKey(refreshKey), // refreshKeyをValueKeyとして使用
        child: _screens[currentIndex],
      ),

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
