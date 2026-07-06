import 'package:flutter/material.dart';
import 'circle_post_screen.dart';
import '../C3/circle_manager.dart';
import '../C3/circle_model.dart';
import '../C1/circle_detail_screen.dart';

class CircleSearchScreen extends StatefulWidget {
  const CircleSearchScreen({Key? key}) : super(key: key);

  @override
  State<CircleSearchScreen> createState() => _CircleSearchScreenState();
}

class _CircleSearchScreenState extends State<CircleSearchScreen> {
  String _searchKeyword = '';
  String _selectedCampus = 'すべて'; 
  String _selectedCategory = 'すべて'; 

  List<CircleModel> _circles = [];
  bool _isLoading = false; 

  @override
  void initState() {
    super.initState();
    _fetchCircles(); 
  }

  Future<void> _fetchCircles() async {
    setState(() { _isLoading = true; }); 

    final results = await CircleManager().searchCircles(
      keyword: _searchKeyword,
      campus: _selectedCampus,
      category: _selectedCategory,
    );

    setState(() {
      _circles = results;
      _isLoading = false; 
    });
  }

  // 💡 追加：キャンパスごとに色付きのバッジ（タグ）を作る専用関数
  Widget _buildCampusBadge(String campus) {
    Color bgColor;
    Color textColor;

    // キャンパス名によって色を振り分け
    switch (campus) {
      case '豊洲':
        bgColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        break;
      case '大宮':
        bgColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        break;
      case '両方':
      default:
        bgColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12), // 丸みを帯びた可愛いデザイン
      ),
      child: Text(
        campus,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('サークル・部活動検索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(labelText: 'キーワード検索', prefixIcon: Icon(Icons.search)),
              onChanged: (val) {
                _searchKeyword = val;
                _fetchCircles(); 
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DropdownButton<String>(
                value: _selectedCampus,
                items: ['すべて', '豊洲', '大宮', '両方'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (newValue) {
                  setState(() { _selectedCampus = newValue!; });
                  _fetchCircles(); 
                },
              ),
              DropdownButton<String>(
                value: _selectedCategory,
                items: ['すべて', '運動系', '文化系', 'その他'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (newValue) {
                  setState(() { _selectedCategory = newValue!; });
                  _fetchCircles(); 
                },
              ),
            ],
          ),
          
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : _circles.isEmpty
                    ? const Center(child: Text('該当するデータが見つかりませんでした。'))
                    : ListView.builder(
                        itemCount: _circles.length,
                        itemBuilder: (context, index) {
                          final circle = _circles[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              // 💡 修正：タイトルとバッジを横並び（Row）にして配置
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      circle.name, 
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCampusBadge(circle.campus), // ここでバッジを表示！
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(circle.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CircleDetailScreen(circle: circle),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CirclePostScreen()),
          );
          if (result == true) {
            _fetchCircles(); 
          }
        },
        backgroundColor: Colors.blue[600],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('サークルを登録', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}