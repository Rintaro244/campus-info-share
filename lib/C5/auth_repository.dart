//import 'package:flutter/material.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {

  final FirebaseAuth _firebaseAuth;

  MultiFactorResolver? _multiFactorResolver;
  TotpSecret? _tempTotpSecret;
  
  //テスト用に偽物のFirebaseを作成
  //テスト時にはFirebaseAuth型の引数を渡してそれをインスタンス変数としてセットする．
  //アプリ実行時にはFirebaseAuthのインスタンスを作成
  AuthRepository({FirebaseAuth? firebaseAuth}): _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  //emailとpasswordからアカウントを仮登録する
  Future<void> createTemporaryAccount(String email, String password) async {
    try{
      //仮登録処理 createUserWithEmailAndPasswordからUserCredentialオブジェクトが返される
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      //UserCredentialオブジェクトに含まれるuserオブジェクトを別の変数に格納
      final user = userCredential.user;
      if(user == null){
        throw AccountCreationFailedException();
      }
      
      try{
        //確認メール送信処理
        await user.sendEmailVerification();
      } catch (e) {
        throw MailSendFailureException();
      }

    } on FirebaseAuthException catch(e){
      //FirebaseAuthExceptionの例外コードに応じてエラーを投げる
      if(e.code == 'email-already-in-use'){
        throw EmailAlreadyInUseException();
      }else if(e.code == 'network-request-failed'){
        throw NetworkException();
      }
      throw  Exception('不明なエラー: ${e.code}');
    }
  }

  //メール認証が完了しているかどうかを判定する
  Future<void> checkEmailVerification() async {
    try{
      final user = _firebaseAuth.currentUser;
      if(user == null){
        throw InvalidUserSessionException();
      }

      //Firebaseのユーザ状態を再読み込み
      await user.reload();

      if (!user.emailVerified) {
        throw EmailNotVerifiedException();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw NetworkException();
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
      if (e.code == 'wrong-password' || e.code == 'user-not-found' || e.code == 'invalid-credential') {
        throw InvalidCredentialException();
      } else if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      throw Exception('不明なエラー: ${e.code}');
    }
  }

  //OTP検証
  Future<void> requestVerifyOTP(String otpCode) async {
    if (_multiFactorResolver == null) { 
      throw InvalidLoginSessionException();
    }

    try {
      final hint = _multiFactorResolver!.hints.first;

      final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(hint.uid, otpCode);

      await _multiFactorResolver!.resolveSignIn(assertion);

      _multiFactorResolver = null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw InvalidOtpException();
      } else if (e.code == 'network-request-failed') {
        throw NetworkException();
      }
      throw Exception('不明なエラー: ${e.code}');
    }
  }

  //初回ログイン時のMFA初期設定用URL発行処理
  Future<String> generateTotpSecretUrl() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw InvalidUserSessionException();
    }

    try {
      final session = await user.multiFactor.getSession();

      _tempTotpSecret = await TotpMultiFactorGenerator.generateSecret(session);

      //URL生成
      final qrCodeUrl = _tempTotpSecret!.generateQrCodeUrl(accountName: user.email ?? 'ユーザ', issuer: 'CampusInfoShare',);
      return qrCodeUrl;
    } catch (e) {
      throw TotpSetupFailureException();
    }
  }

  //MFA登録完了処理
  Future<void> enrollTotpMfa(String otpCode) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || _tempTotpSecret == null) {
      throw InvalidMfaSetupSessionException();
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
        throw InvalidOtpException();
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
}