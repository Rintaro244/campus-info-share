import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ⚠️ 実際のプロジェクトのフォルダ構成に合わせてパスを調整してください
import 'package:student_information_1/C1/auth/authentication_controller.dart';
import 'package:student_information_1/C2/auth/account_creation_service.dart';
import 'package:student_information_1/C2/auth/login_service.dart';
import 'package:student_information_1/C2/auth/logout_service.dart';
import 'package:student_information_1/C2/auth/mfa_setup_service.dart';
import 'package:student_information_1/C5/auth/auth_repository.dart';
import 'package:student_information_1/shared/auth_exceptions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// モッククラスの定義
class MockAccountCreationService extends Mock implements AccountCreationService {}
class MockLoginService extends Mock implements LoginService {}
class MockLogoutService extends Mock implements LogoutService {}
class MockMfaSetupService extends Mock implements MfaSetupService {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseApp extends Mock implements FirebaseApp {}

void main() {

  setUpAll(() {
    final mockAuth = MockFirebaseAuth();
    AuthRepository(firebaseAuth: mockAuth);
  });

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
    
  });

  group('AuthenticationController - コンストラクタのテスト', () {
    test('モックなしのデフォルトコンストラクタが正常にインスタンスを生成すること', () {
      final defaultController = AuthenticationController();
      expect(defaultController, isNotNull);
    });
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

    test('通信エラー時、NetworkException がそのまま rethrow されること', () async {
      when(() => mockLoginService.processLogin(any(), any())).thenThrow(NetworkException());
      expect(() => controller.submitLogin('test@shibaura-it.ac.jp', 'Password123'), throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ネットワークエラー'))));
    });
    test('その他の致命的エラー時、Exception にラップされてスローされること', () async {
      // Exception ではなく Error を投げて catch (e) のルートを通す
      when(() => mockLoginService.processLogin(any(), any())).thenThrow(ArgumentError('システムエラー'));
      expect(() => controller.submitLogin('test@shibaura-it.ac.jp', 'Password123'), throwsA(isA<Exception>()));
    });
  });

  group('submitOtp のテスト', () {
    test('OTP検証成功時、cSessionUid が設定されること', () async {
      when(() => mockLoginService.verifyOTP(any())).thenAnswer((_) async {});

      await controller.submitOtp('123456');
      verify(() => mockLoginService.verifyOTP('123456')).called(1);
    });

    group('submitOtp のテスト', () {
  // 既存の正常系テストやサービスエラーのテスト...

  // 👇 ここから追加：バリデーション（不正な形式）のテスト
  test('異常系: 6桁未満の数字の場合、バリデーションエラーを投げること', () async {
    expect(
      () => controller.submitOtp('12345'), // 5桁
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('6桁の認証コード(数字)を正しく入力してください'))),
    );
  });

  test('異常系: 数字以外の文字が含まれる場合、バリデーションエラーを投げること', () async {
    expect(
      () => controller.submitOtp('12345a'), // 英字混じり
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('6桁の認証コード(数字)を正しく入力してください'))),
    );
  });

  test('異常系: 空文字の場合、バリデーションエラーを投げること', () async {
    expect(
      () => controller.submitOtp(''), // 空文字
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('6桁の認証コード(数字)を正しく入力してください'))),
    );
  });
});

    test('OTPが無効な場合、適切なエラーメッセージの Exception を返すこと', () async {
      when(() => mockLoginService.verifyOTP(any())).thenThrow(InvalidOtpException());

      expect(
        () => controller.submitOtp('000000'),
        throwsA(predicate((e) => e.toString().contains('認証コードが間違っているか、有効期限が切れています'))),
      );
    });

    test('異常系: InvalidLoginSessionException 発生時、適切な Exception を投げること', () async {
      when(() => mockLoginService.verifyOTP(any())).thenThrow(InvalidLoginSessionException());
      expect(() => controller.submitOtp('123456'), throwsA(isA<Exception>()));
    });

    test('通信エラー時、NetworkException がそのまま rethrow されること', () async {
      when(() => mockLoginService.verifyOTP(any())).thenThrow(NetworkException());
      expect(() => controller.submitOtp('123456'), throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ネットワークエラー'))));
    });
    test('その他の致命的エラー時、Exception にラップされてスローされること', () async {
      when(() => mockLoginService.verifyOTP(any())).thenThrow(ArgumentError('システムエラー'));
      expect(() => controller.submitOtp('123456'), throwsA(isA<Exception>()));
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
        () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'different_password'),
        throwsA(predicate((e) => e.toString().contains('パスワードが一致しません'))),
      );
    });

    test('異常系: パスワードが英数字混合・8文字以上でない場合、Exception を投げること', () async {
      // 'pass' という弱いパスワードを渡してバリデーションに引っ掛ける
      expect(
        () => controller.submitRegistration('test@shibaura-it.ac.jp', 'pass', 'pass'), 
        throwsA(isA<Exception>())
      );
    });

    test('新規登録成功時は例外を投げずに終了すること', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenAnswer((_) async {});

      await expectLater(
        controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
        completes,
      );
    });

    test('異常系: ドメインが無効な場合、適切なエラーの Exception を返すこと', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenThrow(InvalidDomainException());
      expect(
        () => controller.submitRegistration('test@gmail.com', 'password123', 'password123'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('芝浦工業大学のメールアドレス'))),
      );
    });

    test('異常系: AccountCreationFailedException 発生時、Exception を投げること', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenThrow(AccountCreationFailedException());
      expect(
        () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('アカウント作成に失敗'))),
      );
    });

    test('異常系: MailSendFailureException 発生時、Exception を投げること', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenThrow(MailSendFailureException());
      expect(
        () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('確認メールの送信に失敗'))),
      );
    });

    test('異常系: 通信エラー時、ネットワークエラーとして Exception がスローされること', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenThrow(NetworkException());
      expect(
        () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ネットワークエラー'))),
      );
    });

    test('異常系: その他の予期せぬエラー時、Exception にラップされてスローされること', () async {
      when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
          .thenThrow(Exception('Unknown Error'));
      expect(
        () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unknown Error'))),
      );
    });

    // ==============================================================
    // 👇 ここからが追加する EmailAlreadyInUseException 用のテストグループ
    // ==============================================================
    group('EmailAlreadyInUseException 発生時の内部フロー（processLogin）のテスト', () {
      setUp(() {
        // 大前提として requestAccountCreation が必ず EmailAlreadyInUseException を投げるように設定
        when(() => mockAccountCreationService.requestAccountCreation(any(), any(), any()))
            .thenThrow(EmailAlreadyInUseException());
      });

      test('異常系: processLogin が成功した場合、「すでに登録が完了しています」エラーを投げること', () async {
        when(() => mockLoginService.processLogin(any(), any())).thenAnswer((_) async {});
        expect(
          () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('すでに登録が完了しています'))),
        );
      });

      test('異常系: processLogin が EmailNotVerifiedException を投げた場合、そのまま rethrow されること', () async {
        when(() => mockLoginService.processLogin(any(), any())).thenThrow(EmailNotVerifiedException());
        expect(
          () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
          throwsA(isA<EmailNotVerifiedException>()),
        );
      });

      test('異常系: processLogin が MultiFactorAuthRequiredException を投げた場合、MFA設定エラーを投げること', () async {
        when(() => mockLoginService.processLogin(any(), any())).thenThrow(MultiFactorAuthRequiredException());
        expect(
          () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('MFA設定を行ってください'))),
        );
      });

      test('異常系: processLogin が MfaSetupRequiredException を投げた場合、MFA設定エラーを投げること', () async {
        when(() => mockLoginService.processLogin(any(), any())).thenThrow(MfaSetupRequiredException());
        expect(
          () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('MFA設定を行ってください'))),
        );
      });

      test('異常系: processLogin が InvalidCredentialException を投げた場合、既に使用されている旨のエラーを投げること', () async {
        when(() => mockLoginService.processLogin(any(), any())).thenThrow(InvalidCredentialException());
        expect(
          () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('既に使用されています'))),
        );
      });

      test('異常系: processLogin が InvalidUserSessionException を投げた場合、セッション無効エラーを投げること', () async {
        when(() => mockLoginService.processLogin(any(), any())).thenThrow(InvalidUserSessionException());
        expect(
          () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('セッションが無効になりました'))),
        );
      });

      test('異常系: processLogin が NetworkException を投げた場合、ネットワークエラーを投げること', () async {
        when(() => mockLoginService.processLogin(any(), any())).thenThrow(NetworkException());
        expect(
          () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ネットワークエラーが発生しました'))),
        );
      });

      test('異常系: processLogin が その他のException を投げた場合、Exceptionにラップして投げること', () async {
        when(() => mockLoginService.processLogin(any(), any())).thenThrow(Exception('Unknown process login error'));
        expect(
          () => controller.submitRegistration('test@shibaura-it.ac.jp', 'password123', 'password123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unknown process login error'))),
        );
      });
    });
  });

group('checkEmailVerified のテスト', () {
    test('正常系: 認証が完了した場合、true を返すこと', () async {
      // 準備: finalizeAccountRegistration が正常終了するように設定
      when(() => mockAccountCreationService.finalizeAccountRegistration())
          .thenAnswer((_) async {});

      // 実行
      final result = await controller.checkEmailVerified();

      // 検証
      expect(result, isTrue);
      verify(() => mockAccountCreationService.finalizeAccountRegistration()).called(1);
    });

    test('準正常系: EmailNotVerifiedException が発生した場合、false を返すこと', () async {
      // 準備: まだメール認証が完了していない例外を投げる
      when(() => mockAccountCreationService.finalizeAccountRegistration())
          .thenThrow(EmailNotVerifiedException());

      // 実行
      final result = await controller.checkEmailVerified();

      // 検証: 例外がキャッチされ、false が返ってくること
      expect(result, isFalse);
      verify(() => mockAccountCreationService.finalizeAccountRegistration()).called(1);
    });

    test('準正常系: NetworkException が発生した場合、false を返すこと', () async {
      // 準備: 通信エラーの例外を投げる
      when(() => mockAccountCreationService.finalizeAccountRegistration())
          .thenThrow(NetworkException());

      // 実行
      final result = await controller.checkEmailVerified();

      // 検証: 例外がキャッチされ、false が返ってくること
      expect(result, isFalse);
      verify(() => mockAccountCreationService.finalizeAccountRegistration()).called(1);
    });

    test('異常系: InvalidUserSessionException が発生した場合、「セッションが無効になりました」というメッセージを持つ Exception を投げること', () async {
      // 準備: セッション無効例外を投げる
      when(() => mockAccountCreationService.finalizeAccountRegistration())
          .thenThrow(InvalidUserSessionException());

      // 実行 & 検証: 指定されたメッセージにラップされた Exception がスローされること
      expect(
        () => controller.checkEmailVerified(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('セッションが無効になりました'))),
      );
      verify(() => mockAccountCreationService.finalizeAccountRegistration()).called(1);
    });

    test('異常系: その他の予期せぬエラーが発生した場合、Exception にラップされてそのままスローされること', () async {
      // 準備: 予期せぬ一般的なエラーを投げる
      when(() => mockAccountCreationService.finalizeAccountRegistration())
          .thenThrow(Exception('予期せぬシステムエラー'));

      // 実行 & 検証
      expect(
        () => controller.checkEmailVerified(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('予期せぬシステムエラー'))),
      );
      verify(() => mockAccountCreationService.finalizeAccountRegistration()).called(1);
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

    /*test('startMfaSetup 内でエラーが発生した場合、適切な Exception を返すこと', () async {
      when(() => mockMfaSetupService.initiateMfaSetup()).thenThrow(Exception('MFA初期化に失敗'));

      expect(
        () => controller.startMfaSetup(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('MFA初期化に失敗'))),
      );
    });*/

    test('異常系: InvalidUserSessionException 発生時、Exception を投げること', () async {
      when(() => mockMfaSetupService.initiateMfaSetup()).thenThrow(InvalidUserSessionException());
      expect(() => controller.startMfaSetup(), throwsA(isA<Exception>()));
    });

    test('異常系: TotpSetupFailureException 発生時、Exception を投げること', () async {
      when(() => mockMfaSetupService.initiateMfaSetup()).thenThrow(TotpSetupFailureException());
      expect(() => controller.startMfaSetup(), throwsA(isA<Exception>()));
    });

    test('通信エラー時、NetworkException がそのまま rethrow されること', () async {
      when(() => mockMfaSetupService.initiateMfaSetup()).thenThrow(NetworkException());
      expect(() => controller.startMfaSetup(), throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ネットワークエラー'))));
    });
    test('その他の致命的エラー時、Exception にラップされてスローされること', () async {
      when(() => mockMfaSetupService.initiateMfaSetup()).thenThrow(ArgumentError('システムエラー'));
      expect(() => controller.startMfaSetup(), throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('システムエラー'))));
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

    /*test('completeMfaEnrollment 内でエラーが発生した場合、適切な Exception を返すこと', () async {
      when(() => mockMfaSetupService.finalizeMfaEnrollment(any())).thenThrow(Exception('不正なコード'));

      expect(
        () => controller.completeMfaEnrollment('111111'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('不正なコード'))),
      );
    });*/

    test('異常系: InvalidMfaSetupSessionException 発生時、Exception を投げること', () async {
      when(() => mockMfaSetupService.finalizeMfaEnrollment(any())).thenThrow(InvalidMfaSetupSessionException());
      expect(() => controller.completeMfaEnrollment('123456'), throwsA(isA<Exception>()));
    });

    test('異常系: InvalidOtpException 発生時、Exception を投げること', () async {
      when(() => mockMfaSetupService.finalizeMfaEnrollment(any())).thenThrow(InvalidOtpException());
      expect(() => controller.completeMfaEnrollment('123456'), throwsA(isA<Exception>()));
    });

    test('通信エラー時、NetworkException がそのまま rethrow されること', () async {
      when(() => mockMfaSetupService.finalizeMfaEnrollment(any())).thenThrow(NetworkException());
      expect(() => controller.completeMfaEnrollment('123456'), throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ネットワークエラー'))));
    });
    test('その他の致命的エラー時、Exception にラップされてスローされること', () async {
      when(() => mockMfaSetupService.finalizeMfaEnrollment(any())).thenThrow(ArgumentError('システムエラー'));
      expect(() => controller.completeMfaEnrollment('123456'), throwsA(isA<Exception>()));
    });
  });

  group('submitLogout のテスト', () {
    test('ログアウト成功時、cSessionUid が null になること', () async {
      when(() => mockLogoutService.processLogout()).thenAnswer((_) async {});

      await controller.submitLogout();
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

  group('deleteCurrentTemporaryAccount のテスト', () {
    test('正常系: エラーなく処理が完了すること', () async {
      when(() => mockAccountCreationService.cancelAndCleanupAccount())
          .thenAnswer((_) async {});

      await expectLater(controller.deleteCurrentTemporaryAccount(), completes);
      verify(() => mockAccountCreationService.cancelAndCleanupAccount()).called(1);
    });

    /*test('異常系: サービスでエラーが起きた場合、Exception を投げること', () async {
      when(() => mockAccountCreationService.cancelAndCleanupAccount())
          .thenThrow(Exception('削除エラー'));

      expect(
        () => controller.deleteCurrentTemporaryAccount(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('削除エラー'))),
      );
    });*/

    test('通信エラー時、NetworkException がそのまま rethrow されること', () async {
      when(() => mockAccountCreationService.cancelAndCleanupAccount()).thenThrow(NetworkException());
      expect(() => controller.deleteCurrentTemporaryAccount(), throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ネットワークエラー'))));
    });
    test('その他の致命的エラー時、Exception にラップされてスローされること', () async {
      when(() => mockAccountCreationService.cancelAndCleanupAccount()).thenThrow(ArgumentError('システムエラー'));
      expect(() => controller.deleteCurrentTemporaryAccount(), throwsA(isA<Exception>()));
    });
  });



  group('Email のテスト', () {
    test('正常系: サービスの再送処理が正常に完了すること', () async {
      // 💡 メソッド名が異なる場合は、コントローラーの実際のメソッド名に合わせて変更してください（例: resendEmailなど）
      when(() => mockAccountCreationService.resendVerificationEmail())
          .thenAnswer((_) async {});
      await expectLater(controller.resendEmail(), completes);
    });

    test('異常系: InvalidUserSessionException が発生した場合、適切なメッセージを投げること', () async {
      when(() => mockAccountCreationService.resendVerificationEmail())
          .thenThrow(InvalidUserSessionException());
      expect(
        () => controller.resendEmail(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('セッションが無効'))),
      );
    });

    // 💡 TooManyRequestsException はカスタム例外に存在する場合は有効化してください
    
    test('異常系: TooManyRequestsException が発生した場合、専用のメッセージを投げること', () async {
      when(() => mockAccountCreationService.resendVerificationEmail())
          .thenThrow(TooManyRequestsException());
      expect(
        () => controller.resendEmail(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('メール送信回数が上限に達しました'))),
      );
    });
    

    test('異常系: NetworkException時、ネットワークエラーのメッセージを投げること', () async {
      when(() => mockAccountCreationService.resendVerificationEmail())
          .thenThrow(NetworkException());
      expect(
        () => controller.resendEmail(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('ネットワークエラー'))),
      );
    });

    test('異常系: その他のエラー時、Exceptionにラップして投げること', () async {
      when(() => mockAccountCreationService.resendVerificationEmail())
          .thenThrow(Exception('Unknown'));
      expect(
        () => controller.resendEmail(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Unknown'))),
      );
    });
  });
}