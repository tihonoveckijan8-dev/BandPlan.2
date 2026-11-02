import 'group_event.dart';

class EventOccurrence {
  const EventOccurrence({required this.event,required this.date});
  final GroupEvent event;
  final String date;
}

/// Expands legacy recurrence values; repeatUntil is inclusive and except stores ISO dates.
List<EventOccurrence> expandEventOccurrences(List<GroupEvent> events,DateTime from,DateTime to) {
  final start=DateTime(from.year,from.month,from.day),end=DateTime(to.year,to.month,to.day);
  final result=<EventOccurrence>[];
  for(final event in events){
    if(event.status=='cancelled')continue;
    final parsed=DateTime.tryParse(event.date);if(parsed==null)continue;
    final first=DateTime(parsed.year,parsed.month,parsed.day);
    final repeating=event.repeat.isNotEmpty&&event.repeat!='none';
    if(!repeating){if(!first.isBefore(start)&&!first.isAfter(end))result.add(EventOccurrence(event:event,date:_key(first)));continue;}
    final until=event.repeatUntil.isEmpty?end:DateTime.tryParse(event.repeatUntil);
    if(until==null)continue;
    final stop=until.isBefore(end)?until:end;var current=first;var guard=0;
    while(!current.isAfter(stop)&&guard++<500){
      final key=_key(current);
      if(!current.isBefore(start)&&!event.except.contains(key))result.add(EventOccurrence(event:event,date:key));
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
String _key(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
