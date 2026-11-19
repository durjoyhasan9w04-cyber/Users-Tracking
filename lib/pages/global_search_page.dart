import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/quiz_database.dart';
import 'activity_center_page.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key,required this.onOpenUser,required this.onOpenReports});
  final ValueChanged<int> onOpenUser;
  final VoidCallback onOpenReports;
  @override State<GlobalSearchPage> createState()=>_GlobalSearchPageState();
}
class _GlobalSearchPageState extends State<GlobalSearchPage>{
 final controller=TextEditingController();String query='';Future<List<_SearchHit>>? future;
 @override void dispose(){controller.dispose();super.dispose();}
 Future<List<_SearchHit>> search(String raw) async {
  final term=raw.trim().toLowerCase();if(term.length<2)return [];
  final data=await Future.wait<Object>([
   AppDatabase.instance.getUsers(search:raw),
   AppDatabase.instance.getUnifiedActivityEvents(limit:500),
   QuizDatabase.instance.getParticipants(search:raw),
   QuizDatabase.instance.getQuizzes(),
   QuizDatabase.instance.getActivityEvents(limit:250),
  ]);
  final hits=<_SearchHit>[];
  for(final u in data[0] as List<Map<String,Object?>>){
   hits.add(_SearchHit(type:'User',title:u['name']?.toString()??'User',subtitle:u['phone']?.toString()??'',userId:(u['id'] as num?)?.toInt()));
  }
  for(final p in data[2] as List<Map<String,Object?>>){
   hits.add(_SearchHit(type:'Quiz participant',title:p['name']?.toString()??'Participant',subtitle:p['phone']?.toString()??''));
  }
  for(final q in data[3] as List<Map<String,Object?>>){
   final text='${q['title']} ${q['notes']}';
   if(text.toLowerCase().contains(term))hits.add(_SearchHit(type:'Quiz',title:q['title']?.toString()??'Quiz',subtitle:q['quiz_date']?.toString()??''));
  }
  final events=<Map<String,Object?>>[...(data[1] as List<Map<String,Object?>>),...(data[4] as List<Map<String,Object?>>)];
  for(final e in events){
   final hay='${e['kind']} ${e['title']} ${e['name']} ${e['detail']} ${e['event_date']}';
   if(hay.toLowerCase().contains(term))hits.add(_SearchHit(type:e['kind']?.toString()??'Activity',title:e['title']?.toString()??'Activity',subtitle:'${e['name']??''} · ${e['event_date']??''}',userId:(e['user_id'] as num?)?.toInt(),event:e));
  }
  if('report'.contains(term)||term.contains('report'))hits.add(const _SearchHit(type:'Reports',title:'Reports & export',subtitle:'Open date-range report preview and export'));
  hits.sort((a,b)=>a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return hits.take(250).toList();
 }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Global Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: (value) {
                setState(() => query = value);
                if (value.trim().length >= 2) {
                  setState(() => future = search(value));
                } else {
                  setState(() => future = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search name, phone, DP, bonus, quiz, task or issue',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    controller.clear();
                    setState(() {
                      query = '';
                      future = null;
                    });
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          Expanded(
            child: query.trim().length < 2
                ? const Center(child: Text('Enter at least 2 characters to search.'))
                : FutureBuilder<List<_SearchHit>>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('Search failed. Please try again.'));
                      }
                      final rows = snapshot.data ?? [];
                      if (rows.isEmpty) {
                        return const Center(child: Text('No matching records found.'));
                      }
                      return ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final event = row.event;
                          final icon = row.type == 'User'
                              ? Icons.person_outline
                              : (row.type == 'Quiz' || row.type == 'Quiz participant')
                                  ? Icons.quiz_outlined
                                  : row.type == 'Reports'
                                      ? Icons.summarize_outlined
                                      : Icons.receipt_long_outlined;
                          return ListTile(
                            leading: CircleAvatar(child: Icon(icon)),
                            title: Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${row.type} · ${row.subtitle}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              if (row.type == 'Reports') {
                                widget.onOpenReports();
                              } else if (row.type == 'User' && row.userId != null) {
                                widget.onOpenUser(row.userId!);
                              } else if (event != null) {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ActivityRecordDetailPage(
                                    event: event,
                                    onOpenUser: (id) {
                                      Navigator.of(context).pop();
                                      widget.onOpenUser(id);
                                    },
                                  ),
                                ));
                              } else if (row.userId != null) {
                                widget.onOpenUser(row.userId!);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

class _SearchHit{
 const _SearchHit({required this.type,required this.title,required this.subtitle,this.userId,this.event});
 final String type,title,subtitle;final int? userId;final Map<String,Object?>? event;
}
