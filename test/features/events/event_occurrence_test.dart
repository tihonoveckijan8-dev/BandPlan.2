import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/events/domain/group_event.dart';
import 'package:bandplan/features/events/domain/event_occurrence.dart';
void main(){
  GroupEvent make({String repeat='weekly',String until='2026-11-30',List<String> except=const []})=>
    GroupEvent.fromJson({'id':'e1','title':'Rehearsal','date':'2026-11-02','repeat':repeat,'repeatUntil':until,'except':except});
  test('weekly expansion includes repeatUntil and skips except dates',(){
    final r=expandEventOccurrences([make(except:['2026-11-09'])],DateTime(2026,11,1),DateTime(2026,11,30));
    expect(r.map((x)=>x.date),['2026-11-02','2026-11-16','2026-11-23','2026-11-30']);
  });
  test('daily and biweekly legacy values expand correctly',(){
    expect(expandEventOccurrences([make(repeat:'daily',until:'2026-11-04')],DateTime(2026,11,1),DateTime(2026,11,5)).map((x)=>x.date),
      ['2026-11-02','2026-11-03','2026-11-04']);
    expect(expandEventOccurrences([make(repeat:'biweekly')],DateTime(2026,11,1),DateTime(2026,11,30)).map((x)=>x.date),
      ['2026-11-02','2026-11-16','2026-11-30']);
  });
  test('monthly recurrence preserves legacy Date.setMonth overflow behavior',(){
    final e=GroupEvent.fromJson({
      'id':'month-end','title':'Month end','date':'2027-01-31',
      'repeat':'monthly','repeatUntil':'2027-04-30',
    });
    // WHY: the original BandPlan calendar advanced monthly events with JS setMonth().
    // Keep the same overflow dates when migrating legacy event records.
    expect(expandEventOccurrences([e],DateTime(2027,1,1),DateTime(2027,4,30)).map((x)=>x.date),
      ['2027-01-31','2027-03-03','2027-04-03']);
  });
  test('cancelled series are hidden',(){
    final e=GroupEvent.fromJson({...make().raw,'status':'cancelled'});
    expect(expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,30)),isEmpty);
  });
}
