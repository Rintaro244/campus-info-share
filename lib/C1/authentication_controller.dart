import 'package:student_information_1/C2/account_creation_service.dart';
import 'package:student_information_1/C2/login_service.dart';
import 'package:student_information_1/C2/logout_service.dart';
import 'package:student_information_1/C2/mfa_setup_service.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';

String? cSessionUid;

class AuthenticationController {
  final AccountCreationService _accountCreationService;
  final LoginService _loginService;
  final LogoutService _logoutService;

  AuthenticationController
  ({AccountCreationService? accountCreationService, 
    LoginService? loginService, 
    LogoutService? logoutService}) :
      _accountCreationService = accountCreationService ?? AccountCreationService(),
      _loginService = loginService ?? LoginService(),
      _logoutService = logoutService ?? LogoutService();

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
    } on InvalidCredentialException {
      throw Exception('メールアドレスまたはパスワードが間違っています');
    } on NetworkException {
      throw Exception('ネットワークエラーが発生しました');
    } catch (e) {
      throw Exception('不明なエラー');
    }
  }

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

  Future<void> submitLogout() async {
    try {
      await _logoutService.processLogout();
      cSessionUid = null;
    } catch (e) {
      throw Exception('ログアウトに失敗しました');
    }
  }
}