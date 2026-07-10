import 'package:flutter_test/flutter_test.dart';
import 'package:student_information_1/C2/auth/account_creation_service.dart';
import 'package:student_information_1/C5/auth/auth_repository.dart';
import 'package:student_information_1/shared/auth_exceptions.dart';

// =======================================================
// 1. 手動で作成するC5層の偽物（Fakeクラス）
// =======================================================
class FakeAuthRepository implements AuthRepository {
  // テストを操るためのエラースイッチ
  Exception? errorToThrow;

  @override
  Future<void> createTemporaryAccount(String email, String password) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> checkEmailVerification() async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  // 💡 追加: メールの再送用のモック
  @override
  Future<void> requestResendVerificationEmail() async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  // 💡 追加: アカウント削除用のモック
  @override
  Future<void> deleteCurrentUser() async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  // 今回のテストでは呼ばれないメソッド群
  @override
  Future<void> requestSignInWithPassword(String email, String password) => throw UnimplementedError();
  @override
  Future<bool> checkIsMfaEnrolled() => throw UnimplementedError();
  @override
  Future<void> requestVerifyOTP(String otpCode) => throw UnimplementedError();
  @override
  Future<String> generateTotpSecretUrl() => throw UnimplementedError();
  @override
  Future<void> enrollTotpMfa(String otpCode) => throw UnimplementedError();
  @override
  Future<void> requestSignOut() => throw UnimplementedError();
}

void main() {
  late AccountCreationService accountService;
  late FakeAuthRepository fakeAuthRepository;

  setUp(() {
    fakeAuthRepository = FakeAuthRepository();
    accountService = AccountCreationService(authRepository: fakeAuthRepository);
  });

  // =======================================================
  // validateDomain (バリデーション) のテスト
  // =======================================================
  group('AccountCreationService - バリデーション単体テスト', () {
    test('validateDomain: 正しい大学のドメインなら true を返すこと', () {
      expect(accountService.validateDomain('student@shibaura-it.ac.jp'), isTrue);
      expect(accountService.validateDomain('student@sic.shibaura-it.ac.jp'), isTrue);
    });

    test('validateDomain: 異なるドメインや無効な形式なら false を返すこと', () {
      expect(accountService.validateDomain('test@gmail.com'), isFalse);
      expect(accountService.validateDomain('test@yahoo.co.jp'), isFalse);
      expect(accountService.validateDomain(''), isFalse); 
      expect(accountService.validateDomain('shibaura-it.ac.jp'), isFalse); 
    });
  });

  // =======================================================
  // requestAccountCreation のテスト
  // =======================================================
  group('AccountCreationService - requestAccountCreation のテスト', () {
    const validEmail = 'test@shibaura-it.ac.jp';
    const invalidEmail = 'test@gmail.com';
    const password = 'password123';

    test('正常系: ドメインが正しく、エラーがなければ完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      await expectLater(
        accountService.requestAccountCreation(validEmail, password, password),
        completes,
      );
    });

    test('異常系: 無効なドメインの場合、InvalidDomainException を投げること', () async {
      expect(
        () => accountService.requestAccountCreation(invalidEmail, password, password),
        throwsA(isA<InvalidDomainException>()),
      );
    });

    test('異常系: AccountCreationFailedException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = AccountCreationFailedException();
      expect(
        () => accountService.requestAccountCreation(validEmail, password, password),
        throwsA(isA<AccountCreationFailedException>()),
      );
    });

    test('異常系: MailSendFailureException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = MailSendFailureException();
      expect(
        () => accountService.requestAccountCreation(validEmail, password, password),
        throwsA(isA<MailSendFailureException>()),
      );
    });

    test('異常系: EmailAlreadyInUseException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = EmailAlreadyInUseException();
      expect(
        () => accountService.requestAccountCreation(validEmail, password, password),
        throwsA(isA<EmailAlreadyInUseException>()),
      );
    });

    test('異常系: NetworkException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = NetworkException();
      expect(
        () => accountService.requestAccountCreation(validEmail, password, password),
        throwsA(isA<NetworkException>()),
      );
    });

    test('異常系: 予期せぬエラーの場合、Exception でラップされること', () async {
      fakeAuthRepository.errorToThrow = Exception('予期せぬエラー');
      expect(
        () => accountService.requestAccountCreation(validEmail, password, password),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('予期せぬエラー'))),
      );
    });
  });

  // =======================================================
  // finalizeAccountRegistration のテスト
  // =======================================================
  group('AccountCreationService - finalizeAccountRegistration のテスト', () {
    test('正常系: エラーなく完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      await expectLater(accountService.finalizeAccountRegistration(), completes);
    });

    test('異常系: InvalidUserSessionException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = InvalidUserSessionException();
      expect(
        () => accountService.finalizeAccountRegistration(),
        throwsA(isA<InvalidUserSessionException>()),
      );
    });

    test('異常系: EmailNotVerifiedException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = EmailNotVerifiedException();
      expect(
        () => accountService.finalizeAccountRegistration(),
        throwsA(isA<EmailNotVerifiedException>()),
      );
    });

    test('異常系: NetworkException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = NetworkException();
      expect(
        () => accountService.finalizeAccountRegistration(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('異常系: 予期せぬエラーの場合、Exception でラップされること', () async {
      fakeAuthRepository.errorToThrow = Exception('予期せぬエラー');
      expect(
        () => accountService.finalizeAccountRegistration(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('予期せぬエラー'))),
      );
    });
  });

  // =======================================================
  // resendVerificationEmail のテスト
  // =======================================================
  group('AccountCreationService - resendVerificationEmail のテスト', () {
    test('正常系: エラーなく完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      await expectLater(accountService.resendVerificationEmail(), completes);
    });

    test('異常系: InvalidUserSessionException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = InvalidUserSessionException();
      expect(
        () => accountService.resendVerificationEmail(),
        throwsA(isA<InvalidUserSessionException>()),
      );
    });

    test('異常系: TooManyRequestsException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = TooManyRequestsException();
      expect(
        () => accountService.resendVerificationEmail(),
        throwsA(isA<TooManyRequestsException>()),
      );
    });

    test('異常系: NetworkException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = NetworkException();
      expect(
        () => accountService.resendVerificationEmail(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('異常系: 予期せぬエラーの場合、Exception でラップされること', () async {
      fakeAuthRepository.errorToThrow = Exception('Unknown Error');
      expect(
        () => accountService.resendVerificationEmail(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unknown Error'))),
      );
    });
  });

  // =======================================================
  // cancelAndCleanupAccount のテスト
  // =======================================================
  group('AccountCreationService - cancelAndCleanupAccount のテスト', () {
    test('正常系: エラーなく完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      await expectLater(accountService.cancelAndCleanupAccount(), completes);
    });

    test('異常系: NetworkException がそのまま伝播すること', () async {
      fakeAuthRepository.errorToThrow = NetworkException();
      expect(
        () => accountService.cancelAndCleanupAccount(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('異常系: 予期せぬエラーの場合、Exception でラップされること', () async {
      fakeAuthRepository.errorToThrow = Exception('Unknown Cleanup Error');
      expect(
        () => accountService.cancelAndCleanupAccount(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unknown Cleanup Error'))),
      );
    });
  });
}