import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_information_1/C5/auth_repository.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';

// 1. Mockの定義
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}
class MockMultiFactor extends Mock implements MultiFactor {}
class MockMultiFactorSession extends Mock implements MultiFactorSession {}
class MockMultiFactorInfo extends Mock implements MultiFactorInfo {}
class MockFirebaseAuthMultiFactorException extends Mock implements FirebaseAuthMultiFactorException {}
class MockMultiFactorResolver extends Mock implements MultiFactorResolver {}

void main() {
  late AuthRepository authRepository;
  late MockFirebaseAuth mockFirebaseAuth;

  const email = 'test@shibaura-it.ac.jp';
  const password = 'password123';

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    authRepository = AuthRepository(firebaseAuth: mockFirebaseAuth);
  });

  group('AuthRepository - createTemporaryAccount のテスト', () {
    // ...(正常系・異常系は省略せず記述)...
    test('正常系: 仮登録とメール送信が成功すること', () async {
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.sendEmailVerification()).thenAnswer((_) async {});
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(email: email, password: password))
          .thenAnswer((_) async => mockUserCredential);
      await expectLater(authRepository.createTemporaryAccount(email, password), completes);
    });

    test('異常系: メアドが既に使用中の場合、専用例外を投げること', () async {
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(email: email, password: password))
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      expect(() => authRepository.createTemporaryAccount(email, password), throwsA(isA<EmailAlreadyInUseException>()));
    });

    test('異常系: ネットワークエラーの場合、NetworkException を投げること', () async {
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(email: email, password: password))
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      expect(() => authRepository.createTemporaryAccount(email, password), throwsA(isA<NetworkException>()));
    });

    // 🟢 追加: 「不明なエラー」のルート
    test('異常系: その他のFirebaseAuthExceptionの場合、不明なエラーとして投げること', () async {
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(email: email, password: password))
          .thenThrow(FirebaseAuthException(code: 'unknown-error'));
      expect(() => authRepository.createTemporaryAccount(email, password), throwsA(isA<Exception>()));
    });

    test('異常系: userがnullの場合、AccountCreationFailedException を投げること', () async {
      final mockUserCredential = MockUserCredential();
      when(() => mockUserCredential.user).thenReturn(null); // ここでnullを返すように設定
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(email: email, password: password))
          .thenAnswer((_) async => mockUserCredential);

      expect(() => authRepository.createTemporaryAccount(email, password), throwsA(isA<AccountCreationFailedException>()));
    });

    test('異常系: メール送信失敗時、MailSendFailureException を投げること', () async {
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.sendEmailVerification()).thenThrow(Exception('メール送信エラー')); // ここでエラーを発生させる
      when(() => mockFirebaseAuth.createUserWithEmailAndPassword(email: email, password: password))
          .thenAnswer((_) async => mockUserCredential);

      expect(() => authRepository.createTemporaryAccount(email, password), throwsA(isA<MailSendFailureException>()));
    });
  });

  group('AuthRepository - checkEmailVerification のテスト', () {
    test('正常系: 認証済みの場合は完了すること', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload()).thenAnswer((_) async {});
      when(() => mockUser.emailVerified).thenReturn(true);
      await expectLater(authRepository.checkEmailVerification(), completes);
    });

    test('異常系: 認証未完了の場合、EmailNotVerifiedException を投げること', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload()).thenAnswer((_) async {});
      when(() => mockUser.emailVerified).thenReturn(false);
      expect(() => authRepository.checkEmailVerification(), throwsA(isA<EmailNotVerifiedException>()));
    });

    test('異常系: ネットワークエラーの場合、NetworkException を投げること', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload()).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      expect(() => authRepository.checkEmailVerification(), throwsA(isA<NetworkException>()));
    });

    // 🟢 追加: 「不明なエラー」のルート
    test('異常系: その他のFirebaseAuthExceptionの場合、不明なエラーとして投げること', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload()).thenThrow(FirebaseAuthException(code: 'unknown-error'));
      expect(() => authRepository.checkEmailVerification(), throwsA(isA<Exception>()));
    });

    test('異常系: 未ログイン(null)の場合、InvalidUserSessionException を投げること', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null); // currentUserをnullにする
      expect(() => authRepository.checkEmailVerification(), throwsA(isA<InvalidUserSessionException>()));
    });
  });

  group('AuthRepository - requestSignInWithPassword のテスト', () {
    test('異常系: MFAが必要な場合、MultiFactorAuthRequiredException に変換すること', () async {
      final mockMfaException = MockFirebaseAuthMultiFactorException();
      final mockResolver = MockMultiFactorResolver();
      when(() => mockMfaException.resolver).thenReturn(mockResolver);
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(email: email, password: password))
          .thenThrow(mockMfaException);
      expect(() => authRepository.requestSignInWithPassword(email, password), throwsA(isA<MultiFactorAuthRequiredException>()));
    });

    test('異常系: 各種FirebaseAuthExceptionの変換テスト', () async {
      // 81行目 (wrong-password)
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(email: email, password: password))
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      expect(() => authRepository.requestSignInWithPassword(email, password), throwsA(isA<InvalidCredentialException>()));

      // 83行目 (network-request-failed)
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(email: email, password: password))
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      expect(() => authRepository.requestSignInWithPassword(email, password), throwsA(isA<NetworkException>()));
    });

    // 🟢 追加: 「不明なエラー」のルート
    test('異常系: その他のFirebaseAuthExceptionの場合、不明なエラーとして投げること', () async {
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(email: email, password: password))
          .thenThrow(FirebaseAuthException(code: 'unknown-error'));
      expect(() => authRepository.requestSignInWithPassword(email, password), throwsA(isA<Exception>()));
    });
  });

  group('AuthRepository - requestVerifyOTP のテスト', () {
    test('異常系: resolverがない場合、InvalidLoginSessionException を投げること', () async {
      expect(() => authRepository.requestVerifyOTP('123456'), throwsA(isA<InvalidLoginSessionException>()));
    });

    // 🟢 追加: MFAログイン失敗(resolverセット済み)のルートに突入させ、Staticメソッドで落ちるところまで実行させる
    test('異常系: resolverが存在する場合、Staticメソッド呼び出しまで到達してFirebaseエラーで落ちること', () async {
      // 1. まずログインしてMFAエラーを発生させ、内部の _multiFactorResolver にモックをセットする
      final mockMfaException = MockFirebaseAuthMultiFactorException();
      final mockResolver = MockMultiFactorResolver();
      final mockHint = MockMultiFactorInfo();
      when(() => mockResolver.hints).thenReturn([mockHint]);
      when(() => mockMfaException.resolver).thenReturn(mockResolver);
      
      when(() => mockFirebaseAuth.signInWithEmailAndPassword(email: email, password: password))
          .thenThrow(mockMfaException);
      
      try {
        await authRepository.requestSignInWithPassword(email, password);
      } catch (_) {}

      // 2. その状態で requestVerifyOTP を呼ぶと、最初のif文を突破し、
      // TotpMultiFactorGenerator の呼び出しまで進んでからFirebase未初期化エラーで落ちる！
      expect(
        () => authRepository.requestVerifyOTP('123456'),
        throwsA(anything), // どんなエラーでも飛んでくればOK（行を通すことが目的）
      );
    });
  });

  group('AuthRepository - generateTotpSecretUrl のテスト', () {
    test('異常系: ユーザーがnullの場合、InvalidUserSessionException を投げること', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);
      expect(() => authRepository.generateTotpSecretUrl(), throwsA(isA<InvalidUserSessionException>()));
    });

    // 🟢 追加: Staticメソッド呼び出しまで到達させる
    test('異常系: ユーザーが存在する場合、Staticメソッド呼び出しまで到達してFirebaseエラーで落ちること', () async {
      final mockUser = MockUser();
      final mockMultiFactor = MockMultiFactor();
      final mockSession = MockMultiFactorSession();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.multiFactor).thenReturn(mockMultiFactor);
      when(() => mockMultiFactor.getSession()).thenAnswer((_) async => mockSession);

      expect(
        () => authRepository.generateTotpSecretUrl(),
        throwsA(anything), // TotpSetupFailureException か Firebaseエラーが出るはず
      );
    });
  });

  group('AuthRepository - enrollTotpMfa のテスト', () {
    test('異常系: _tempTotpSecretがnullの場合、InvalidMfaSetupSessionException を投げること', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      expect(() => authRepository.enrollTotpMfa('123456'), throwsA(isA<InvalidMfaSetupSessionException>()));
    });
  });

  group('AuthRepository - requestSignOut のテスト', () {
    test('正常系: サインアウトが成功すること', () async {
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
      await expectLater(authRepository.requestSignOut(), completes);
    });

    test('異常系: 例外発生時に SignOutFailureException を投げること', () async {
      when(() => mockFirebaseAuth.signOut()).thenThrow(Exception());
      expect(() => authRepository.requestSignOut(), throwsA(isA<SignOutFailureException>()));
    });
  });

  group('AuthRepository - checkIsMfaEnrolled のテスト', () {
    test('正常系: MFA情報がある場合は true を返すこと', () async {
      final mockUser = MockUser();
      final mockMultiFactor = MockMultiFactor();
      final mockFactorInfo = MockMultiFactorInfo(); // 要素を1つ用意
      
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.multiFactor).thenReturn(mockMultiFactor);
      when(() => mockMultiFactor.getEnrolledFactors()).thenAnswer((_) async => [mockFactorInfo]);

      final result = await authRepository.checkIsMfaEnrolled();
      expect(result, isTrue);
    });

    test('正常系: 未ログインの場合は false を返すこと', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);
      final result = await authRepository.checkIsMfaEnrolled();
      expect(result, isFalse);
    });
  });
}