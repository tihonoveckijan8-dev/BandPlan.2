import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/events/domain/group_event.dart';
void main() {
  test('reads legacy fields and preserves unknown payload fields', () {
    final event=GroupEvent.fromJson({'id':'e1','title':'Sunday','date':'2026-11-08','end':'12:00',
      'setlistId':'s1','repeat':'weekly','memberIds':['m1'],'customField':{'keep':true}});
    expect(event.title,'Sunday'); expect(event.end,'12:00'); expect(event.setlistId,'s1');
    expect(event.repeat,'weekly'); expect(event.memberIds,['m1']);
    expect(event.toLegacyJson()['customField'],{'keep':true});
  });
  test('edits known fields without dropping unknown fields', () {
    final event=GroupEvent.fromJson({'id':'e1','title':'Old','date':'2026-11-08','privateLegacyField':{'enabled':true}});
    final edited=event.withEdits(title:'New',date:'2026-11-09',type:'rehearsal',time:'19:00',end:'',
      location:'',notes:'',status:'upcoming',repeat:'none',repeatUntil:'',setlistId:'');
    expect(edited.title,'New'); expect(edited.toLegacyJson()['privateLegacyField'],{'enabled':true});
  });
  test('rejects event payloads without an id', () {
    expect(()=>GroupEvent.fromJson({'title':'Missing id'}),throwsFormatException);
  });
}