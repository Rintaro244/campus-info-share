import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {

  final FirebaseAuth _firebaseAuth;
  
  //テスト用に偽物のFirebaseを作成
  //テスト時にはFirebaseAuth型の引数を渡してそれをインスタンス変数としてセットする．
  //アプリ実行時にはFirebaseAuthのインスタンスを作成
  AuthRepository({FirebaseAuth? firebaseAuth}): _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  //emailとpasswordからアカウントを仮登録し，uidと処理の成否を返す
  Future<(String, bool)> createTemporaryAccount(String email, String password) async {
    try{
      //仮登録処理 createUserWithEmailAndPasswordからUserCredentialオブジェクトが返される
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      //UserCredentialオブジェクトに含まれるuserオブジェクトを別の変数に格納
      final user = userCredential.user;
      if(user == null){
        throw Exception('アカウント作成失敗');
      }
      
      //確認メール送信処理
      await user.sendEmailVerification();

      //uidと送信成功ステータスを返す
      return (user.uid, true);
    } on FirebaseAuthException catch(e){
      //FirebaseAuthExceptionの例外コードに応じてthrowを投げる
      if(e.code == 'email-already-in-use'){
        throw Exception('このメールアドレスは既に登録されています');
      }else if(e.code == 'network-request-failed'){
        throw Exception('ネットワークエラー');
      }
      throw  Exception('不明なエラー: ${e.code}');
    }
  }

  //メール認証が完了しているかどうかを判定し，成否を返す
  Future<bool> checkEmailVerification() async {
    try{
      final user = _firebaseAuth.currentUser;
      if(user == null){
        return false;
      }

      //Firebaseのユーザ状態を再読み込み
      await user.reload();
      //メール認証完了の成否を返す
      return user.emailVerified;
    } on FirebaseAuthException catch(e){
      if(e.code == 'newwork-request-failed'){
        throw Exception('ネットワークエラー');
      }
      throw Exception('不明なエラー: ${e.code}');
    }
  }

  //
}