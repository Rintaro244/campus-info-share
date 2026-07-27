import 'package:student_information_1/shared/auth_exceptions.dart';
import 'package:student_information_1/C5/auth/auth_repository.dart';

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
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> finalizeMfaEnrollment(String otpCode) async {

    try {
      //MFA登録完了処理依頼
      await _authRepository.enrollTotpMfa(otpCode);
    } on InvalidMfaSetupSessionException {
      rethrow;
    } on InvalidOtpException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}