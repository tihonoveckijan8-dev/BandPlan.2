/// A user's membership in a BandPlan workspace.
class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    this.ownerId,
    this.joinedAt,
    this.role,
  });

  final String id;
  final String name;
  final String? ownerId;
  final DateTime? joinedAt;
  final String? role;

  bool get isOwner => role?.toLowerCase() == 'owner';

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    final id = (json['group_id'] ?? json['id'])?.toString().trim() ?? '';
    final name =
        (json['group_name'] ?? json['name'])?.toString().trim() ?? '';

    if (id.isEmpty || name.isEmpty) {
      throw const FormatException(
        'Group response is missing its identifier or name.',
      );
    }

    final joinedAtValue = json['joined_at']?.toString();
    return GroupSummary(
      id: id,
      name: name,
      ownerId: json['owner_id']?.toString(),
      joinedAt: joinedAtValue == null
          ? null
          : DateTime.tryParse(joinedAtValue),
      role: json['role']?.toString(),
    );
  }
}
