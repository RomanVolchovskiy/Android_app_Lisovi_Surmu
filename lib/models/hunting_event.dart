class HuntingEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String type; // 'Полювання' | 'Змагання' | 'Фестиваль' | 'Навчання'
  final String? relatedSignalId;

  HuntingEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.type,
    this.relatedSignalId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'location': location,
    'date': date.toIso8601String(),
    'type': type,
    'relatedSignalId': relatedSignalId,
  };

  factory HuntingEvent.fromJson(Map<String, dynamic> json) => HuntingEvent(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    location: json['location']?.toString() ?? '',
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    type: json['type']?.toString() ?? 'Полювання',
    relatedSignalId: json['relatedSignalId'],
  );
}
