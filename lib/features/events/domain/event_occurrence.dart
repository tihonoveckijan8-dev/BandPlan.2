import 'group_event.dart';

class EventOccurrence {
  const EventOccurrence({required this.event,required this.series,required this.date});
  /// Effective values for this particular date, including any one-off overrides.
  final GroupEvent event;
  /// Original recurring event record; recurrence metadata and overrides live here.
  final GroupEvent series;
  final String date;
}

/// Expands legacy recurrence values; repeatUntil is inclusive and except stores ISO dates.
/// The optional overrides map is keyed by the original occurrence date and stores only
/// occurrence-specific editable fields, leaving the recurrence anchor untouched.
List<EventOccurrence> expandEventOccurrences(List<GroupEvent> events,DateTime from,DateTime to) {
  final start=DateTime(from.year,from.month,from.day),end=DateTime(to.year,to.month,to.day);
  final result=<EventOccurrence>[];
  for(final event in events){
    if(event.status=='cancelled')continue;
    final parsed=DateTime.tryParse(event.date);if(parsed==null)continue;
    final first=DateTime(parsed.year,parsed.month,parsed.day);
    final repeating=event.repeat.isNotEmpty&&event.repeat!='none';
    if(!repeating){_addOccurrence(result,event,_key(first),start,end);continue;}
    final until=event.repeatUntil.isEmpty?end:DateTime.tryParse(event.repeatUntil);
    if(until==null)continue;
    final stop=until.isBefore(end)?until:end;
    var current=first;
    // WHY: older daily/weekly series must fast-forward to the visible range;
    // otherwise the 500-step safety guard can hide every recent occurrence.
    if(current.isBefore(start)){
      final interval=switch(event.repeat){'daily'=>1,'weekly'=>7,'biweekly'=>14,_=>0};
      if(interval>0){
        final elapsed=start.difference(current).inDays;
        final steps=(elapsed+interval-1)~/interval;
        current=current.add(Duration(days:steps*interval));
      }else if(event.repeat=='monthly'){
        // WHY: legacy JS setMonth() can overflow in a later February or a
        // 30-day month, permanently changing the day. Simulate up to 13
        // monthly steps to reach that stable day before arithmetic fast-forwarding.
        if(current.day>28){
          final originalDay=current.day;
          for(var i=0;i<13&&current.day==originalDay&&current.isBefore(start);i++){
            // WHY: do not jump past the requested range while searching for the
            // eventual overflow day; those earlier monthly occurrences are visible.
            current=DateTime(current.year,current.month+1,current.day);
          }
        }
        if(current.isBefore(start)){
          final months=(start.year-current.year)*12+start.month-current.month;
          if(months>0)current=DateTime(current.year,current.month+months,current.day);
          if(current.isBefore(start))current=DateTime(current.year,current.month+1,current.day);
        }
      }
    }
    var guard=0;
    while(!current.isAfter(stop)&&guard++<500){
      _addOccurrence(result,event,_key(current),start,end);
      switch(event.repeat){
        case 'daily':current=current.add(const Duration(days:1));break;
        case 'weekly':current=current.add(const Duration(days:7));break;
        case 'biweekly':current=current.add(const Duration(days:14));break;
        case 'monthly':current=DateTime(current.year,current.month+1,current.day);break;
        default:guard=500;break;
      }
    }
  }
  result.sort((a,b){final d=a.date.compareTo(b.date);return d==0?a.event.time.compareTo(b.event.time):d;});
  return result;
}

void _addOccurrence(List<EventOccurrence> result,GroupEvent series,String date,DateTime start,DateTime end){
  final day=DateTime.parse(date);
  if(day.isBefore(start)||day.isAfter(end)||series.except.contains(date))return;
  final all=series.raw['overrides'];
  final overrides=all is Map?all[date]:null;
  final effective=overrides is Map
      ?GroupEvent.fromJson({...series.raw,...Map<String,dynamic>.from(overrides),'id':series.id,'date':date,
        'repeat':series.repeat,'repeatUntil':series.repeatUntil,'except':series.except})
      :GroupEvent.fromJson({...series.raw,'date':date});
  if(effective.status=='cancelled')return;
  result.add(EventOccurrence(event:effective,series:series,date:date));
}

String _key(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
