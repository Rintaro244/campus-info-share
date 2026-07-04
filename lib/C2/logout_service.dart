//import 'package:flutter/material.dart';
import 'package:student_information_1/exceptions/auth_exceptions.dart';
import 'package:student_information_1/C5/auth_repository.dart';

class LogoutService{
  //C5クラスインスタンス
  final AuthRepository _authRepository;
  
  //コンストラクタによる初期化
  LogoutService({AuthRepository? authRepository}): _authRepository = authRepository ?? AuthRepository();

  Future<void> processLogout() async {
    try {
      //ログアウト依頼
      await _authRepository.requestSignOut();
    } on SignOutFailureException {
      rethrow;
    } catch (e){
      throw Exception('不明なエラー');
    }
  }
}