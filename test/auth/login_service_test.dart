import 'package:flutter_test/flutter_test.dart';
import 'package:student_information_1/C2/auth/login_service.dart';
import 'package:student_information_1/C5/auth/auth_repository.dart';
import 'package:student_information_1/shared/auth_exceptions.dart';

// =======================================================
// 1. 手動で作成するC5層の偽物（Fakeクラス）
// =======================================================
class FakeAuthRepository implements AuthRepository {
  Exception? errorToThrow;
  bool mfaEnrolled = true;

  @override
  Future<void> requestSignInWithPassword(String email, String password) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<bool> checkIsMfaEnrolled() async {
    return mfaEnrolled;
  }

  @override
  Future<void> requestVerifyOTP(String otpCode) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  // 今回呼ばれない機能
  @override
  Future<void> createTemporaryAccount(String email, String password) => throw UnimplementedError();
  @override
  Future<void> checkEmailVerification() => throw UnimplementedError();
  @override
  Future<String> generateTotpSecretUrl() => throw UnimplementedError();
  @override
  Future<void> enrollTotpMfa(String otpCode) => throw UnimplementedError();
  @override
  Future<void> requestSignOut() => throw UnimplementedError();
  @override
  Future<void> deleteCurrentUser() => throw UnimplementedError();
}

// =======================================================
// 2. テスト本体
// =======================================================
void main() {
  late LoginService loginService;
  late FakeAuthRepository fakeAuthRepository;

  setUp(() {
    fakeAuthRepository = FakeAuthRepository();
    loginService = LoginService(authRepository: fakeAuthRepository);
  });

  group('LoginService - processLogin のテスト', () {
    test('正常系: パスワード検証OK、かつMFA登録済みの場合は例外なく完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      fakeAuthRepository.mfaEnrolled = true;
      await expectLater(loginService.processLogin('test@test.com', 'pass123'), completes);
    });

    /*test('異常系: C1のバリデーションで弾かれること', () async {
      expect(
        () => loginService.processLogin('', ''),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('メールアドレスとパスワードを入力してください'))),
      );
    });*/

    test('異常系: MFA未登録の場合、MfaSetupRequiredException を投げること', () async {
      fakeAuthRepository.errorToThrow = null;
      fakeAuthRepository.mfaEnrolled = false;
      expect(
        () => loginService.processLogin('test@test.com', 'pass123'),
        throwsA(isA<MfaSetupRequiredException>()),
      );
    });

    test('異常系: パスワード間違い時、InvalidCredentialException を投げること', () async {
      fakeAuthRepository.errorToThrow = InvalidCredentialException();
      expect(
        () => loginService.processLogin('test@test.com', 'wrong'),
        throwsA(isA<InvalidCredentialException>()),
      );
    });

    test('異常系: 通信エラー時、NetworkException を投げること', () async {
      fakeAuthRepository.errorToThrow = NetworkException();
      expect(
        () => loginService.processLogin('test@test.com', 'pass123'),
        throwsA(isA<NetworkException>()),
      );
    });

    // processLogin の異常系テスト（グループの最後）を以下に差し替え
    test('異常系: 予期せぬエラー時、Exception がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = Exception('ログインテストエラー');
      expect(
        () => loginService.processLogin('test@test.com', 'pass123'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ログインテストエラー'))),
      );
    });
  });

  group('LoginService - verifyOTP のテスト', () {
    test('正常系: OTP検証成功時、例外なく完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      await expectLater(loginService.verifyOTP('123456'), completes);
    });

    test('異常系: セッション無効時、InvalidLoginSessionException を投げること', () async {
      fakeAuthRepository.errorToThrow = InvalidLoginSessionException();
      expect(
        () => loginService.verifyOTP('123456'),
        throwsA(isA<InvalidLoginSessionException>()),
      );
    });

    test('異常系: OTP間違い時、InvalidOtpException を投げること', () async {
      fakeAuthRepository.errorToThrow = InvalidOtpException();
      expect(
        () => loginService.verifyOTP('wrong_code'),
        throwsA(isA<InvalidOtpException>()),
      );
    });

    test('異常系: 通信エラー時、NetworkException を投げること', () async {
      fakeAuthRepository.errorToThrow = NetworkException();
      expect(
        () => loginService.verifyOTP('123456'),
        throwsA(isA<NetworkException>()),
      );
    });

    // verifyOTP の異常系テスト（グループの最後）を以下に差し替え
    test('異常系: 予期せぬエラー時、Exception がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = Exception('OTPテストエラー');
      expect(
        () => loginService.verifyOTP('123456'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('OTPテストエラー'))),
      );
    });
  });
}