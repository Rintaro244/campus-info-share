//アカウント作成時にメールアドレスが既に使用されている場合
class EmailAlreadyInUseException implements Exception {}
//ネットワークエラー
class NetworkException implements Exception {}
//ログイン時OTP検証が必要な場合
class MultiFactorAuthRequiredException implements Exception {}
//ログイン時入力エラー
class InvalidCredentialException implements Exception {}
//OTP検証時入力エラー
class InvalidOtpException implements Exception {}
//アカウント作成時ドメインエラー
class InvalidDomainException implements Exception {}
//アカウント作成時パスワード不一致エラー
//class PasswordMismatchException implements Exception {}
//アカウント作成時メール送信エラー
class MailSendFailureException implements Exception {}
//アカウント作成時メール認証エラー
class EmailNotVerifiedException implements Exception {}
//ユーザセッションが無効な場合
class InvalidUserSessionException implements Exception {}
//アカウント作成エラー
class AccountCreationFailedException implements Exception {}
//OTP検証時ログインセッションが無効場合
class InvalidLoginSessionException implements Exception {}
//MFAのURL発行エラー
class TotpSetupFailureException implements Exception {}
//MFA登録時セットアップ情報エラー
class InvalidMfaSetupSessionException implements Exception {}
//サインアウト失敗
class SignOutFailureException implements Exception {}
//MFA登録が必要な場合
class MfaSetupRequiredException implements Exception {}
//アカウントデータ保存エラー
class AccountSaveFailureException implements Exception {}
//メール再送信をたくさん送っちゃったときのエラー(そんなことおこらないようにフロントエンドで対応してるけどね一応だよ一応)
class TooManyRequestsException implements Exception {}