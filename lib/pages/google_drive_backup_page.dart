// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/encrypted_drive_backup_service.dart';

class GoogleDriveBackupPage extends StatefulWidget {
  const GoogleDriveBackupPage({super.key});
  @override State<GoogleDriveBackupPage> createState()=>_GoogleDriveBackupPageState();
}
class _GoogleDriveBackupPageState extends State<GoogleDriveBackupPage>{
  final clientId=TextEditingController();final passphrase=TextEditingController();
  bool busy=false,connected=false;String account='',status='Connect a Google account to use its private app-data backup area.';List<Map<String,Object?>> backups=[];
  @override void initState(){super.initState();loadClientId();}
  Future<void> loadClientId()async{final p=await SharedPreferences.getInstance();clientId.text=p.getString('user_hub_drive_oauth_client_id')??'';}
  @override void dispose(){clientId.dispose();passphrase.dispose();super.dispose();}
  Future<void> connect()async{
    setState(()=>busy=true);
    try{final email=await GoogleDriveBackupService.instance.signIn(clientId.text);final p=await SharedPreferences.getInstance();await p.setString('user_hub_drive_oauth_client_id',clientId.text.trim());final rows=await GoogleDriveBackupService.instance.listBackups();if(!mounted)return;setState((){connected=true;account=email;backups=rows;status='Connected. Backups are stored in Google Drive app data and are not visible in your normal Drive files.';});}
    catch(e){if(mounted)setState(()=>status='Could not connect: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> refreshBackups()async{setState(()=>busy=true);try{final rows=await GoogleDriveBackupService.instance.listBackups();if(mounted)setState(()=>backups=rows);}catch(e){if(mounted)setState(()=>status='Could not load backups: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> createBackup()async{
    if(passphrase.text.trim().length<10){setState(()=>status='Set a passphrase with at least 10 characters. Keep it safe; it cannot be recovered.');return;}
    setState(()=>busy=true);
    try{final bytes=await UserHubDriveBackup.create(passphrase.text);await GoogleDriveBackupService.instance.upload(bytes);passphrase.clear();await refreshBackups();if(mounted)setState(()=>status='Encrypted backup uploaded. Both SQLite databases are included.');}
    catch(e){if(mounted)setState(()=>status='Backup failed: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> restoreBackup(Map<String,Object?> backup)async{
    if(passphrase.text.isEmpty){setState(()=>status='Enter the original backup passphrase before restoring.');return;}
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Restore encrypted backup?'),content:const Text('This replaces both local databases. The app validates both databases first and keeps rollback copies during restore. Export a separate backup before continuing.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Restore'))]));
    if(ok!=true||!mounted)return;
    setState(()=>busy=true);
    try{final bytes=await GoogleDriveBackupService.instance.download(backup['id'].toString());await UserHubDriveBackup.restore(bytes,passphrase.text);passphrase.clear();if(mounted)setState(()=>status='Both databases restored and integrity-checked. Restart the app if an open screen still shows old data.');}
    catch(e){if(mounted)setState(()=>status='Restore failed: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Encrypted Google Drive backup')),body:ListView(padding:const EdgeInsets.all(18),children:[
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Google OAuth setup',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
      const SizedBox(height:8),
      const Text('Create an OAuth 2.0 Web client ID in Google Cloud Console, configure the Android OAuth client for this app package and signing certificate, and enable the Google Drive API. Paste the Web client ID below.'),
      const SizedBox(height:10),
      TextField(controller:clientId,decoration:const InputDecoration(labelText:'Google OAuth Web client ID')),
      const SizedBox(height:10),
      FilledButton.icon(onPressed:busy?null:connect,icon:const Icon(Icons.account_circle_outlined),label:Text(connected?'Reconnect Google account':'Connect Google Drive')),
      if(connected)Text('Connected account: $account',style:const TextStyle(fontWeight:FontWeight.w600)),
    ]))),
    const SizedBox(height:12),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Backup encryption',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
      const SizedBox(height:8),
      const Text('Both user_hub.db and quiz_participants.db are encrypted together using AES-256-GCM. A password-derived key uses PBKDF2-HMAC-SHA256. The passphrase is never uploaded or saved. If you lose it, the backup cannot be decrypted.'),
      const SizedBox(height:10),
      TextField(controller:passphrase,obscureText:true,decoration:const InputDecoration(labelText:'Backup passphrase (10+ characters)')),
      const SizedBox(height:10),
      FilledButton.icon(onPressed:busy||!connected?null:createBackup,icon:const Icon(Icons.cloud_upload_outlined),label:const Text('Create encrypted backup')),
    ]))),
    const SizedBox(height:12),
    Row(children:[const Expanded(child:Text('Cloud backups',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800))),IconButton(onPressed:busy||!connected?null:refreshBackups,icon:const Icon(Icons.refresh_rounded))]),
    if(backups.isEmpty)const Text('No backups found yet.') else ...backups.map((b)=>Card(child:ListTile(
      leading:const Icon(Icons.lock_outline_rounded),title:Text(b['name']?.toString()??'Encrypted backup'),
      subtitle:Text('${b['createdTime']??''} · ${b['size']??'—'} bytes'),
      trailing:IconButton(tooltip:'Restore this backup',onPressed:busy?null:()=>restoreBackup(b),icon:const Icon(Icons.restore_rounded)),
    ))),
    const SizedBox(height:12),
    if(busy)const LinearProgressIndicator(),
    SelectableText(status,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant)),
  ]));
}
