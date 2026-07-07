import 'package:flutter_test/flutter_test.dart';
import 'package:student_information_1/C2/mfa_setup_service.dart';
import 'package:student_information_1/C5/auth_repository.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';

// =======================================================
// 1. 手動で作成するC5層の偽物（Fakeクラス）
// =======================================================
class FakeAuthRepository implements AuthRepository {
  // テストを操るためのスイッチ
  Exception? errorToThrow;
  String qrCodeUrlToReturn = 'dummy_qr_code_url'; // 正常時に返すURL

  @override
  Future<String> generateTotpSecretUrl() async {
    if (errorToThrow != null) throw errorToThrow!;
    return qrCodeUrlToReturn;
  }

  @override
  Future<void> enrollTotpMfa(String otpCode) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  // 今回のテストでは呼ばれないメソッド群
  @override
  Future<void> createTemporaryAccount(String email, String password) => throw UnimplementedError();
  @override
  Future<void> checkEmailVerification() => throw UnimplementedError();
  @override
  Future<void> requestSignInWithPassword(String email, String password) => throw UnimplementedError();
  @override
  Future<bool> checkIsMfaEnrolled() => throw UnimplementedError();
  @override
  Future<void> requestVerifyOTP(String otpCode) => throw UnimplementedError();
  @override
  Future<void> requestSignOut() => throw UnimplementedError();
}

// =======================================================
// 2. テスト本体
// =======================================================
void main() {
  late MfaSetupService mfaSetupService;
  late FakeAuthRepository fakeAuthRepository;

  setUp(() {
    fakeAuthRepository = FakeAuthRepository();
    mfaSetupService = MfaSetupService(authRepository: fakeAuthRepository);
  });

  // ---------------------------------------------------------
  // initiateMfaSetup() のテスト
  // ---------------------------------------------------------
  group('MfaSetupService - initiateMfaSetup のテスト', () {
    test('正常系: エラーなく QRコードURL を返すこと', () async {
      fakeAuthRepository.errorToThrow = null;
      final result = await mfaSetupService.initiateMfaSetup();
      expect(result, 'dummy_qr_code_url');
    });

    test('異常系: セッション切れの場合、InvalidUserSessionException を投げること', () async {
      fakeAuthRepository.errorToThrow = InvalidUserSessionException();
      expect(
        () => mfaSetupService.initiateMfaSetup(),
        throwsA(isA<InvalidUserSessionException>()),
      );
    });

    test('異常系: MFA設定生成失敗時、TotpSetupFailureException を投げること', () async {
      fakeAuthRepository.errorToThrow = TotpSetupFailureException();
      expect(
        () => mfaSetupService.initiateMfaSetup(),
        throwsA(isA<TotpSetupFailureException>()),
      );
    });

    test('異常系: 予期せぬエラー時、「不明なエラー」として Exception を投げること', () async {
      fakeAuthRepository.errorToThrow = Exception('謎のサーバーダウン');
      expect(
        () => mfaSetupService.initiateMfaSetup(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('不明なエラー'))),
      );
    });
  });

  // ---------------------------------------------------------
  // finalizeMfaEnrollment() のテスト
  // ---------------------------------------------------------
  group('MfaSetupService - finalizeMfaEnrollment のテスト', () {
    test('正常系: 有効なOTP（6桁の数字）なら、例外なく登録完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      await expectLater(mfaSetupService.finalizeMfaEnrollment('123456'), completes);
    });

    test('異常系: 入力チェックで弾かれた場合（5桁以下など）、通信前に InvalidOtpException を投げること', () async {
      expect(
        () => mfaSetupService.finalizeMfaEnrollment('12345'), // 5桁
        throwsA(isA<InvalidOtpException>()),
      );
    });

    test('異常系: セッションが無効な場合、InvalidMfaSetupSessionException を投げること', () async {
      fakeAuthRepository.errorToThrow = InvalidMfaSetupSessionException();
      expect(
        () => mfaSetupService.finalizeMfaEnrollment('123456'),
        throwsA(isA<InvalidMfaSetupSessionException>()),
      );
    });

    test('異常系: C5からOTP不一致で弾かれた場合、InvalidOtpException を投げること', () async {
      fakeAuthRepository.errorToThrow = InvalidOtpException();
      expect(
        () => mfaSetupService.finalizeMfaEnrollment('123456'),
        throwsA(isA<InvalidOtpException>()),
      );
    });

    test('異常系: 予期せぬエラー時、「不明なエラー」として Exception を投げること', () async {
      fakeAuthRepository.errorToThrow = Exception('謎のサーバーダウン');
      expect(
        () => mfaSetupService.finalizeMfaEnrollment('123456'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('不明なエラー'))),
      );
    });
  });

  // ---------------------------------------------------------
  // validateOtpInput() のテスト（単体バリデーションテスト）
  // ---------------------------------------------------------
  group('MfaSetupService - validateOtpInput (バリデーション単体) のテスト', () {
    test('正常系: 6桁の数字なら true を返すこと', () {
      expect(mfaSetupService.validateOtpInput('000000'), isTrue);
      expect(mfaSetupService.validateOtpInput('999999'), isTrue);
      expect(mfaSetupService.validateOtpInput('123456'), isTrue);
    });

    test('異常系: 6桁の数字以外なら false を返すこと', () {
      expect(mfaSetupService.validateOtpInput(''), isFalse); // 空文字
      expect(mfaSetupService.validateOtpInput('12345'), isFalse); // 5桁
      expect(mfaSetupService.validateOtpInput('1234567'), isFalse); // 7桁
      expect(mfaSetupService.validateOtpInput('123a56'), isFalse); // 英字混じり
      expect(mfaSetupService.validateOtpInput(' 12345'), isFalse); // スペース混じり
    });
  });

  // =======================================================
  // 3. コンストラクタ（初期化）のテスト
  // =======================================================
  /*group('MfaSetupService - コンストラクタのテスト', () {
    test('authRepository を渡さない場合、デフォルトの AuthRepository が生成されること', () {
      // 引数なしでインスタンス化することで、 `?? AuthRepository()` のルートを通す
      final service = MfaSetupService();
      expect(service, isNotNull);
    });
  });*/
}