/// Lossless model for the legacy BandPlan setlist JSON payload.
class Setlist {
  Setlist._(this.raw)
      : id = _string(raw['id']),
        name = _string(raw['name']),
        note = _string(raw['note']),
        eventId = _string(raw['eventId']),
        items = (raw['items'] is List ? raw['items'] as List : const [])
            .whereType<Map>()
            .map((item) => SetlistItem.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);

  final Map<String, dynamic> raw;
  final String id;
  final String name;
  final String note;
  final String eventId;
  final List<SetlistItem> items;

  factory Setlist.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    if (_string(copy['id']).isEmpty) {
      throw const FormatException('Setlist payload is missing its id.');
    }
    return Setlist._(copy);
  }

  Setlist withEdits({
    required String name,
    required String note,
    required List<SetlistItem> items,
    String? eventId,
  }) =>
      Setlist._({
        ...raw,
        'name': name,
        'note': note,
        // WHY: omitting eventId during a partial edit must not silently unlink
        // an existing setlist; pass an empty string explicitly to clear it.
        'eventId': eventId ?? this.eventId,
        'items': items.map((item) => item.toJson()).toList(growable: false),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

  Map<String, dynamic> toLegacyJson() => Map<String, dynamic>.from(raw);

  static String _string(Object? value) => value?.toString().trim() ?? '';
}

class SetlistItem {
  SetlistItem._(this.raw)
      : id = _string(raw['id']),
        songId = _string(raw['songId']),
        shift = _integer(raw['shift']),
        note = _string(raw['note']);

  final Map<String, dynamic> raw;
  final String id;
  final String songId;
  final int shift;
  final String note;

  factory SetlistItem.fromJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    return SetlistItem._(copy);
  }

  factory SetlistItem.create(String songId) => SetlistItem._({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'songId': songId,
        'shift': 0,
        'note': '',
      });

  SetlistItem withEdits({int? shift, String? note}) => SetlistItem._({
        ...raw,
        if (shift != null) 'shift': shift,
        if (note != null) 'note': note,
      });

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);

  static String _string(Object? value) => value?.toString().trim() ?? '';
  static int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
