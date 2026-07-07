import 'package:student_information_1/exceptions/auth_exceptions.dart';
import 'package:student_information_1/C5/auth_repository.dart';

class MfaSetupService {
  // C5クラスインスタンス
  final AuthRepository _authRepository;

  // コンストラクタによる初期化
  MfaSetupService({AuthRepository? authRepository}): _authRepository = authRepository ?? AuthRepository();

  Future<String> initiateMfaSetup() async {
    try {
      //URL生成依頼
      final qrCodeUrl = await _authRepository.generateTotpSecretUrl();
      return qrCodeUrl;
    } on InvalidUserSessionException {
      rethrow;
    } on TotpSetupFailureException {
      rethrow;
    } catch (e) {
      throw Exception('不明なエラー');
    }
  }

  Future<void> finalizeMfaEnrollment(String otpCode) async {
    if (!validateOtpInput(otpCode)) {
      throw InvalidOtpException();
    }

    try {
      //MFA登録完了処理依頼
      await _authRepository.enrollTotpMfa(otpCode);
    } on InvalidMfaSetupSessionException {
      rethrow;
    } on InvalidOtpException {
      rethrow;
    } catch (e) {
      throw Exception('不明なエラー');
    }
  }

  bool validateOtpInput(String otpCode) {
    final regExp = RegExp(r'^\d{6}$');
    return regExp.hasMatch(otpCode);
  }
}