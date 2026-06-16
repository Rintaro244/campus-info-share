import 'circle_model.dart';

// 💡 C3 M5: サークル管理ビジネスロジッククラス
class CircleManager {
  // シミュレーション用のメモリ内データストア（起動している間だけデータを保持します）
  static final List<CircleModel> _mockDatabase = [
    CircleModel(id: '1', name: '芝浦工大公式鉄道研究会', campus: '豊洲', category: '文化系', description: '模型の展示や合宿を行っています！'),
    CircleModel(id: '2', name: '硬式庭球部（テニス）', campus: '大宮', category: '運動系', description: '初心者から経験者まで大歓迎です！🎾'),
    CircleModel(id: '3', name: 'プログラミングサークルC3', campus: '両方', category: '文化系', description: 'アプリやゲームを楽しく開発しています。'),
  ];

  // 📝 1. サークル情報を登録する関数 (UC08 サークル・部活動情報投稿)
  Future<bool> registerCircle({
    required String name,
    required String campus,
    required String category,
    required String description,
    String? imageUrl,
  }) async {
    try {
      // 💡 内部設計書のエラー処理: バックエンド側でも文字数と必須入力を最終チェック
      if (name.isEmpty || description.isEmpty) {
        throw Exception('必須項目が空です');
      }
      if (name.length > 30 || description.length > 800) {
        throw Exception('文字数制限を超過しています');
      }

      // --- 本番環境ではここに Firebase Firestore への追加処理が入ります ---
      // await FirebaseFirestore.instance.collection('circles').add({...});
      
      // 現段階のシミュレーション処理
      final newCircle = CircleModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // 簡易的なユニークID
        name: name,
        campus: campus,
        category: category,
        description: description,
        imageUrl: imageUrl,
      );
      _mockDatabase.add(newCircle);

      print('【C3ロジック】データベースに新しいサークル「$name」を正常に登録しました。');
      return true; // 成功
    } catch (e) {
      print('【C3ロジック】登録エラー: $e');
      return false; // 失敗
    }
  }

  // 🔍 2. 条件を指定してサークル一覧を取得する関数 (UC09 サークル・部活動情報検索)
  Future<List<CircleModel>> searchCircles({
    required String keyword,
    required String campus,
    required String category,
  }) async {
    // 本番ではここで Firestore の query (where句) を組み立てて get() します
    // final query = FirebaseFirestore.instance.collection('circles').where(...);
    
    // 擬似的なデータベースからの非同期取得（ネットワーク通信を模して少しだけ待つ処理）
    await Future.delayed(const Duration(milliseconds: 300));

    // 内部設計書の絞り込みロジックを再現
    return _mockDatabase.where((circle) {
      final matchKeyword = keyword.isEmpty || 
                           circle.name.contains(keyword) || 
                           circle.description.contains(keyword);
      
      final matchCampus = campus == 'すべて' || 
                          circle.campus == campus || 
                          circle.campus == '両方';

      final matchCategory = category == 'すべて' || 
                            circle.category == category;

      return matchKeyword && matchCampus && matchCategory;
    }).toList();
  }
}