/// Lossless view of a legacy group event JSON payload.
class GroupEvent {
  GroupEvent._(this.raw)
      : id = _string(raw['id']), title = _string(raw['title']),
        date = _string(raw['date']), time = _string(raw['time']),
        end = _string(raw['end']), type = _string(raw['type']),
        location = _string(raw['location']), notes = _string(raw['notes']),
        status = _string(raw['status']), repeat = _string(raw['repeat']),
        repeatUntil = _string(raw['repeatUntil']), setlistId = _string(raw['setlistId']);
  final Map<String, dynamic> raw;
  final String id, title, date, time, end, type, location, notes, status, repeat, repeatUntil, setlistId;
  List<String> get memberIds => _stringList(raw['memberIds']);
  List<String> get except => _stringList(raw['except']);
  factory GroupEvent.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (_string(copy['id']).isEmpty) throw const FormatException('Event payload is missing its id.');
    return GroupEvent._(copy);
  }
  factory GroupEvent.create({
    required String id, required String title, required String date, required String type,
    String time = '', String end = '', String location = '', String notes = '',
    String status = 'upcoming', String repeat = 'none', String repeatUntil = '', String setlistId = '',
  }) => GroupEvent.fromJson({
    'id': id, 'title': title, 'date': date, 'time': time, 'end': end, 'type': type,
    'location': location, 'notes': notes, 'status': status, 'repeat': repeat,
    'repeatUntil': repeatUntil, 'setlistId': setlistId, 'memberIds': <String>[],
    'except': <String>[], 'participation': <String, dynamic>{},
    'participationUpdatedAt': <String, dynamic>{},
  });
  GroupEvent withEdits({
    required String title, required String date, required String type, required String time,
    required String end, required String location, required String notes, required String status,
    required String repeat, required String repeatUntil, required String setlistId,
  }) => GroupEvent.fromJson({...raw, 'title': title, 'date': date, 'type': type, 'time': time,
    'end': end, 'location': location, 'notes': notes, 'status': status, 'repeat': repeat,
    'repeatUntil': repeatUntil, 'setlistId': setlistId});
  Map<String, dynamic> toLegacyJson() => Map<String, dynamic>.from(raw);
  static String _string(Object? value) => value?.toString().trim() ?? '';
  static List<String> _stringList(Object? value) =>
      value is List ? value.map(_string).where((v) => v.isNotEmpty).toList() : const [];
}