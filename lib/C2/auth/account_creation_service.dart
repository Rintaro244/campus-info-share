//import 'package:flutter/material.dart';
import 'package:student_information_1/shared/auth_exceptions.dart';
import 'package:student_information_1/C5/auth/auth_repository.dart';

class AccountCreationService{

    //C5クラスインスタンス
    final AuthRepository _authRepository;
    
    //コンストラクタによる初期化
    AccountCreationService({AuthRepository? authRepository}): _authRepository = authRepository ?? AuthRepository();

  Future<void> requestAccountCreation
  (String emailAddress, String password, String passwordConfirm) async {

    //バリデーションチェック
    if(!validateDomain(emailAddress)){
      throw InvalidDomainException();
    }
    /*if(!validatePassword(password, passwordConfirm)){
      throw PasswordMismatchException();
    }*/

    try{
      //仮認証および確認メール送信依頼
      await _authRepository.createTemporaryAccount(emailAddress, password);

    } on AccountCreationFailedException {
      rethrow;
    } on MailSendFailureException {
      rethrow;
    } on EmailAlreadyInUseException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> finalizeAccountRegistration() async {
    try {
      //認証済みか確認依頼
      await _authRepository.checkEmailVerification();

      //final uid = _authRepository.currentUid;
      //final email = _authRepository.getCurrentUid;

      //アカウントをデータベースに登録

    } on InvalidUserSessionException {
      rethrow;
    } on EmailNotVerifiedException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  //アカウント削除処理
  Future<void> cancelAndCleanupAccount() async {
    try {
      await _authRepository.deleteCurrentUser();
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }


  //芝浦工業大学のドメインならtrue, そうでないならfalseを返す
  bool validateDomain(String emailAddress){
    final domain = ['@shibaura-it.ac.jp', '@sic.shibaura-it.ac.jp'];
    return domain.any((domain) => emailAddress.endsWith(domain));
  }
  //パスワードが一致していればtrue, そうでないならfalseを返す
  /*bool validatePassword(String password, String passwordConfirm){
    return password == passwordConfirm;
  }*/
    
}