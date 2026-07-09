import 'package:student_information_1/C2/auth/account_creation_service.dart';
import 'package:student_information_1/C2/auth/login_service.dart';
import 'package:student_information_1/C2/auth/logout_service.dart';
import 'package:student_information_1/C2/auth/mfa_setup_service.dart';
import 'package:student_information_1/shared/auth_exceptions.dart';
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
    } on EmailNotVerifiedException {
      rethrow;
    } on InvalidCredentialException {
      throw Exception('メールアドレスまたはパスワードが間違っています');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  //OTP検証時
  Future<void> submitOtp(String otpCode) async {
    final otpRegex = RegExp(r'^\d{6}$');
    if (!otpRegex.hasMatch(otpCode)) {
      throw Exception('6桁の認証コード(数字)を正しく入力してください');
    }


    try {
      await _loginService.verifyOTP(otpCode);

      cSessionUid ='dummy_uid_form_firebase';
    } on InvalidOtpException {
      throw Exception('認証コードが間違っているか、有効期限が切れています');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  //アカウント新規作成時
  Future<void> submitRegistration(String mailAddress, String password, String passwordConfirm) async {
    
    if(mailAddress.isEmpty || password.isEmpty || passwordConfirm.isEmpty) {
      throw Exception('すべての項目を入力してください');
    }

    final alphanumericRegex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).{8,}$');
    if(!alphanumericRegex.hasMatch(password)) {
      throw Exception('パスワードは8文字以上で、英字と数字の両方を含めてください');
    }

    if(password != passwordConfirm) {
      throw Exception('パスワードと確認用パスワードが一致しません');
    }
    
    try {
      await _accountCreationService.requestAccountCreation(mailAddress, password, passwordConfirm);
    } on AccountCreationFailedException {
      throw Exception('アカウント作成に失敗しました');
    } on InvalidDomainException {
      throw Exception('芝浦工業大学のメールアドレス (@shibaura-it.ac.jp または @sic.shibaura-it.ac.jp) を使用してください');
    } on EmailAlreadyInUseException {
      try {
        //未認証だけどアカウント作成されてるかどうかを確かめる
        await _loginService.processLogin(mailAddress, password);
        //未認証でない場合
        throw Exception('このメールアドレスはすでに登録が完了しています。ログイン画面からログインしてください');
      } on EmailNotVerifiedException {
        //未認証の場合
        rethrow;
      } on MultiFactorAuthRequiredException {
        throw Exception('メール認証はすでに完了しています。ログイン画面からログインしてMFA設定を行ってください');
      } on MfaSetupRequiredException {
        throw Exception('メール認証はすでに完了しています。ログイン画面からログインしてMFA設定を行ってください');
      } on InvalidCredentialException {
        throw Exception('このメールアドレスは既に使用されています');
      } on InvalidUserSessionException {
        throw Exception('セッションが無効になりました');
      } on NetworkException {
        throw Exception('ネットワークエラーが発生しました');
      } catch (e) {
        throw Exception(e.toString());
      }
    } on MailSendFailureException {
      throw Exception('確認メールの送信に失敗しました');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  //メール認証時
  Future<bool> checkEmailVerified() async {
    try {
      await _accountCreationService.finalizeAccountRegistration();
      return true; // 認証完了
    } on EmailNotVerifiedException {
      return false; // まだ認証されていないので待機
    } on NetworkException {
      return false; // まだ認証されていないので待機
    } on InvalidUserSessionException {
      throw Exception('セッションが無効になりました'); //セッション無効時は終了させる
    } catch (e) {
      throw Exception(e.toString()); // その他のエラー時は終了させる
    }
  }

  Future<void> resendEmail() async {
    try {
      // Service層へ処理を委譲
      await _accountCreationService.resendVerificationEmail();
    } on TooManyRequestsException {
      throw Exception('メール送信回数が上限に達しました。しばらく待ってから再度お試しください');
    } on InvalidUserSessionException {
      throw Exception('セッションが切れました。もう一度最初から登録し直してください');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました。時間を置いて再度お試しください');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  //アカウント削除
  Future<void> deleteCurrentTemporaryAccount() async {
    try {
      await _accountCreationService.cancelAndCleanupAccount();
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  //MFA初期設定時
  Future<String> startMfaSetup() async {
    try {
      // C2層からQRコード用のデータ（またはURL）を取得する
      final qrData = await _mfaSetupService.initiateMfaSetup();
      return qrData;
    } on InvalidUserSessionException {
      throw Exception('セッションが無効です。もう一度ログインしなおしてください');
    } on TotpSetupFailureException {
      throw Exception('MFAの初期化に失敗しました。もう一度お試しください');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception(e.toString());
    }
    
  }

  //MFA初期設定完了時
  Future<void> completeMfaEnrollment(String otpCode) async {
    final otpRegex = RegExp(r'^\d{6}$');
    if (!otpRegex.hasMatch(otpCode)) {
      throw Exception('6桁の認証コード(数字)を正しく入力してください');
    }
    
    try {
      // C2層のMFA登録確定処理を呼び出す
      await _mfaSetupService.finalizeMfaEnrollment(otpCode);
    } on InvalidMfaSetupSessionException {
      throw Exception('MFA設定の有効期限が切れましたもう一度ログインしなおしてください');
    } on InvalidOtpException {
      throw Exception('認証コードが正しくありません。もう一度確認してください');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception(e.toString());
    }
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



//UIテスト用の実行
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