import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ⚠️ 実際のプロジェクトのフォルダ構成に合わせてパスを調整してください
import 'package:student_information_1/C1/authentication_controller.dart';
import 'package:student_information_1/C2/account_creation_service.dart';
import 'package:student_information_1/C2/login_service.dart';
import 'package:student_information_1/C2/logout_service.dart';
import 'package:student_information_1/C2/mfa_setup_service.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';

// モッククラスの定義
class MockAccountCreationService extends Mock implements AccountCreationService {}
class MockLoginService extends Mock implements LoginService {}
class MockLogoutService extends Mock implements LogoutService {}
class MockMfaSetupService extends Mock implements MfaSetupService {}

void main() {
  late AuthenticationController controller;
  late MockAccountCreationService mockAccountCreationService;
  late MockLoginService mockLoginService;
  late MockLogoutService mockLogoutService;
  late MockMfaSetupService mockMfaSetupService;

  setUp(() {
    mockAccountCreationService = MockAccountCreationService();
    mockLoginService = MockLoginService();
    mockLogoutService = MockLogoutService();
    mockMfaSetupService = MockMfaSetupService();

    controller = AuthenticationController(
      accountCreationService: mockAccountCreationService,
      loginService: mockLoginService,
      logoutService: mockLogoutService,
      mfaSetupService: mockMfaSetupService,
    );
    
    cSessionUid = null;
  });

  group('submitLogin のテスト', () {
    test('メールアドレスかパスワードが空の場合は Exception をスローすること', () async {
      expect(() => controller.submitLogin('', 'password'), throwsA(isA<Exception>()));
      expect(() => controller.submitLogin('test@example.com', ''), throwsA(isA<Exception>()));
    });

    test('ログイン成功時、戻り値 1 を返し、cSessionUid が設定されること', () async {
      when(() => mockLoginService.processLogin(any(), any())).thenAnswer((_) async {});

      final result = await controller.submitLogin('test@example.com', 'password123');

      expect(result, 1);
      expect(cSessionUid, 'dummy_uid_form_firebase');
      verify(() => mockLoginService.processLogin('test@example.com', 'password123')).called(1);
    });

    test('MFA検証が必要な例外発生時、戻り値 2 を返すこと', () async {
      when(() => mockLoginService.processLogin(any(), any()))
          .thenThrow(MultiFactorAuthRequiredException());

      final result = await controller.submitLogin('test@example.com', 'password123');

      expect(result, 2);
    });

    test('MFA初期設定が必要な例外発生時、戻り値 3 を返すこと', () async {
      when(() => mockLoginService.processLogin(any(), any()))
          .thenThrow(MfaSetupRequiredException());

      final result = await controller.submitLogin('test@example.com', 'password123');

      expect(result, 3);
    });

    test('資格情報が無効な例外発生時、適切なエラーメッセージの Exception を返すこと', () async {
      when(() => mockLoginService.processLogin(any(), any()))
          .thenThrow(InvalidCredentialException());

      expect(
        () => controller.submitLogin('test@example.com', 'wrong_pass'),
        throwsA(predicate((e) => e.toString().contains('メールアドレスまたはパスワードが間違っています'))),
      );
    });
  });

  group('submitOtp のテスト', () {
    test('OTP検証成功時、cSessionUid が設定されること', () async {
      when(() => mockLoginService.verifyOTP(any())).thenAnswer((_) async {});

      await controller.submitOtp('123456');

      expect(cSessionUid, 'dummy_uid_form_firebase');
      verify(() => mockLoginService.verifyOTP('123456')).called(1);
    });

    test('OTPが無効な場合、適切なエラーメッセージの Exception を返すこと', () async {
      when(() => mockLoginService.verifyOTP(any())).thenThrow(InvalidOtpException());

      expect(
        () => controller.submitOtp('000000'),
        throwsA(predicate((e) => e.toString().contains('認証コードが間違っているか、有効期限が切れています'))),
      );
    });
  });

  group('submitRegistration のテスト', () {
    test('入力項目が空の場合は Exception をスローすること', () async {
      expect(() => controller.submitRegistration('', 'pass', 'pass'), throwsA(isA<Exception>()));
      expect(() => controller.submitRegistration('a@a.com', '', 'pass'), throwsA(isA<Exception>()));
      expect(() => controller.submitRegistration('a@a.com', 'pass', ''), throwsA(isA<Exception>()));
    });

    test('パスワードと確認用パスワードが一致しない場合は Exception をスローすること', () async {
      expect(
        () => controller.submitRegistration('test@shibaura.ac.jp', 'password123', 'different_password'),
        throwsA(predicate((e) => e.toString().contains('パスワードが一致しません'))),
      );
    });

    test('新規登録成功時は例外を投げずに終了すること', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenAnswer((_) async {});

      await expectLater(
        controller.submitRegistration('test@shibaura.ac.jp', 'pass123', 'pass123'),
        completes,
      );
    });

    test('ドメインが無効な場合、適切なエラーの Exception を返すこと', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenThrow(InvalidDomainException());

      expect(
        () => controller.submitRegistration('test@gmail.com', 'pass123', 'pass123'),
        throwsA(predicate((e) => e.toString().contains('このメールアドレスは使用できません'))),
      );
    });

    test('予期せぬ一般エラーが発生した場合、メッセージをそのまま保持して Exception を返すこと', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenThrow(Exception('カスタムネットワークエラー'));

      expect(
        () => controller.submitRegistration('test@shibaura.ac.jp', 'pass123', 'pass123'),
        throwsA(predicate((e) => e.toString().contains('カスタムネットワークエラー'))),
      );
    });
  });

  group('checkEmailVerified のテスト', () {
    test('メール認証完了時、true を返すこと', () async {
      when(() => mockAccountCreationService.finalizeAccountRegistration()).thenAnswer((_) async {});

      final isVerified = await controller.checkEmailVerified();

      expect(isVerified, true);
    });

    test('メールが未認証の場合、false を返すこと', () async {
      when(() => mockAccountCreationService.finalizeAccountRegistration())
          .thenThrow(EmailNotVerifiedException());

      final isVerified = await controller.checkEmailVerified();

      expect(isVerified, false);
    });
  });

  group('MFAセットアップのテスト', () {
    test('startMfaSetup が呼ばれたとき、QRコードの文字列URLを返すこと', () async {
      const dummyQrUrl = 'otpauth://totp/Firebase:test@example.com?secret=ABCDEF';
      when(() => mockMfaSetupService.initiateMfaSetup()).thenAnswer((_) async => dummyQrUrl);

      final result = await controller.startMfaSetup();

      expect(result, dummyQrUrl);
      verify(() => mockMfaSetupService.initiateMfaSetup()).called(1);
    });

    test('startMfaSetup 内でエラーが発生した場合、適切な Exception を返すこと', () async {
      when(() => mockMfaSetupService.initiateMfaSetup()).thenThrow(Exception('MFA初期化に失敗'));

      expect(
        () => controller.startMfaSetup(),
        throwsA(predicate((e) => e.toString().contains('MFAセットアップの開始に失敗しました'))),
      );
    });

    test('completeMfaEnrollment でコードが空または6桁以外なら即座に例外を出すこと', () async {
      expect(() => controller.completeMfaEnrollment(''), throwsA(isA<Exception>()));
      expect(() => controller.completeMfaEnrollment('12345'), throwsA(isA<Exception>()));
    });

    test('completeMfaEnrollment で正しいコードの場合、サービスを呼び出すこと', () async {
      when(() => mockMfaSetupService.finalizeMfaEnrollment(any())).thenAnswer((_) async {});

      await expectLater(controller.completeMfaEnrollment('123456'), completes);
      verify(() => mockMfaSetupService.finalizeMfaEnrollment('123456')).called(1);
    });

    test('completeMfaEnrollment 内でエラーが発生した場合、適切な Exception を返すこと', () async {
      when(() => mockMfaSetupService.finalizeMfaEnrollment(any())).thenThrow(Exception('不正なコード'));

      expect(
        () => controller.completeMfaEnrollment('111111'),
        throwsA(predicate((e) => e.toString().contains('2段階認証の設定に失敗しました'))),
      );
    });
  });

  group('submitLogout のテスト', () {
    test('ログアウト成功時、cSessionUid が null になること', () async {
      cSessionUid = 'before_logout_uid';
      when(() => mockLogoutService.processLogout()).thenAnswer((_) async {});

      await controller.submitLogout();

      expect(cSessionUid, null);
      verify(() => mockLogoutService.processLogout()).called(1);
    });

    test('ログアウト内でエラーが発生した場合、適切な Exception を返すこと', () async {
      when(() => mockLogoutService.processLogout()).thenThrow(Exception('通信エラー'));

      expect(
        () => controller.submitLogout(),
        throwsA(predicate((e) => e.toString().contains('ログアウトに失敗しました'))),
      );
    });
  });
}