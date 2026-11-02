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
  test('old daily series fast-forwards beyond the safety guard',(){
    final e=GroupEvent.fromJson({
      'id':'old-daily','title':'Daily','date':'2024-01-01',
      'repeat':'daily','repeatUntil':'2026-12-31',
    });
    expect(expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,3)).map((x)=>x.date),
      ['2026-11-01','2026-11-02','2026-11-03']);
  });
  test('old weekly fast-forward still honors excluded dates',(){
    final e=GroupEvent.fromJson({
      'id':'old-weekly-except','title':'Weekly','date':'2024-01-01',
      'repeat':'weekly','repeatUntil':'2026-12-31','except':['2026-11-02'],
    });
    expect(expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,15)).map((x)=>x.date),
      ['2026-11-09']);
  });
  test('recurring series ending before visible range produces no occurrences',(){
    final e=GroupEvent.fromJson({
      'id':'ended-series','title':'Ended','date':'2024-01-01',
      'repeat':'weekly','repeatUntil':'2024-12-31',
    });
    expect(expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,30)),isEmpty);
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
  test('old weekly and biweekly series fast-forward without changing cadence',(){
    final weekly=GroupEvent.fromJson({
      'id':'old-weekly','title':'Weekly','date':'2024-01-01',
      'repeat':'weekly','repeatUntil':'2026-12-31',
    });
    final biweekly=GroupEvent.fromJson({
      'id':'old-biweekly','title':'Biweekly','date':'2024-01-01',
      'repeat':'biweekly','repeatUntil':'2026-12-31',
    });
    expect(expandEventOccurrences([weekly],DateTime(2026,11,1),DateTime(2026,11,15)).map((x)=>x.date),
      ['2026-11-02','2026-11-09']);
    expect(expandEventOccurrences([biweekly],DateTime(2026,11,1),DateTime(2026,11,15)).map((x)=>x.date),
      ['2026-11-02','2026-11-16'].where((d)=>d.compareTo('2026-11-15')<=0));
  });
  test('old monthly series fast-forwards while preserving legacy overflow phase',(){
    final e=GroupEvent.fromJson({
      'id':'old-monthly','title':'Monthly','date':'2024-01-31',
      'repeat':'monthly','repeatUntil':'2026-12-31',
    });
    expect(expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,30)).map((x)=>x.date),
      ['2026-11-02']);
  });
  test('monthly fast-forward keeps occurrences inside the stabilization window',(){
    final e=GroupEvent.fromJson({
      'id':'monthly-near-anchor','title':'Monthly','date':'2024-01-29',
      'repeat':'monthly','repeatUntil':'2025-12-31',
    });
    // The first requested date is before the day-29 series overflows in Feb 2025.
    // Earlier occurrences must not be skipped while finding the later stable day.
    expect(expandEventOccurrences([e],DateTime(2024,2,1),DateTime(2024,4,30)).map((x)=>x.date),
      ['2024-02-29','2024-03-29','2024-04-29']);
  });

  test('old monthly series fast-forwards after a later February overflow',(){
    final e=GroupEvent.fromJson({
      'id':'old-monthly-29','title':'Monthly 29','date':'2024-01-29',
      'repeat':'monthly','repeatUntil':'2026-12-31',
    });
    // Jan 2024 -> Feb 29 is valid; Feb 2025 then overflows to Mar 1.
    // All later monthly dates therefore stay on day 1.
    expect(expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,30)).map((x)=>x.date),
      ['2026-11-01']);
  });
  test('one-off overrides affect only their occurrence and preserve the series',(){
    final base=GroupEvent.fromJson({
      'id':'e1','title':'Original','date':'2026-11-02','repeat':'weekly','repeatUntil':'2026-11-16',
      'overrides':{'2026-11-09':{'title':'Changed date','time':'20:00','notes':'special'}},
      'legacyField':'keep',
    });
    final r=expandEventOccurrences([base],DateTime(2026,11,1),DateTime(2026,11,30));
    expect(r.map((x)=>x.event.title),['Original','Changed date','Original']);
    expect(r[1].event.time,'20:00');
    expect(r[1].event.date,'2026-11-09');
    expect(r[1].series.title,'Original');
    expect(r[1].series.raw['legacyField'],'keep');
  });
  test('editing one occurrence preserves unknown override metadata',(){
    final base=GroupEvent.fromJson({
      'id':'e1','title':'Original','date':'2026-11-02','repeat':'weekly',
      'repeatUntil':'2026-11-16',
      'overrides':{
        '2026-11-09':{'title':'Old title','legacyFlag':'preserve','customPayload':{'x':1}},
        '2026-11-16':{'title':'Other occurrence'},
      },
      'legacyEventField':'also preserve',
    });
    final edited=base.withOccurrenceOverride('2026-11-09',{'title':'New title','time':'20:00'});
    final overrides=edited.raw['overrides'] as Map;
    final changed=overrides['2026-11-09'] as Map;
    expect(changed['title'],'New title');
    expect(changed['time'],'20:00');
    expect(changed['legacyFlag'],'preserve');
    expect(changed['customPayload'],{'x':1});
    expect(overrides['2026-11-16'],{'title':'Other occurrence'});
    expect(edited.raw['legacyEventField'],'also preserve');
    expect(base.raw['overrides'],isNot(equals(overrides)));
  });
  test('excluded occurrence cannot be revived by an override',(){
    final e=GroupEvent.fromJson({
      'id':'excluded','title':'Series','date':'2026-11-02',
      'repeat':'weekly','repeatUntil':'2026-11-16',
      'except':['2026-11-09'],
      'overrides':{'2026-11-09':{'title':'Should stay excluded','status':'upcoming'}},
    });
    expect(expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,30)).map((x)=>x.date),
      ['2026-11-02','2026-11-16']);
  });
  test('one-off override cannot move the date or rewrite series recurrence metadata',(){
    final e=GroupEvent.fromJson({
      'id':'protected-series','title':'Series','date':'2026-11-02',
      'repeat':'weekly','repeatUntil':'2026-11-16',
      'overrides':{
        '2026-11-09':{
          'date':'2026-11-10','repeat':'daily','repeatUntil':'2099-01-01',
          'except':['2026-11-16'],'title':'Edited occurrence',
        },
      },
    });
    final r=expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,30));
    expect(r.map((x)=>x.date),['2026-11-02','2026-11-09','2026-11-16']);
    expect(r[1].event.date,'2026-11-09');
    expect(r[1].event.repeat,'weekly');
    expect(r[1].event.repeatUntil,'2026-11-16');
    expect(r[1].event.except,isEmpty);
  });

  test('cancelled one-off override hides only its date',(){
    final base=GroupEvent.fromJson({
      'id':'e1','title':'Original','date':'2026-11-02','repeat':'weekly','repeatUntil':'2026-11-16',
      'overrides':{'2026-11-09':{'status':'cancelled'}},
    });
    expect(expandEventOccurrences([base],DateTime(2026,11,1),DateTime(2026,11,30)).map((x)=>x.date),
      ['2026-11-02','2026-11-16']);
  });
  test('cancelled series are hidden',(){
    final e=GroupEvent.fromJson({...make().raw,'status':'cancelled'});
    expect(expandEventOccurrences([e],DateTime(2026,11,1),DateTime(2026,11,30)),isEmpty);
  });
}
