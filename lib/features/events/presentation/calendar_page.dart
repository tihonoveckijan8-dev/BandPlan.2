import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../groups/application/group_providers.dart';
import '../../setlists/application/setlist_providers.dart';
import '../../setlists/domain/setlist.dart';
import '../application/event_providers.dart';
import '../domain/group_event.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events=ref.watch(groupEventsProvider);
    final setlists=ref.watch(groupSetlistsProvider);
    final programs=setlists.asData?.value??const <Setlist>[];
    return Scaffold(
      appBar:AppBar(title:const Text('Календарь'),actions:[
        IconButton(tooltip:'Сет-листы',onPressed:()=>context.push('/setlists'),icon:const Icon(Icons.queue_music_rounded))]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>_edit(context,ref,programs),
        icon:const Icon(Icons.add_rounded),label:const Text('Событие')),
      body:SafeArea(child:events.when(
        loading:()=>const Center(child:CircularProgressIndicator()),
        error:(e,_)=>_Error(message:e.toString(),retry:()=>ref.invalidate(groupEventsProvider)),
        data:(values){
          final items=[...values]..sort((a,b){final d=a.date.compareTo(b.date);return d==0?a.time.compareTo(b.time):d;});
          if(items.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
            Icon(Icons.calendar_month_rounded,size:48),SizedBox(height:12),
            Text('Пока нет событий',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700)),SizedBox(height:6),
            Text('Добавьте репетицию, выступление или служение.',textAlign:TextAlign.center)])));
          final map={for(final s in programs)s.id:s};
          return ListView.separated(padding:const EdgeInsets.fromLTRB(16,12,16,100),itemCount:items.length,
            separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(context,i){
              final e=items[i];final sl=map[e.setlistId];
              return Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
                leading:CircleAvatar(backgroundColor:Theme.of(context).colorScheme.primaryContainer,child:Icon(_icon(e.type))),
                title:Text(e.title,style:const TextStyle(fontWeight:FontWeight.w700)),
                subtitle:Text([_date(e.date),if(e.time.isNotEmpty)e.time+(e.end.isNotEmpty?'–'+e.end:''),if(e.location.isNotEmpty)e.location,
                  if(sl!=null)'Сет-лист: '+sl.name,if(e.status=='done')'Проведено',if(e.status=='cancelled')'Отменено'].join(' · '),
                  maxLines:3,overflow:TextOverflow.ellipsis),
                trailing:const Icon(Icons.chevron_right_rounded),
                onTap:()=>_details(context,ref,e,sl,programs)));
            });
        })),
    );
  }

  Future<void> _details(BuildContext context,WidgetRef ref,GroupEvent e,Setlist? sl,List<Setlist> programs) async {
    await showModalBottomSheet<void>(context:context,useSafeArea:true,showDragHandle:true,
      builder:(sheet)=>Padding(padding:const EdgeInsets.all(20),child:Wrap(runSpacing:12,children:[
        Text(e.title,style:Theme.of(context).textTheme.headlineSmall),
        Text([_date(e.date),if(e.time.isNotEmpty)e.time+(e.end.isNotEmpty?'–'+e.end:''),if(e.location.isNotEmpty)e.location].join(' · ')),
        if(e.notes.isNotEmpty)Text(e.notes),
        if(sl!=null)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.queue_music_rounded),title:Text(sl.name),
          subtitle:Text('\${sl.items.length} песен'),onTap:(){Navigator.pop(sheet);context.push('/setlists');}),
        Row(children:[if(sl==null)TextButton.icon(onPressed:(){Navigator.pop(sheet);context.push('/setlists');},
          icon:const Icon(Icons.queue_music_rounded),label:const Text('Сет-листы')),const Spacer(),
          TextButton(onPressed:()=>Navigator.pop(sheet),child:const Text('Закрыть')),
          FilledButton.icon(onPressed:(){Navigator.pop(sheet);_edit(context,ref,programs,e);},
            icon:const Icon(Icons.edit_rounded),label:const Text('Изменить'))])
      ])));
  }

  Future<void> _edit(BuildContext context,WidgetRef ref,List<Setlist> programs,[GroupEvent? old]) async {
    final group=await ref.read(activeGroupProvider.future);if(group==null||!context.mounted)return;
    final repo=ref.read(eventRepositoryProvider);if(repo==null)return;
    final title=TextEditingController(text:old?.title??'');
    final date=TextEditingController(text:old?.date??_iso(DateTime.now()));
    final time=TextEditingController(text:old?.time??'19:00');
    final end=TextEditingController(text:old?.end??'');
    final place=TextEditingController(text:old?.location??'');
    final notes=TextEditingController(text:old?.notes??'');
    final until=TextEditingController(text:old?.repeatUntil??'');
    final key=GlobalKey<FormState>();
    var type=old?.type.isNotEmpty==true?old!.type:'rehearsal';
    var status=old?.status.isNotEmpty==true?old!.status:'upcoming';
    var repeat=old?.repeat.isNotEmpty==true?old!.repeat:'none';
    var setlist=old?.setlistId??'';var saving=false;
    try{
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,
        builder:(sheet)=>StatefulBuilder(builder:(context,setState)=>SizedBox(height:MediaQuery.of(context).size.height*.9,
          child:Padding(padding:EdgeInsets.fromLTRB(18,8,18,MediaQuery.of(context).viewInsets.bottom+16),
            child:Form(key:key,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text(old==null?'Новое событие':'Изменить событие',style:Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height:12),Expanded(child:ListView(children:[
                TextFormField(controller:title,maxLength:80,decoration:const InputDecoration(labelText:'Название *',border:OutlineInputBorder()),
                  validator:(v)=>(v?.trim().isEmpty??true)?'Введите название':null),
                const SizedBox(height:8),
                DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Тип',border:OutlineInputBorder()),
                  items:const [DropdownMenuItem(value:'rehearsal',child:Text('Репетиция')),DropdownMenuItem(value:'gig',child:Text('Выступление')),
                    DropdownMenuItem(value:'service',child:Text('Служение')),DropdownMenuItem(value:'other',child:Text('Другое'))],
                  onChanged:(v)=>setState(()=>type=v??'other')),
                const SizedBox(height:8),
                TextFormField(controller:date,readOnly:true,decoration:const InputDecoration(labelText:'Дата',border:OutlineInputBorder(),suffixIcon:Icon(Icons.calendar_month)),
                  onTap:()async{final d=DateTime.tryParse(date.text)??DateTime.now();final p=await showDatePicker(context:context,initialDate:d,firstDate:DateTime(2000),lastDate:DateTime(2100));if(p!=null)date.text=_iso(p);},
                  validator:(v)=>DateTime.tryParse(v??'')==null?'Выберите дату':null),
                const SizedBox(height:8),Row(children:[
                  Expanded(child:TextFormField(controller:time,decoration:const InputDecoration(labelText:'Начало',hintText:'19:00',border:OutlineInputBorder()))),
                  const SizedBox(width:8),Expanded(child:TextFormField(controller:end,decoration:const InputDecoration(labelText:'Окончание',hintText:'21:00',border:OutlineInputBorder())))]),
                const SizedBox(height:8),TextFormField(controller:place,maxLength:120,decoration:const InputDecoration(labelText:'Место',border:OutlineInputBorder())),
                const SizedBox(height:8),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Статус',border:OutlineInputBorder()),
                  items:const [DropdownMenuItem(value:'upcoming',child:Text('Запланировано')),DropdownMenuItem(value:'done',child:Text('Проведено')),
                    DropdownMenuItem(value:'cancelled',child:Text('Отменено'))],onChanged:(v)=>setState(()=>status=v??'upcoming')),
                const SizedBox(height:8),DropdownButtonFormField<String>(value:repeat,decoration:const InputDecoration(labelText:'Повторение',border:OutlineInputBorder()),
                  items:const [DropdownMenuItem(value:'none',child:Text('Не повторять')),DropdownMenuItem(value:'daily',child:Text('Каждый день')),
                    DropdownMenuItem(value:'weekly',child:Text('Каждую неделю')),DropdownMenuItem(value:'monthly',child:Text('Каждый месяц'))],
                  onChanged:(v)=>setState(()=>repeat=v??'none')),
                if(repeat!='none')...[
                  const SizedBox(height:8),TextFormField(controller:until,readOnly:true,decoration:const InputDecoration(labelText:'Повторять до',border:OutlineInputBorder()),
                    onTap:()async{final d=DateTime.tryParse(until.text)??DateTime.tryParse(date.text)??DateTime.now();final p=await showDatePicker(context:context,initialDate:d,firstDate:DateTime(2000),lastDate:DateTime(2100));if(p!=null)until.text=_iso(p);})],
                const SizedBox(height:8),DropdownButtonFormField<String>(value:setlist,
                  decoration:const InputDecoration(labelText:'Связанный сет-лист',border:OutlineInputBorder()),
                  items:[const DropdownMenuItem(value:'',child:Text('Без сет-листа')),
                    if(setlist.isNotEmpty&&!programs.any((s)=>s.id==setlist))DropdownMenuItem(value:setlist,enabled:false,child:const Text('Сет-лист недоступен')),
                    ...programs.map((s)=>DropdownMenuItem(value:s.id,child:Text(s.name,overflow:TextOverflow.ellipsis)))],
                  onChanged:(v)=>setState(()=>setlist=v??'')),
                const SizedBox(height:8),TextFormField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Заметки',border:OutlineInputBorder())),
              ])),
              const SizedBox(height:12),FilledButton.icon(onPressed:saving?null:()async{
                if(!(key.currentState?.validate()??false))return;
                if(repeat!='none'&&until.text.isNotEmpty&&until.text.compareTo(date.text)<0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Дата окончания повтора раньше начала.')));return;}
                setState(()=>saving=true);
                try{
                  final event=old==null?GroupEvent.create(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),
                    date:date.text,type:type,time:time.text.trim(),end:end.text.trim(),location:place.text.trim(),notes:notes.text.trim(),
                    status:status,repeat:repeat,repeatUntil:until.text.trim(),setlistId:setlist):
                    old.withEdits(title:title.text.trim(),date:date.text,type:type,time:time.text.trim(),end:end.text.trim(),
                      location:place.text.trim(),notes:notes.text.trim(),status:status,repeat:repeat,repeatUntil:until.text.trim(),setlistId:setlist);
                  await repo.saveGroupEvent(group.id,event);ref.invalidate(groupEventsProvider);if(sheet.mounted)Navigator.pop(sheet);
                }catch(error){setState(()=>saving=false);if(sheet.mounted)ScaffoldMessenger.of(sheet).showSnackBar(SnackBar(content:Text('Не удалось сохранить: $error')));}
              },icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_rounded),
                label:Text(saving?'Сохранение…':'Сохранить событие')),
            ]))))));
    }finally{title.dispose();date.dispose();time.dispose();end.dispose();place.dispose();notes.dispose();until.dispose();}
  }

  static IconData _icon(String type)=>switch(type){'rehearsal'=>Icons.music_note_rounded,'service'=>Icons.church_outlined,'gig'=>Icons.mic_external_on_rounded,_=>Icons.event_rounded};
  static String _iso(DateTime d)=>'\${d.year.toString().padLeft(4,'0')}-\${d.month.toString().padLeft(2,'0')}-\${d.day.toString().padLeft(2,'0')}';
  static String _date(String value){final d=DateTime.tryParse(value);if(d==null)return value;const m=['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];return '\${d.day} \${m[d.month-1]} \${d.year}';}
}
class _Error extends StatelessWidget{
  const _Error({required this.message,required this.retry});final String message;final VoidCallback retry;
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.cloud_off_rounded,size:40),const SizedBox(height:12),Text(message,textAlign:TextAlign.center),
    const SizedBox(height:16),OutlinedButton(onPressed:retry,child:const Text('Повторить'))])));
}