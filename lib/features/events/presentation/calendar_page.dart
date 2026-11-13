import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../groups/application/group_providers.dart';
import '../../setlists/application/setlist_providers.dart';
import '../../setlists/domain/setlist.dart';
import '../application/event_providers.dart';
import '../domain/group_event.dart';
import '../domain/event_occurrence.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime visibleMonth;
  late String selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    visibleMonth = DateTime(now.year, now.month);
    selectedDate = _iso(now);
  }

  @override
  Widget build(BuildContext context) {
    final events=ref.watch(groupEventsProvider);
    final setlists=ref.watch(groupSetlistsProvider);
    final programs=setlists.asData?.value??const <Setlist>[];
    return Scaffold(
      appBar:AppBar(title:const Text('Календарь'),actions:[
        IconButton(tooltip:'Сет-листы',onPressed:()=>context.push('/setlists'),icon:const Icon(Icons.queue_music_rounded))]),
      floatingActionButton:FloatingActionButton.extended(onPressed:()=>_edit(context,ref,programs,initialDate:selectedDate),
        icon:const Icon(Icons.add_rounded),label:const Text('Событие')),
      body:SafeArea(child:events.when(
        loading:()=>const Center(child:CircularProgressIndicator()),
        error:(e,_)=>_Error(message:e.toString(),retry:()=>ref.invalidate(groupEventsProvider)),
        data:(values){
          final items=expandEventOccurrences(values, DateTime(visibleMonth.year,visibleMonth.month,1), DateTime(visibleMonth.year,visibleMonth.month+1,0));
          final map={for(final s in programs)s.id:s};
          final selectedItems=items.where((o)=>o.date==selectedDate).toList();
          final calendarPanel = _monthCalendar(context,visibleMonth,selectedDate,items,
            (month)=>setState((){visibleMonth=month;selectedDate=_iso(month);}),
            (day)=>setState((){
              // WHY: the Today shortcut must bring the visible month along with the selected date.
              visibleMonth=DateTime(day.year,day.month);selectedDate=_iso(day);
            }));
          final selectedDayPanel = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding:const EdgeInsets.fromLTRB(4,18,4,10),child:Text(
                _date(selectedDate),style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800))),
              if(selectedItems.isEmpty)
                // WHY: The calendar is the app's landing screen, so its first viewport
                // should communicate group activity and offer a clear next action.
                Card(
                  color: Theme.of(context).colorScheme.primary,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.graphic_eq_rounded, color: Theme.of(context).colorScheme.onPrimary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'BANDPLAN  /  MUSIC GROUP OS',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Перейти к сегодняшней дате',
                              onPressed: () => setState(() {
                                final today = DateTime.now();
                                visibleMonth = DateTime(today.year, today.month);
                                selectedDate = _iso(today);
                              }),
                              color: Theme.of(context).colorScheme.onPrimary,
                              icon: const Icon(Icons.today_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Музыка начинается\\nс общего плана.',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Репетиции, выступления и планы группы — в одном месте.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.82),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DashboardMetric(value: '${items.length}', label: 'событий'),
                            _DashboardMetric(value: '${programs.length}', label: 'сет-листов'),
                            _DashboardMetric(value: '${selectedItems.length}', label: 'на выбранный день'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () => _edit(context, ref, programs, initialDate: selectedDate),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Добавить событие'),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: () => context.push('/songs'),
                              icon: const Icon(Icons.library_music_rounded),
                              label: const Text('Открыть песни'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height:8),
                if(isWide)
                  Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Expanded(flex:11,child:calendarPanel),
                    const SizedBox(width:20),
                    Expanded(flex:9,child:selectedDayPanel),
                  ])
                else ...[
                  calendarPanel,
                  selectedDayPanel,
                ],
              ]),
            ));
          });
        })),
    );
  }

  Widget _monthCalendar(BuildContext context,DateTime month,String selectedDate,List<EventOccurrence> events,
      ValueChanged<DateTime> onMonthChanged,ValueChanged<DateTime> onDaySelected) {
    const monthNames=['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    const weekdays=['Пн','Вт','Ср','Чт','Пт','Сб','Вс'];
    final first=DateTime(month.year,month.month,1);
    final offset=first.weekday-1;
    final days=DateTime(month.year,month.month+1,0).day;
    final cells=((offset+days+6)~/7)*7;
    final counts=<String,int>{};
    for(final occurrence in events){counts.update(occurrence.date,(v)=>v+1,ifAbsent:()=>1);}
    final scheme=Theme.of(context).colorScheme;
    return Card(child:Padding(padding:const EdgeInsets.fromLTRB(12,10,12,12),child:Column(children:[
      Row(children:[
        IconButton(tooltip:'Предыдущий месяц',onPressed:()=>onMonthChanged(DateTime(month.year,month.month-1,1)),icon:const Icon(Icons.chevron_left_rounded)),
        Expanded(child:Center(child:Text('${monthNames[month.month-1][0].toUpperCase()}${monthNames[month.month-1].substring(1)} ${month.year}',
          style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)))),
        IconButton(tooltip:'Следующий месяц',onPressed:()=>onMonthChanged(DateTime(month.year,month.month+1,1)),icon:const Icon(Icons.chevron_right_rounded)),
      ]),
      Row(children:weekdays.map((day)=>Expanded(child:Center(child:Padding(padding:const EdgeInsets.symmetric(vertical:8),
        child:Text(day,style:Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight:FontWeight.w700,
          color:day=='Сб'||day=='Вс'?scheme.primary:scheme.onSurfaceVariant)))))).toList()),
      LayoutBuilder(builder: (context, constraints) {
        // WHY: Wide desktop calendars should read as a compact month overview,
        // not expand each date cell into a tall card that wastes vertical space.
        final cellAspectRatio = constraints.maxWidth >= 640 ? 1.9 : 1.12;
        return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:cells,
        gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,childAspectRatio:cellAspectRatio),
        itemBuilder:(context,index){
          final dayNumber=index-offset+1;
          if(dayNumber<1||dayNumber>days)return const SizedBox.shrink();
          final day=DateTime(month.year,month.month,dayNumber);
          final key=_iso(day);final isSelected=key==selectedDate;final count=counts[key]??0;
          final isToday=key==_iso(DateTime.now());
          return Padding(padding:const EdgeInsets.all(2),child:Material(
            color:isSelected?scheme.primary:Colors.transparent,borderRadius:BorderRadius.circular(12),
            child:InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>onDaySelected(day),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Text('$dayNumber',style:TextStyle(fontWeight:isSelected||isToday?FontWeight.w800:FontWeight.w500,
                  color:isSelected?scheme.onPrimary:isToday?scheme.primary:scheme.onSurface)),
                const SizedBox(height:3),
                if(count>0)Container(width:5,height:5,decoration:BoxDecoration(
                  color:isSelected?scheme.onPrimary:scheme.primary,shape:BoxShape.circle)),
              ])),
          ));
        });
      }),
      const SizedBox(height:4),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(
        onPressed:()=>onDaySelected(DateTime.now()),icon:const Icon(Icons.today_rounded,size:18),label:const Text('Сегодня'))),
    ])));
  }

  Future<void> _details(BuildContext context,WidgetRef ref,GroupEvent e,Setlist? sl,List<Setlist> programs,{required String occurrenceDate,required GroupEvent seriesEvent}) async {
    await showModalBottomSheet<void>(context:context,useSafeArea:true,showDragHandle:true,
      builder:(sheet)=>Padding(padding:const EdgeInsets.all(20),child:Wrap(runSpacing:12,children:[
        Text(e.title,style:Theme.of(context).textTheme.headlineSmall),
        Text([_date(occurrenceDate),if(e.time.isNotEmpty)e.time+(e.end.isNotEmpty?'–'+e.end:''),if(e.location.isNotEmpty)e.location].join(' · ')),
        if(e.notes.isNotEmpty)Text(e.notes),
        if(sl!=null)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.queue_music_rounded),title:Text(sl.name),
          subtitle:Text('${sl.items.length} песен'),onTap:(){Navigator.pop(sheet);context.push('/setlists');}),
        Row(children:[
          IconButton(tooltip:'Удалить событие',color:Theme.of(context).colorScheme.error,
            onPressed:()=>_deleteEvent(context,sheet,ref,seriesEvent,occurrenceDate),icon:const Icon(Icons.delete_outline_rounded)),
          if(sl==null)TextButton.icon(onPressed:(){Navigator.pop(sheet);context.push('/setlists');},
            icon:const Icon(Icons.queue_music_rounded),label:const Text('Сет-листы')),
          const Spacer(),
          TextButton(onPressed:()=>Navigator.pop(sheet),child:const Text('Закрыть')),
          FilledButton.icon(onPressed:()async{
            final recurring=seriesEvent.repeat.isNotEmpty&&seriesEvent.repeat!='none';
            var editOne=false;
            if(recurring){
              final action=await showDialog<String>(context:context,builder:(dialog)=>AlertDialog(
                title:const Text('Что изменить?'),
                content:Text('«${e.title}» — ${_date(occurrenceDate)}. Можно изменить только эту дату или всю серию.'),
                actions:[
                  TextButton(onPressed:()=>Navigator.pop(dialog,'cancel'),child:const Text('Отмена')),
                  TextButton(onPressed:()=>Navigator.pop(dialog,'one'),child:const Text('Только это повторение')),
                  FilledButton(onPressed:()=>Navigator.pop(dialog,'all'),child:const Text('Всю серию')),
                ],
              ));
              if(action==null||action=='cancel'||!context.mounted)return;
              editOne=action=='one';
            }
            if(sheet.mounted)Navigator.pop(sheet);
            await _edit(context,ref,programs,old:seriesEvent,
              occurrenceDate:editOne?occurrenceDate:null,initial:editOne?e:null);
          },
            icon:const Icon(Icons.edit_rounded),label:Text(seriesEvent.repeat.isNotEmpty&&seriesEvent.repeat!='none'?'Изменить':'Изменить'))])
      ])));
  }

  Future<void> _deleteEvent(BuildContext context,BuildContext sheet,WidgetRef ref,GroupEvent event,String occurrenceDate) async {
    final recurring=event.repeat.isNotEmpty&&event.repeat!='none';
    final action=await showDialog<String>(context:context,builder:(dialog)=>AlertDialog(
      icon:Icon(Icons.delete_outline_rounded,color:Theme.of(dialog).colorScheme.error),
      title:Text(recurring?'Удалить повторение?':'Удалить событие?'),
      content:Text(recurring
        ?'Удалить «${event.title}» за ${_date(occurrenceDate)} или всю серию?'
        :'«${event.title}» будет удалено. Это действие нельзя отменить.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog,'cancel'),child:const Text('Отмена')),
        if(recurring)TextButton(onPressed:()=>Navigator.pop(dialog,'one'),child:const Text('Только это повторение')),
        FilledButton.tonal(onPressed:()=>Navigator.pop(dialog,'all'),child:Text(recurring?'Всю серию':'Удалить')),
      ],
    ));
    if(action==null||action=='cancel'||!context.mounted)return;
    var pendingSync = false;
    var failedSync = false;
    try{
      final group=await ref.read(activeGroupProvider.future);
      final repo=await ref.read(eventRepositoryProvider.future);
      if(group==null)throw StateError('Не удалось определить активную группу.');
      if(action=='one'){
        final excluded={...event.except,occurrenceDate}.toList()..sort();
        final sync=await repo.saveGroupEvent(group.id,GroupEvent.fromJson({...event.raw,'except':excluded}));
        pendingSync=sync.hasPending; failedSync=sync.hasPermanentFailure;
      }else{final sync=await repo.deleteGroupEvent(group.id,event.id); pendingSync=sync.hasPending;}
      ref.invalidate(groupEventsProvider);
      if(sheet.mounted)Navigator.pop(sheet);
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(failedSync?'Изменение сохранено локально, но сервер отклонил синхронизацию.':pendingSync?'Изменение сохранено на устройстве. Ожидает синхронизации.':action=='one'?'Повторение удалено.':'Событие удалено.')));
    }catch(error){
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Не удалось удалить событие: $error')));
    }
  }

  Future<void> _edit(BuildContext context,WidgetRef ref,List<Setlist> programs,{GroupEvent? old,String? occurrenceDate,GroupEvent? initial,String? initialDate}) async {
    final group=await ref.read(activeGroupProvider.future);if(group==null||!context.mounted)return;
    final repo=await ref.read(eventRepositoryProvider.future);
    final source=initial??old;
    final title=TextEditingController(text:source?.title??'');
    final date=TextEditingController(text:occurrenceDate??source?.date??initialDate??_iso(DateTime.now()));
    final time=TextEditingController(text:source?.time??'19:00');
    final end=TextEditingController(text:source?.end??'');
    final place=TextEditingController(text:source?.location??'');
    final notes=TextEditingController(text:source?.notes??'');
    final until=TextEditingController(text:old?.repeatUntil??'');
    final key=GlobalKey<FormState>();
    var type=source?.type.isNotEmpty==true?source!.type:'rehearsal';
    var status=source?.status.isNotEmpty==true?source!.status:'upcoming';
    var repeat=occurrenceDate!=null?'none':(old?.repeat.isNotEmpty==true?old!.repeat:'none');
    var setlist=source?.setlistId??'';var saving=false;
    try{
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,
        builder:(sheet)=>StatefulBuilder(builder:(context,setState)=>SizedBox(height:MediaQuery.of(context).size.height*.9,
          child:Padding(padding:EdgeInsets.fromLTRB(18,8,18,MediaQuery.of(context).viewInsets.bottom+16),
            child:Form(key:key,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text(old==null?'Новое событие':occurrenceDate!=null?'Изменить повторение':'Изменить событие',style:Theme.of(context).textTheme.headlineSmall),
              if(occurrenceDate!=null)const Padding(padding:EdgeInsets.only(bottom:8),child:Text('Изменения затронут только выбранную дату. Остальные повторения останутся прежними.')),
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
                  onTap:occurrenceDate!=null?null:()async{final d=DateTime.tryParse(date.text)??DateTime.now();final p=await showDatePicker(context:context,initialDate:d,firstDate:DateTime(2000),lastDate:DateTime(2100));if(p!=null)date.text=_iso(p);},
                  validator:(v)=>DateTime.tryParse(v??'')==null?'Выберите дату':null),
                const SizedBox(height:8),Row(children:[
                  Expanded(child:TextFormField(controller:time,keyboardType:TextInputType.datetime,
                    decoration:const InputDecoration(labelText:'Начало',hintText:'19:00',border:OutlineInputBorder()),
                    validator:_timeValidator)),
                  const SizedBox(width:8),Expanded(child:TextFormField(controller:end,keyboardType:TextInputType.datetime,
                    decoration:const InputDecoration(labelText:'Окончание',hintText:'21:00',border:OutlineInputBorder()),
                    validator:_timeValidator))]),
                const SizedBox(height:8),TextFormField(controller:place,maxLength:120,decoration:const InputDecoration(labelText:'Место',border:OutlineInputBorder())),
                const SizedBox(height:8),DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Статус',border:OutlineInputBorder()),
                  items:const [DropdownMenuItem(value:'upcoming',child:Text('Запланировано')),DropdownMenuItem(value:'done',child:Text('Проведено')),
                    DropdownMenuItem(value:'cancelled',child:Text('Отменено'))],onChanged:(v)=>setState(()=>status=v??'upcoming')),
                if(occurrenceDate==null)const SizedBox(height:8),
                if(occurrenceDate==null)DropdownButtonFormField<String>(value:repeat,decoration:const InputDecoration(labelText:'Повторение',border:OutlineInputBorder()),
                  items:const [DropdownMenuItem(value:'none',child:Text('Не повторять')),DropdownMenuItem(value:'daily',child:Text('Каждый день')),
                    DropdownMenuItem(value:'weekly',child:Text('Каждую неделю')),DropdownMenuItem(value:'biweekly',child:Text('Раз в две недели')),DropdownMenuItem(value:'monthly',child:Text('Каждый месяц'))],
                  onChanged:(v)=>setState(()=>repeat=v??'none')),
                if(occurrenceDate==null&&repeat!='none')...[
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
                  final edited=old==null?GroupEvent.create(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),
                    date:date.text,type:type,time:time.text.trim(),end:end.text.trim(),location:place.text.trim(),notes:notes.text.trim(),
                    status:status,repeat:repeat,repeatUntil:until.text.trim(),setlistId:setlist):
                    old.withEdits(title:title.text.trim(),date:date.text,type:type,time:time.text.trim(),end:end.text.trim(),
                      location:place.text.trim(),notes:notes.text.trim(),status:status,repeat:repeat,repeatUntil:until.text.trim(),setlistId:setlist);
                  final event=occurrenceDate==null?edited:old!.withOccurrenceOverride(occurrenceDate,{
                    'title':edited.title,'type':edited.type,'time':edited.time,'end':edited.end,
                    'location':edited.location,'notes':edited.notes,'status':edited.status,'setlistId':edited.setlistId,
                  });
                  final sync=await repo.saveGroupEvent(group.id,event);ref.invalidate(groupEventsProvider);if(sheet.mounted)Navigator.pop(sheet);
                  if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content:Text(sync.hasPermanentFailure?'Событие сохранено на устройстве, но сервер отклонил синхронизацию.':sync.hasPending?'Событие сохранено на устройстве. Ожидает синхронизации.':old==null?'Событие создано.':'Событие сохранено.')));
                }catch(error){setState(()=>saving=false);if(sheet.mounted)ScaffoldMessenger.of(sheet).showSnackBar(SnackBar(content:Text('Не удалось сохранить: $error')));}
              },icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_rounded),
                label:Text(saving?'Сохранение…':'Сохранить событие')),
            ]))))));
    }finally{title.dispose();date.dispose();time.dispose();end.dispose();place.dispose();notes.dispose();until.dispose();}
  }

  // WHY: free-form time fields otherwise accept values the calendar cannot display consistently.
  static String? _timeValidator(String? value){
    final time=value?.trim()??'';
    if(time.isEmpty)return null;
    return RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(time)
      ?null:'Введите время в формате ЧЧ:ММ';
  }

  static String _iso(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  static IconData _icon(String type)=>switch(type){'rehearsal'=>Icons.music_note_rounded,'service'=>Icons.church_outlined,'gig'=>Icons.mic_external_on_rounded,_=>Icons.event_rounded};
  static String _date(String value){final d=DateTime.tryParse(value);if(d==null)return value;const m=['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];return '${d.day} ${m[d.month-1]} ${d.year}';}
}
class _Error extends StatelessWidget{
  const _Error({required this.message,required this.retry});final String message;final VoidCallback retry;
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.cloud_off_rounded,size:40),const SizedBox(height:12),Text(message,textAlign:TextAlign.center),
    const SizedBox(height:16),OutlinedButton(onPressed:retry,child:const Text('Повторить'))])));
}


class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
