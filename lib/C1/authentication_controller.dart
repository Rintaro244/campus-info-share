import 'package:student_information_1/C2/account_creation_service.dart';
import 'package:student_information_1/C2/login_service.dart';
import 'package:student_information_1/C2/logout_service.dart';
import 'package:student_information_1/C2/mfa_setup_service.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';
//import 'dart:async';


//グローバル変数
String? cSessionUid;

class AuthenticationController {
  final AccountCreationService _accountCreationService;
  final LoginService _loginService;
  final LogoutService _logoutService;
  final MfaSetupService _mfaSetupService;

  AuthenticationController
  ({AccountCreationService? accountCreationService, 
    LoginService? loginService, 
    LogoutService? logoutService,
    MfaSetupService? mfaSetupService}) :
      _accountCreationService = accountCreationService ?? AccountCreationService(),
      _loginService = loginService ?? LoginService(),
      _logoutService = logoutService ?? LogoutService(),
      _mfaSetupService = mfaSetupService ?? MfaSetupService();

  //ログイン時
  Future<int> submitLogin(String mailAddress, String password) async {
    if(mailAddress.isEmpty || password.isEmpty) {
      throw Exception('メールアドレスとパスワードを入力してください');
    }

    try {
      await _loginService.processLogin(mailAddress, password);
      cSessionUid = 'dummy_uid_form_firebase';


      //ログイン成功
      return 1;
    } on MultiFactorAuthRequiredException {
      //OTP検証へ遷移
      return 2;
    } on MfaSetupRequiredException {
      //MFA初期設定へ遷移
      return 3;
    } on InvalidCredentialException {
      throw Exception('メールアドレスまたはパスワードが間違っています');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception('不明なエラー');
    }
  }

  //OTP検証時
  Future<void> submitOtp(String otpCode) async {
    try {
      await _loginService.verifyOTP(otpCode);

      cSessionUid ='dummy_uid_form_firebase';
    } on InvalidOtpException {
      throw Exception('認証コードが間違っているか、有効期限が切れています');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception('不明なエラー');
    }
  }

  //アカウント新規作成時
  Future<void> submitRegistration(String mailAddress, String password, String passwordConfirm) async {
    try {
      await _accountCreationService.requestAccountCreation(mailAddress, password, passwordConfirm);
    } on InvalidDomainException {
      throw Exception('このメールアドレスは使用できません');
    } on PasswordMismatchException {
      throw Exception('パスワードが一致しません');
    } on EmailAlreadyInUseException {
      throw Exception('このメールアドレスは既に登録されています');
    } on MailSendFailureException {
      throw Exception('確認メールの送信に失敗しました');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception('不明なエラー');
    }
  }

  Future<bool> checkEmailVerified() async {
    try {
      await _accountCreationService.finalizeAccountRegistration();
      return true; // 認証完了
    } on EmailNotVerifiedException {
      return false; // まだ認証されていない
    } catch (e) {
      return false; // その他のエラー時は待機を継続
    }
  }

  //MFA初期設定時
  Future<String> startMfaSetup() async {
    // C2層からQRコード用のデータ（またはURL）を取得する
    final qrData = await _mfaSetupService.initiateMfaSetup();
    return qrData;
  }

  //MFA初期設定完了時
  Future<void> completeMfaEnrollment(String otpCode) async {
    if (otpCode.isEmpty || otpCode.length != 6) {
      throw Exception('6桁の認証コードを正しく入力してください。');
    }

    // C2層のMFA登録確定処理を呼び出す
    await _mfaSetupService.finalizeMfaEnrollment(otpCode);
  }

  //ログアウト時
  Future<void> submitLogout() async {
    try {
      await _logoutService.processLogout();
      cSessionUid = null;
    } catch (e) {
      throw Exception('ログアウトに失敗しました');
    }
  }
}



//いったんテスト用の実行を有効化
/*
class AuthenticationController {
  // ログイン処理
  // 戻り値: 1=Home(MFAなし), 2=OTP入力画面(MFA登録済), 3=MFA初期設定画面(初回)
  Future<int> submitLogin(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    // テスト用: ここを 1, 2, 3 に書き換えることで遷移先をテストできます
    // 今回の要望通り「初回ログイン」を想定して 3 を返します
    return 3; 
  }

  // 新規登録処理
  Future<void> submitRegistration(String email, String password, String confirmPassword) async {
    await Future.delayed(const Duration(seconds: 1));
    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      throw Exception('すべての項目を入力してください。');
    }
    if (password != confirmPassword) {
      throw Exception('パスワードが一致しません。');
    }
    // 成功したフリをして何も返さず終了
  }

  // MFA初期設定（QRコード生成）
  Future<String> startMfaSetup() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'dummy_qr_data';
  }

  // MFA初期設定完了
  Future<void> completeMfaEnrollment(String otpCode) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  // OTP認証（ログイン時）
  Future<void> submitOtp(String otpCode) async {
    await Future.delayed(const Duration(seconds: 1));
  }
}*/