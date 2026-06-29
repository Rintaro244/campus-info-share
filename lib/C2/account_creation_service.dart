import 'package:flutter/material.dart';
import '../C5/auth_repository.dart';

class AccountCreationService{
  Future<String> requestAccountCreation
  (String emailAddress, String password, String passwordConfirm) async {

    //C5クラスインスタンス
    final AuthRepository _authRepository;
    
    //コンストラクタによる初期化s
    AccountCreationService({AuthRepository? authRepository}): _authRepository = authRepository ?? AuthRepository();
  

    //バリデーションチェック
    if(!validateDomain(emailAddress)){
    }
    if(!validatePassword(password, passwordConfirm)){
    }

    try{
      final (uid, isMailsent) = await _authRepository.createTemporaryAccount(emailAddress, password);
      if(isMailsent){
        return 'success';
      }else{
        return 'メール送信失敗';
      }
    } on EmailAlreadyInUseException catch(e){
    
    } on NetworkException catch(e){

    } catch(e){

    }
  }

  Future<void> finalizeAccountRegistration(){

  }

  //芝浦工業大学のドメインならtrue, そうでないならfalseを返す
  bool validateDomain(String emailAddress){
    final domain = ['@shibaura-it.ac.jp', '@sic.shibaura-it.ac.jp'];
    return domain.any((domain) => emailAddress.endsWith(domain));
  }

  bool validatePassword(String password, String passwordConfirm){
    return password == passwordConfirm;
  }
    
}