import 'package:student_information_1/shared/auth_exceptions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {

  //クラス間での状態を保持するためシングルトンにする

  static AuthRepository? _instance;

  //外部から初めてよばれたらインスタンスを返す
  //2回目以降は同じ_instanceを返す
  factory AuthRepository({FirebaseAuth? firebaseAuth}) {
    if (_instance == null) {
      _instance = AuthRepository._internal(firebaseAuth ?? FirebaseAuth.instance);
    } else if (firebaseAuth != null) {
      //テスト用モックが渡されたら上書き
      _instance!._firebaseAuth = firebaseAuth;
    }
    return _instance!;
  }
  //コンストラクタ
  AuthRepository._internal(this._firebaseAuth);

  FirebaseAuth _firebaseAuth;

  MultiFactorResolver? _multiFactorResolver;
  TotpSecret? _tempTotpSecret;

  //emailとpasswordからアカウントを仮登録する
  Future<void> createTemporaryAccount(String email, String password) async {
    try {
      //仮登録処理 createUserWithEmailAndPasswordからUserCredentialオブジェクトが返される
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      //UserCredentialオブジェクトに含まれるuserオブジェクトを別の変数に格納
      final user = userCredential.user;
      if(user == null){
        throw AccountCreationFailedException();//アカウント作成失敗
      }
      
      try {
        //確認メール送信処理
        await user.sendEmailVerification();
      } catch (e) {
        throw MailSendFailureException();//メール送信失敗
      }

    } on FirebaseAuthException catch(e){
      //FirebaseAuthExceptionの例外コードに応じてエラーを投げる
      if (e.code == 'email-already-in-use'){
        throw EmailAlreadyInUseException();//メールアドレス重複
      } else if (e.code == 'network-request-failed') {
        throw NetworkException();//ネットワークエラー
      }
      throw  Exception('不明なエラー: ${e.code}');
    }
  }

  //確認メールを再送信する
  Future<void> requestResendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      
      // セッション（ユーザー状態）が切れている場合は例外を投げる
      if (user == null) {
        throw InvalidUserSessionException();
      }

      // FirebaseのAPIを使ってメールを再送信
      await user.sendEmailVerification();
      debugPrint('Firebase: 確認メールを再送信しました');
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        // 短時間に送りすぎた場合のFirebase側の制限
        throw TooManyRequestsException();
      } else if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      throw Exception('不明なエラー: ${e.code}');
    }
  }

  //メール認証が完了しているかどうかを判定する
  Future<void> checkEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw InvalidUserSessionException();//セッション無効
      }

      //Firebaseのユーザ状態を再読み込み
      await user.reload();

      if (!user.emailVerified) {
        throw EmailNotVerifiedException();//メール認証未完了
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw NetworkException();//ネットワークエラー
      }
      throw Exception('不明なエラー: ${e.code}');
    }
  }

  //ログイン時入力情報が正しいか判定
  Future<void> requestSignInWithPassword(String email, String password) async {
    try {
      //セッションリセット
      _multiFactorResolver = null;

      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthMultiFactorException catch (e) {
      //OTP検証が必要な場合
      _multiFactorResolver = e.resolver;
      throw MultiFactorAuthRequiredException();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
        throw InvalidCredentialException();//入力間違い
      } else if (e.code == 'network-request-failed') {
        throw NetworkException();//ネットワークエラー
      }
      throw Exception('不明なエラー: ${e.code}');
    }
  }

  //OTP検証
  Future<void> requestVerifyOTP(String otpCode) async {
    if (_multiFactorResolver == null) { 
      throw InvalidLoginSessionException();//セッション無効
    }

    try {
      final hint = _multiFactorResolver!.hints.first;

      final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(hint.uid, otpCode);

      await _multiFactorResolver!.resolveSignIn(assertion);

      _multiFactorResolver = null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw InvalidOtpException();//OTP間違い
      } else if (e.code == 'network-request-failed') {
        throw NetworkException();//ネットワークエラー
      }
      throw Exception('不明なエラー: ${e.code}');
    }
  }

  //初回ログイン時のMFA初期設定用URL発行処理
  Future<String> generateTotpSecretUrl() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw InvalidUserSessionException();//セッション無効
    }

    try {
      final session = await user.multiFactor.getSession();

      _tempTotpSecret = await TotpMultiFactorGenerator.generateSecret(session);

      //URL生成
      final qrCodeUrl = _tempTotpSecret!.generateQrCodeUrl(accountName: user.email ?? 'ユーザ', issuer: 'CampusInfoShare',);
      return qrCodeUrl;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      throw TotpSetupFailureException();
    } catch (e) {
      throw TotpSetupFailureException();
    }
  }

  //MFA登録完了処理
  Future<void> enrollTotpMfa(String otpCode) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || _tempTotpSecret == null) {
      throw InvalidMfaSetupSessionException();//セッション無効
    }

    try {
      final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
        _tempTotpSecret!, 
        otpCode
      );

      await user.multiFactor.enroll(assertion, displayName: 'Authenticator App');

      _tempTotpSecret = null;
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw InvalidOtpException();//OTP間違い
      } else if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      throw Exception('不明なエラー: ${e.code}');
    }
  }

  //サインアウト処理
  Future<void> requestSignOut() async {
    try{
      await _firebaseAuth.signOut();
    } catch (e) {
      throw SignOutFailureException();
    }
  }

  //MFA初期設定が必要かチェック
  Future<bool> checkIsMfaEnrolled() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;

    //MFA情報を取得
    final enrolledFactors = await user.multiFactor.getEnrolledFactors();
    //空でなければtrue返す
    return enrolledFactors.isNotEmpty;
  }

  //アカウント削除処理
  Future<void> deleteCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      throw Exception('アカウント削除に失敗しました: ${e.code}');
    } catch (e) {
      throw Exception('アカウント削除に失敗しました');
    }
  }
}