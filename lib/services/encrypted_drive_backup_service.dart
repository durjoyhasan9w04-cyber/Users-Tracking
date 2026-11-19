import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../data/quiz_database.dart';

const String driveBackupFormat = 'user-hub-encrypted-backup';
const int driveBackupFormatVersion = 1;
const int driveBackupPbkdf2Iterations = 210000;

class EncryptedBackupCodec {
  static final AesGcm _cipher = AesGcm.with256bits();
  static final Pbkdf2 _kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: driveBackupPbkdf2Iterations, bits: 256);

  static Future<Uint8List> encrypt(Uint8List plaintext, String passphrase) async {
    if (passphrase.trim().length < 10) throw ArgumentError('Use a backup passphrase with at least 10 characters.');
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
    final box = await _cipher.encrypt(plaintext, secretKey: key);
    final envelope = <String, Object?>{
      'format': driveBackupFormat,
      'version': driveBackupFormatVersion,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': driveBackupPbkdf2Iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  static Future<Uint8List> decrypt(Uint8List encrypted, String passphrase) async {
    if (passphrase.isEmpty) throw ArgumentError('Enter the backup passphrase.');
    final envelope = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    if (envelope['format'] != driveBackupFormat || envelope['version'] != driveBackupFormatVersion ||
        envelope['kdf'] != 'PBKDF2-HMAC-SHA256' || envelope['cipher'] != 'AES-256-GCM' ||
        envelope['iterations'] != driveBackupPbkdf2Iterations) {
      throw const FormatException('Unsupported encrypted backup format.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final cipherText = base64Decode(envelope['ciphertext'] as String);
    final mac = Mac(base64Decode(envelope['mac'] as String));
    final key = await _kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
    final plain = await _cipher.decrypt(SecretBox(cipherText, nonce: nonce, mac: mac), secretKey: key);
    return Uint8List.fromList(plain);
  }
}

class GoogleDriveBackupService {
  GoogleDriveBackupService._();
  static final GoogleDriveBackupService instance = GoogleDriveBackupService._();
  static const _scopes = ['https://www.googleapis.com/auth/drive.appdata'];
  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _uploadApi = 'https://www.googleapis.com/upload/drive/v3/files';
  Future<void>? _initialization;
  String? _configuredClientId;
  GoogleSignInAccount? _account;

  Future<String> signIn(String serverClientId) async {
    final clientId = serverClientId.trim();
    if (clientId.isEmpty) throw ArgumentError('Enter your Google OAuth Web client ID first.');
    if (_configuredClientId != null && _configuredClientId != clientId) {
      throw StateError('Google Sign-In was initialized with another client ID. Restart the app to change it.');
    }
    _configuredClientId = clientId;
    _initialization ??= GoogleSignIn.instance.initialize(serverClientId: clientId);
    await _initialization;
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('Google Sign-In is not supported on this device.');
    }
    _account = await GoogleSignIn.instance.authenticate();
    await _token();
    return _account!.email;
  }

  Future<String> _token() async {
    final account = _account;
    if (account == null) throw StateError('Connect Google Drive first.');
    final authorization = await account.authorizationClient.authorizationForScopes(_scopes)
        ?? await account.authorizationClient.authorizeScopes(_scopes);
    return authorization.accessToken;
  }

  Future<List<Map<String, Object?>>> listBackups() async {
    final token = await _token();
    final uri = Uri.parse('$_api/files').replace(queryParameters: {
      'spaces': 'appDataFolder',
      'pageSize': '50',
      'orderBy': 'createdTime desc',
      'fields': 'files(id,name,createdTime,size)',
    });
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw HttpException('Google Drive list failed (${response.statusCode}).');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['files'] as List<dynamic>? ?? const []).cast<Map<String, Object?>>();
  }

  Future<void> upload(Uint8List encryptedBytes) async {
    final token = await _token();
    final boundary = 'userhub_${DateTime.now().microsecondsSinceEpoch}';
    final filename = 'user-hub-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.uhb';
    final metadata = jsonEncode({'name': filename, 'parents': ['appDataFolder'], 'mimeType': 'application/octet-stream'});
    final body = <int>[
      ...utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n'),
      ...utf8.encode('--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n'),
      ...encryptedBytes,
      ...utf8.encode('\r\n--$boundary--'),
    ];
    final response = await http.post(Uri.parse('$_uploadApi?uploadType=multipart&fields=id,name'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'multipart/related; boundary=$boundary'},
      body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Google Drive upload failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<Uint8List> download(String fileId) async {
    final token = await _token();
    final response = await http.get(Uri.parse('$_api/files/${Uri.encodeComponent(fileId)}?alt=media'),
      headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw HttpException('Google Drive download failed (${response.statusCode}).');
    return response.bodyBytes;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _account = null;
  }
}

class UserHubDriveBackup {
  static Future<Uint8List> create(String passphrase) async {
    final mainDb = await AppDatabase.instance.database;
    final quizDb = await QuizDatabase.instance.database;
    await mainDb.rawQuery('PRAGMA wal_checkpoint(FULL)');
    await quizDb.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final root = await getDatabasesPath();
    final mainBytes = await File(p.join(root, 'user_hub.db')).readAsBytes();
    final quizBytes = await File(p.join(root, 'quiz_participants.db')).readAsBytes();
    final payload = utf8.encode(jsonEncode({
      'format': 'user-hub-dual-database',
      'mainDatabase': base64Encode(mainBytes),
      'quizDatabase': base64Encode(quizBytes),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    }));
    return EncryptedBackupCodec.encrypt(Uint8List.fromList(payload), passphrase);
  }

  static Future<void> restore(Uint8List encrypted, String passphrase) async {
    final plain = await EncryptedBackupCodec.decrypt(encrypted, passphrase);
    final payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    if (payload['format'] != 'user-hub-dual-database') throw const FormatException('This backup does not contain both User Hub databases.');
    final temp = await getTemporaryDirectory();
    final root = await getDatabasesPath();
    final mainPath = p.join(root, 'user_hub.db');
    final quizPath = p.join(root, 'quiz_participants.db');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final candidateMain = File(p.join(temp.path, 'restore-main-$stamp.db'));
    final candidateQuiz = File(p.join(temp.path, 'restore-quiz-$stamp.db'));
    final rollbackMain = File(p.join(temp.path, 'rollback-main-$stamp.db'));
    final rollbackQuiz = File(p.join(temp.path, 'rollback-quiz-$stamp.db'));
    await candidateMain.writeAsBytes(base64Decode(payload['mainDatabase'] as String), flush: true);
    await candidateQuiz.writeAsBytes(base64Decode(payload['quizDatabase'] as String), flush: true);
    final mainCheck = await openDatabase(candidateMain.path, readOnly: true);
    final quizCheck = await openDatabase(candidateQuiz.path, readOnly: true);
    try {
      final mainIntegrity = await mainCheck.rawQuery('PRAGMA integrity_check');
      final mainVersionRows = await mainCheck.rawQuery('PRAGMA user_version');
      final version = (mainVersionRows.first.values.first as num).toInt();
      final tables = await mainCheck.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final names = tables.map((r) => r['name'] as String).toSet();
      if (mainIntegrity.first.values.first != 'ok' || !names.containsAll(requiredBackupTablesForVersion(version))) {
        throw StateError('The main database in this backup is invalid or incomplete.');
      }
      final quizIntegrity = await quizCheck.rawQuery('PRAGMA integrity_check');
      final quizTables = await quizCheck.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final quizNames = quizTables.map((r) => r['name'] as String).toSet();
      if (quizIntegrity.first.values.first != 'ok' || !quizNames.containsAll({'quiz_participants','quizzes','quiz_participations','quiz_bonus_entries'})) {
        throw StateError('The quiz database in this backup is invalid or incomplete.');
      }
    } finally {
      await mainCheck.close();
      await quizCheck.close();
    }
    final mainFile = File(mainPath);
    final quizFile = File(quizPath);
    if (await mainFile.exists()) await mainFile.copy(rollbackMain.path);
    if (await quizFile.exists()) await quizFile.copy(rollbackQuiz.path);
    try {
      await AppDatabase.instance.restoreBackupFile(candidateMain.path);
      await QuizDatabase.instance.close();
      await candidateQuiz.copy(quizPath);
      final restoredQuiz = await QuizDatabase.instance.database;
      final quizIntegrity = await restoredQuiz.rawQuery('PRAGMA integrity_check');
      if (quizIntegrity.isEmpty || quizIntegrity.first.values.first != 'ok') {
        throw StateError('Restored quiz database failed its integrity check.');
      }
    } catch (_) {
      if (await rollbackMain.exists()) await AppDatabase.instance.restoreBackupFile(rollbackMain.path);
      await QuizDatabase.instance.close();
      if (await rollbackQuiz.exists()) await rollbackQuiz.copy(quizPath);
      await QuizDatabase.instance.database;
      rethrow;
    } finally {
      for (final file in [candidateMain, candidateQuiz, rollbackMain, rollbackQuiz]) {
        if (await file.exists()) await file.delete();
      }
    }
  }
}
