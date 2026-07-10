import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:student_information_1/C2/auth/logout_service.dart';
import 'package:student_information_1/C5/auth/auth_repository.dart';
import 'package:student_information_1/shared/auth_exceptions.dart';

// =======================================================
// 1. mocktail を使って依存する C5層の偽物（Mock）を作成
// =======================================================
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late LogoutService logoutService;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    // 各テストの実行前にMockを初期化
    mockAuthRepository = MockAuthRepository();
    
    // LogoutServiceのコンストラクタでMockを注入できるように実装されている前提です。
    // もしコンストラクタが対応していない場合は、LogoutService(authRepository: mockAuthRepository) 
    // のように引数を受け取れるように Service 側のコードを調整してください。
    logoutService = LogoutService(authRepository: mockAuthRepository);
  });

  group('LogoutService - processLogout のテスト', () {
    
    test('正常系: Repositoryのログアウトが正常に完了した場合、サービスも正常終了すること', () async {
      // AuthRepository の requestSignOut が呼ばれたら、何もしない（正常完了）ように設定
      when(() => mockAuthRepository.requestSignOut()).thenAnswer((_) async {});

      // 例外が発生せずに完了することを検証
      await expectLater(
        logoutService.processLogout(),
        completes,
      );

      // 実際に一度だけメソッドが呼ばれたことを検証
      verify(() => mockAuthRepository.requestSignOut()).called(1);
    });

    test('異常系: Repositoryが例外を投げた場合、そのままサービス側へ伝播（スロー）されること', () async {
      // AuthRepository が例外（SignOutFailureExceptionなど）を投げるように設定
      when(() => mockAuthRepository.requestSignOut()).thenThrow(SignOutFailureException());

      // サービスを実行したときに、同じ例外がスローされるかを検証
      expect(
        () => logoutService.processLogout(),
        throwsA(isA<SignOutFailureException>()),
      );

      // メソッドが呼ばれたことを確認
      verify(() => mockAuthRepository.requestSignOut()).called(1);
    });
    
    
    test('異常系: 予期せぬエラーが発生した場合、元の Exception をそのまま投げること', () async {
      // 準備: AuthRepositoryが、想定していない標準のException（予期せぬエラー）を投げるように設定
      when(() => mockAuthRepository.requestSignOut()).thenThrow(Exception('謎のサーバーダウン'));

      // 実行＆検証: サービス側がそれをキャッチし、そのまま上に投げることを検証
      expect(
        () => logoutService.processLogout(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('謎のサーバーダウン'))),
      );

      // メソッドが呼ばれたことを確認
      verify(() => mockAuthRepository.requestSignOut()).called(1);
    });
  });
}