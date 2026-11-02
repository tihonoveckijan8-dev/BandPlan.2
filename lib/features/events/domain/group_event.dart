/// Lossless view of a legacy group event JSON payload.
class GroupEvent {
  GroupEvent._(this.raw)
      : id = _string(raw['id']),
        title = _string(raw['title']),
        date = _string(raw['date']),
        time = _string(raw['time']),
        type = _string(raw['type']),
        location = _string(raw['location']),
        status = _string(raw['status']),
        setlistId = _string(raw['setlistId']);

  final Map<String, dynamic> raw;
  final String id;
  final String title;
  final String date;
  final String time;
  final String type;
  final String location;
  final String status;
  final String setlistId;

  factory GroupEvent.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (_string(copy['id']).isEmpty) {
      throw const FormatException('Event payload is missing its id.');
    }
    return GroupEvent._(copy);
  }

  Map<String, dynamic> toLegacyJson() => Map<String, dynamic>.from(raw);

  static String _string(Object? value) => value?.toString().trim() ?? '';
}
