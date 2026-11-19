import 'dart:math' as math;
class UserConsistency {
 const UserConsistency({required this.userId,required this.name,required this.activeDays,required this.score,required this.currentStreak,required this.totalDp});
 final int userId;final String name;final int activeDays;final int score;final int currentStreak;final double totalDp;
}
class PeriodComparison {
 const PeriodComparison({required this.currentDp,required this.previousDp,required this.currentBonus,required this.previousBonus,required this.currentDpCount,required this.previousDpCount});
 final double currentDp,previousDp,currentBonus,previousBonus;final int currentDpCount,previousDpCount;
 double get dpChangePercent=>_change(currentDp,previousDp);double get bonusChangePercent=>_change(currentBonus,previousBonus);
 static double _change(double c,double p)=>p==0?(c==0?0:100):(c-p)/p*100;
}
class AnalyticsCalculator {
 static PeriodComparison compare({required Iterable<Map<String,Object?>> dpRows,required Iterable<Map<String,Object?>> bonusRows,required DateTime start,required DateTime end}) {
  final previousStart=start.subtract(end.difference(start));
  double sum(Iterable<Map<String,Object?>> rows,String key,DateTime from,DateTime until)=>rows.where((r){final d=DateTime.tryParse((r['entry_date']??'').toString());return d!=null&&!d.isBefore(from)&&d.isBefore(until);}).fold<double>(0,(s,r)=>s+((r[key] as num?)?.toDouble()??0));
  int count(Iterable<Map<String,Object?>> rows,DateTime from,DateTime until)=>rows.where((r){final d=DateTime.tryParse((r['entry_date']??'').toString());return d!=null&&!d.isBefore(from)&&d.isBefore(until);}).length;
  return PeriodComparison(currentDp:sum(dpRows,'total',start,end),previousDp:sum(dpRows,'total',previousStart,start),currentBonus:sum(bonusRows,'amount',start,end),previousBonus:sum(bonusRows,'amount',previousStart,start),currentDpCount:count(dpRows,start,end),previousDpCount:count(dpRows,previousStart,start));
 }
 static List<UserConsistency> consistency({required List<Map<String,Object?>> users,required List<Map<String,Object?>> dpRows,required DateTime start,required DateTime end}) {
  final days=math.max(1,end.difference(start).inDays);final yesterday=DateTime(end.year,end.month,end.day).subtract(const Duration(days:2));
  final grouped=<int,Set<String>>{};final totals=<int,double>{};
  for(final r in dpRows){final id=(r['user_id'] as num?)?.toInt();final raw=(r['entry_date']??'').toString();final d=DateTime.tryParse(raw);if(id==null||d==null||d.isBefore(start)||!d.isBefore(end))continue;grouped.putIfAbsent(id,()=>{}).add(raw.substring(0,10));totals[id]=(totals[id]??0)+((r['total'] as num?)?.toDouble()??0);}
  final out=<UserConsistency>[];
  for(final u in users){final id=(u['id'] as num?)?.toInt();if(id==null)continue;final dates=grouped[id]??<String>{};var streak=0;var cursor=yesterday;while(dates.contains(cursor.toIso8601String().substring(0,10))){streak++;cursor=cursor.subtract(const Duration(days:1));}out.add(UserConsistency(userId:id,name:u['name']?.toString()??'Unknown',activeDays:dates.length,score:((dates.length/days)*100).round().clamp(0,100),currentStreak:streak,totalDp:totals[id]??0));}
  out.sort((a,b)=>b.score.compareTo(a.score));return out;
 }
 static Map<String,double> bonusByReason(Iterable<Map<String,Object?>> rows){final out=<String,double>{};for(final r in rows){final k=(r['reason']??'Other').toString();out[k]=(out[k]??0)+((r['amount'] as num?)?.toDouble()??0);}return out;}
 static Map<String,int> userGrowthByMonth(Iterable<Map<String,Object?>> users,{int months=6,DateTime? now}){final current=now??DateTime.now();final out=<String,int>{};for(var i=months-1;i>=0;i--){final d=DateTime(current.year,current.month-i);out['${d.year}-${d.month.toString().padLeft(2,'0')}']=0;}for(final u in users){final d=DateTime.tryParse((u['created_at']??'').toString());if(d==null)continue;final k='${d.year}-${d.month.toString().padLeft(2,'0')}';if(out.containsKey(k))out[k]=out[k]!+1;}return out;}
}
