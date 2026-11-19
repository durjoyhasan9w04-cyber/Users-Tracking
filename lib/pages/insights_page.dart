import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../services/analytics_calculator.dart';
class InsightsPage extends StatefulWidget {const InsightsPage({super.key});@override State<InsightsPage> createState()=>_InsightsPageState();}
class _InsightsPageState extends State<InsightsPage>{
 late Future<_InsightsData> future;int days=30;
 @override void initState(){super.initState();load();}
 void load(){future=Future.wait<Object>([AppDatabase.instance.getUsers(),AppDatabase.instance.getDpEntries(),AppDatabase.instance.getBonusEntries()]).then((v){
  final now=DateTime.now();final end=DateTime(now.year,now.month,now.day).add(const Duration(days:1));final start=end.subtract(Duration(days:days));
  final users=v[0] as List<Map<String,Object?>>;final dp=v[1] as List<Map<String,Object?>>;final bonus=v[2] as List<Map<String,Object?>>;
  bool inRange(Map<String,Object?> r){final d=DateTime.tryParse((r['entry_date']??'').toString());return d!=null&&!d.isBefore(start)&&d.isBefore(end);}
  final scopedDp=dp.where(inRange).toList();final scopedBonus=bonus.where(inRange).toList();
  return _InsightsData(AnalyticsCalculator.compare(dpRows:dp,bonusRows:bonus,start:start,end:end),AnalyticsCalculator.consistency(users:users,dpRows:dp,start:start,end:end),AnalyticsCalculator.bonusByReason(scopedBonus),AnalyticsCalculator.userGrowthByMonth(users),scopedDp);
 });}
 String coins(num n)=>n.toStringAsFixed(n%1==0?0:2);
 Widget section(String title,Widget child)=>Card(margin:const EdgeInsets.only(bottom:14),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:12),child])));
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Advanced Analytics')),body:FutureBuilder<_InsightsData>(future:future,builder:(context,snap){
  if(snap.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(snap.hasError)return const Center(child:Text('Analytics could not be loaded. Refresh and try again.'));
  final d=snap.data!;final totals=<int,double>{};final names=<int,String>{};
  for(final r in d.dpRows){final id=(r['user_id'] as num?)?.toInt();if(id!=null){totals[id]=(totals[id]??0)+((r['total'] as num?)?.toDouble()??0);names[id]=r['user_name']?.toString()??'User';}}
  final ranking=totals.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));final maxBonus=d.bonusMix.values.fold<double>(0,(a,b)=>a>b?a:b);final maxGrowth=d.growth.values.fold<int>(0,(a,b)=>a>b?a:b);
  return RefreshIndicator(onRefresh:()async{setState(load);await future;},child:ListView(padding:const EdgeInsets.all(16),children:[
   SegmentedButton<int>(segments:const [ButtonSegment(value:7,label:Text('7 days')),ButtonSegment(value:30,label:Text('30 days')),ButtonSegment(value:90,label:Text('90 days'))],selected:{days},onSelectionChanged:(v)=>setState((){days=v.first;load();})),
   const SizedBox(height:12),
   section('Date-range comparison · current vs previous $days days',Column(children:[
    _CompareRow(label:'DP',current:d.comparison.currentDp,previous:d.comparison.previousDp,change:d.comparison.dpChangePercent,format:coins),const Divider(),
    _CompareRow(label:'Bonus',current:d.comparison.currentBonus,previous:d.comparison.previousBonus,change:d.comparison.bonusChangePercent,format:coins),
    _CompareRow(label:'DP transactions',current:d.comparison.currentDpCount.toDouble(),previous:d.comparison.previousDpCount.toDouble(),change:d.comparison.previousDpCount==0?(d.comparison.currentDpCount==0?0:100):(d.comparison.currentDpCount-d.comparison.previousDpCount)/d.comparison.previousDpCount*100,format:(n)=>n.toStringAsFixed(0)),
   ])),
   section('Top DP contributions',ranking.isEmpty?const Text('No DP transactions in this period.'):Column(children:[for(var i=0;i<ranking.take(10).length;i++)ListTile(dense:true,leading:CircleAvatar(radius:15,child:Text('${i+1}')),title:Text(names[ranking[i].key]??'User'),trailing:Text('${coins(ranking[i].value)} coins',style:const TextStyle(fontWeight:FontWeight.w800)))])),
   section('DP consistency score',Column(children:[const Text('Score = active DP days ÷ selected period days. It measures frequency, not monetary value.'),const SizedBox(height:8),for(final u in d.consistency.where((x)=>x.activeDays>0).take(12))Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Column(children:[Row(children:[Expanded(child:Text(u.name,style:const TextStyle(fontWeight:FontWeight.w600))),Text('${u.score}% · ${u.activeDays}/$days days')]),const SizedBox(height:4),LinearProgressIndicator(value:u.score/100,minHeight:7),Align(alignment:Alignment.centerRight,child:Text('Current streak: ${u.currentStreak} days',style:Theme.of(context).textTheme.bodySmall))]))])),
   section('Bonus distribution by reason',d.bonusMix.isEmpty?const Text('No bonuses in this period.'):Column(children:[for(final e in d.bonusMix.entries)Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Column(children:[Row(children:[Expanded(child:Text(e.key)),Text('${coins(e.value)} coins')]),const SizedBox(height:4),LinearProgressIndicator(value:maxBonus==0?0:e.value/maxBonus,minHeight:7)]))])),
   section('User growth · new profiles per month',Column(children:[for(final e in d.growth.entries)Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Column(children:[Row(children:[Expanded(child:Text(e.key)),Text('${e.value} users')]),const SizedBox(height:4),LinearProgressIndicator(value:maxGrowth==0?0:e.value/maxGrowth,minHeight:7)]))])),
  ]));
 }));
}
class _InsightsData{const _InsightsData(this.comparison,this.consistency,this.bonusMix,this.growth,this.dpRows);final PeriodComparison comparison;final List<UserConsistency> consistency;final Map<String,double> bonusMix;final Map<String,int> growth;final List<Map<String,Object?>> dpRows;}
class _CompareRow extends StatelessWidget{const _CompareRow({required this.label,required this.current,required this.previous,required this.change,required this.format});final String label;final double current,previous,change;final String Function(num) format;@override Widget build(BuildContext context)=>Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontWeight:FontWeight.w700)),Text('Previous: ${format(previous)}',style:Theme.of(context).textTheme.bodySmall)])),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(format(current),style:const TextStyle(fontWeight:FontWeight.w800)),Text('${change>=0?'+':''}${change.toStringAsFixed(1)}%',style:TextStyle(color:change>=0?Colors.green:Colors.red,fontWeight:FontWeight.w700))])]);}
