import 'package:flutter_test/flutter_test.dart';
import 'package:student_information_1/C2/account_creation_service.dart';
import 'package:student_information_1/C5/auth_repository.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';

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

// =======================================================
// 2. テスト本体
// =======================================================
void main() {
  late AccountCreationService accountService;
  late FakeAuthRepository fakeAuthRepository;

  // ※注意：AccountCreationServiceの実装に合わせて、
  // validateDomain() を通過する「正しい大学のメアド」に変更してください。
  // ここでは仮に '@shibaura-it.ac.jp' としています。
  const validEmail = 'test@shibaura-it.ac.jp';
  const invalidEmail = 'test@gmail.com'; 
  const validPassword = 'password123';

  setUp(() {
    fakeAuthRepository = FakeAuthRepository();
    accountService = AccountCreationService(authRepository: fakeAuthRepository);
  });

  group('AccountCreationService - requestAccountCreation のテスト', () {
    
    test('正常系: バリデーションOKで例外なく完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      await expectLater(
        accountService.requestAccountCreation(validEmail, validPassword, validPassword), 
        completes
      );
    });

    test('異常系: ドメインが違う場合、InvalidDomainException で弾かれること', () async {
      expect(
        () => accountService.requestAccountCreation(invalidEmail, validPassword, validPassword),
        throwsA(isA<InvalidDomainException>()),
      );
    });

    test('異常系: パスワードが一致しない場合、PasswordMismatchException で弾かれること', () async {
      expect(
        () => accountService.requestAccountCreation(validEmail, validPassword, 'wrong_password'),
        throwsA(isA<PasswordMismatchException>()),
      );
    });

    test('異常系: C5から EmailAlreadyInUseException が投げられた場合、そのまま投げること', () async {
      fakeAuthRepository.errorToThrow = EmailAlreadyInUseException();
      expect(
        () => accountService.requestAccountCreation(validEmail, validPassword, validPassword),
        throwsA(isA<EmailAlreadyInUseException>()),
      );
    });

    test('異常系: C5から AccountCreationFailedException が投げられた場合、そのまま投げること', () async {
      fakeAuthRepository.errorToThrow = AccountCreationFailedException();
      expect(
        () => accountService.requestAccountCreation(validEmail, validPassword, validPassword),
        throwsA(isA<AccountCreationFailedException>()),
      );
    });

    test('異常系: C5から MailSendFailureException が投げられた場合、そのまま投げること', () async {
      fakeAuthRepository.errorToThrow = MailSendFailureException();
      expect(
        () => accountService.requestAccountCreation(validEmail, validPassword, validPassword),
        throwsA(isA<MailSendFailureException>()),
      );
    });

    test('異常系: 通信エラー時、NetworkException をそのまま投げること', () async {
      fakeAuthRepository.errorToThrow = NetworkException();
      expect(
        () => accountService.requestAccountCreation(validEmail, validPassword, validPassword),
        throwsA(isA<NetworkException>()),
      );
    });

    test('異常系: 予期せぬエラー時、「不明なエラー」として Exception を投げること', () async {
      fakeAuthRepository.errorToThrow = Exception('謎のサーバーダウン');
      expect(
        () => accountService.requestAccountCreation(validEmail, validPassword, validPassword),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('不明なエラー'))),
      );
    });
  });

  group('AccountCreationService - finalizeAccountRegistration のテスト', () {
    
    test('正常系: 認証済みの確認が例外なく完了すること', () async {
      fakeAuthRepository.errorToThrow = null;
      await expectLater(accountService.finalizeAccountRegistration(), completes);
    });

    test('異常系: まだ認証されていない場合、EmailNotVerifiedException を投げること', () async {
      fakeAuthRepository.errorToThrow = EmailNotVerifiedException();
      expect(
        () => accountService.finalizeAccountRegistration(),
        throwsA(isA<EmailNotVerifiedException>()),
      );
    });

    test('異常系: セッション切れの場合、InvalidUserSessionException を投げること', () async {
      fakeAuthRepository.errorToThrow = InvalidUserSessionException();
      expect(
        () => accountService.finalizeAccountRegistration(),
        throwsA(isA<InvalidUserSessionException>()),
      );
    });

    test('異常系: 通信エラー時、NetworkException を投げること', () async {
      fakeAuthRepository.errorToThrow = NetworkException();
      expect(
        () => accountService.finalizeAccountRegistration(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('異常系: 予期せぬエラー時、「不明なエラー」として Exception を投げること', () async {
      fakeAuthRepository.errorToThrow = Exception('謎のサーバーダウン');
      expect(
        () => accountService.finalizeAccountRegistration(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('不明なエラー'))),
      );
    });
  });

  // =======================================================
  // 3. バリデーション機能（単体）のテスト
  // =======================================================
  group('AccountCreationService - バリデーション単体テスト', () {
    
    test('validateDomain: 正しい大学のドメインなら true を返すこと', () {
      // 正常系のテスト
      final result = accountService.validateDomain('student@shibaura-it.ac.jp');
      expect(result, isTrue);
    });

    test('validateDomain: 異なるドメインや無効な形式なら false を返すこと', () {
      // 異常系のテスト（同値分割・境界値分析）
      expect(accountService.validateDomain('test@gmail.com'), isFalse);
      expect(accountService.validateDomain('test@yahoo.co.jp'), isFalse);
      expect(accountService.validateDomain(''), isFalse); // 空文字
      expect(accountService.validateDomain('shibaura-it.ac.jp'), isFalse); // @がない
    });

    test('validatePassword: パスワードと確認用が一致していれば true を返すこと', () {
      final result = accountService.validatePassword('Password123', 'Password123');
      expect(result, isTrue);
    });

    test('validatePassword: 一致しない、または不備がある場合は false を返すこと', () {
      expect(accountService.validatePassword('Password123', 'Password456'), isFalse); // 不一致
      // もし実装側で「空文字は弾く」などの処理を入れていれば、以下のテストも有効になります
      // expect(accountService.validatePassword('', ''), isFalse); 
    });
  });
}