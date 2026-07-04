//import 'package:flutter/material.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';
import 'package:student_information_1/C5/auth_repository.dart';

//例外は後で分類する

class LoginService{
  //C5クラスインスタンス
  final AuthRepository _authRepository;
  
  //コンストラクタによる初期化
  LoginService({AuthRepository? authRepository}): _authRepository = authRepository ?? AuthRepository();

  Future<void> processLogin(String emailAddress, String password) async {
    if (!validateLoginInput(emailAddress, password)) {
      throw Exception('メールアドレスとパスワードを入力してください');
    }

    try {
      //パスワード認証依頼
      await _authRepository.requestSignInWithPassword(emailAddress, password);

      //初回認証の場合、MFA検証の例外が発生しないため、以下の処理に入る。
      final isEnrolled = await _authRepository.checkIsMfaEnrolled();

      if (!isEnrolled) {
        throw MfaSetupRequiredException();
      }

    } on MultiFactorAuthRequiredException {
      //MFA検証が必要
      rethrow;
    } on InvalidCredentialException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw Exception('不明なエラー');
    }
  }

  Future<void> verifyOTP(String otpCode) async { 
    try {
      //OTP検証依頼
      await _authRepository.requestVerifyOTP(otpCode); 
    } on InvalidLoginSessionException {
      rethrow;
    } on InvalidOtpException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw Exception('不明なエラー');
    }
  }

  bool validateLoginInput(String emailAddress, String password) {
    //後で条件修正する
    if (emailAddress.isEmpty || password.isEmpty) {
      return false;
    }
    return true;
  }
}