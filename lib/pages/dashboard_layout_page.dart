import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardLayoutPage extends StatefulWidget {
  const DashboardLayoutPage({super.key});
  @override State<DashboardLayoutPage> createState()=>_DashboardLayoutPageState();
}
class _DashboardLayoutPageState extends State<DashboardLayoutPage>{
  static const labels=<String,String>{'metrics':'Overview cards','sales':'Sales chart','activity':'Recent activity','quick':'Quick entry buttons'};
  static const descriptions=<String,String>{'metrics':'Today totals, follow-ups, active users and issues','sales':'Weekly, monthly and yearly DP trends','activity':'Latest user and quiz events','quick':'Record DP and add bonus shortcuts'};
  List<String> order=['metrics','sales','activity','quick'];Set<String> hidden={};Set<String> pinned={};bool loading=true,saving=false;
  @override void initState(){super.initState();load();}
  Future<void> load()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){
    order=p.getStringList('user_hub_dashboard_order')??order;
    hidden=p.getStringList('user_hub_dashboard_hidden')?.toSet()??{};
    pinned=p.getStringList('user_hub_dashboard_pinned')?.toSet()??{};
    for(final id in labels.keys){if(!order.contains(id))order.add(id);}
    loading=false;
  });}
  Future<void> save()async{setState(()=>saving=true);final p=await SharedPreferences.getInstance();
    await p.setStringList('user_hub_dashboard_order',order);
    await p.setStringList('user_hub_dashboard_hidden',hidden.toList());
    await p.setStringList('user_hub_dashboard_pinned',pinned.toList());
    if(!mounted)return;setState(()=>saving=false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Dashboard layout saved. Return to Dashboard to see the changes.')));
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Customize Dashboard'),actions:[TextButton(onPressed:loading||saving?null:save,child:Text(saving?'Saving…':'Save'))]),
    body:loading?const Center(child:CircularProgressIndicator()):Column(children:[
      const Padding(padding:EdgeInsets.fromLTRB(18,12,18,8),child:Text('Drag to reorder sections. Hide sections you do not need, or pin important sections to the top.',style:TextStyle(color:Colors.black54))),
      Expanded(child:ReorderableListView.builder(
        padding:const EdgeInsets.fromLTRB(14,8,14,20),
        itemCount:order.length,
        onReorder:(oldIndex,newIndex){setState((){
          if(newIndex>oldIndex)newIndex--;
          final item=order.removeAt(oldIndex);order.insert(newIndex,item);
        });},
        itemBuilder:(context,index){
          final id=order[index];
          return Card(key:ValueKey(id),margin:const EdgeInsets.only(bottom:8),child:ListTile(
            leading:const Icon(Icons.drag_handle_rounded),
            title:Text(labels[id]??id,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(descriptions[id]??''),
            trailing:Wrap(spacing:0,crossAxisAlignment:WrapCrossAlignment.center,children:[
              IconButton(tooltip:pinned.contains(id)?'Unpin section':'Pin to top',onPressed:()=>setState(()=>pinned.contains(id)?pinned.remove(id):pinned.add(id)),icon:Icon(pinned.contains(id)?Icons.push_pin:Icons.push_pin_outlined,color:pinned.contains(id)?Theme.of(context).colorScheme.primary:null)),
              Switch(value:!hidden.contains(id),onChanged:(visible)=>setState(()=>visible?hidden.remove(id):hidden.add(id))),
            ]),
          ));
        },
      )),
      SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(16),child:FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save_outlined),label:const Text('Save dashboard layout')))),
    ]),
  );
}
