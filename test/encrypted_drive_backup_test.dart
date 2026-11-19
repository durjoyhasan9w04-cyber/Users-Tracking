import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/services/encrypted_drive_backup_service.dart';
void main(){
 group('EncryptedBackupCodec',(){
  test('encrypts and decrypts without changing payload',()async{
   final original=Uint8List.fromList(utf8.encode('dual database backup fixture'));
   final encrypted=await EncryptedBackupCodec.encrypt(original,'correct horse battery staple');
   expect(utf8.decode(encrypted),contains('AES-256-GCM'));
   final restored=await EncryptedBackupCodec.decrypt(encrypted,'correct horse battery staple');
   expect(restored,original);
  });
  test('rejects an incorrect passphrase',()async{
   final encrypted=await EncryptedBackupCodec.encrypt(Uint8List.fromList([1,2,3]),'long enough test passphrase');
   await expectLater(EncryptedBackupCodec.decrypt(encrypted,'wrong passphrase'),throwsA(anything));
  });
  test('requires a sufficiently long passphrase',()async{
   await expectLater(EncryptedBackupCodec.encrypt(Uint8List.fromList([1]),'short'),throwsArgumentError);
  });
 });
}
