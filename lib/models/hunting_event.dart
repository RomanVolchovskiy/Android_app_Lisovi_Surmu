class HuntingEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String type; // 'Полювання' | 'Змагання' | 'Фестиваль' | 'Навчання'
  final List<String> mainSignalIds;         // основні (обов'язкові)
  final List<String> accompanyingSignalIds; // сопутні (рекомендовані)
  final bool isGlobal;
  final String? shareCode;

  HuntingEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.type,
    this.mainSignalIds = const [],
    this.accompanyingSignalIds = const [],
    this.isGlobal = false,
    this.shareCode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'location': location,
    'date': date.toIso8601String(),
    'type': type,
    'mainSignalIds': mainSignalIds,
    'accompanyingSignalIds': accompanyingSignalIds,
    'isGlobal': isGlobal,
    'shareCode': shareCode,
  };

  factory HuntingEvent.fromJson(Map<String, dynamic> json) {
    // Backward compat: old format used relatedSignalId (single signal)
    List<String> mainSignalIds = [];
    if (json['mainSignalIds'] != null) {
      mainSignalIds = List<String>.from(json['mainSignalIds'] as List);
    } else if (json['relatedSignalId'] != null) {
      mainSignalIds = [json['relatedSignalId'].toString()];
    }

    return HuntingEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      type: json['type']?.toString() ?? 'Полювання',
      mainSignalIds: mainSignalIds,
      accompanyingSignalIds: json['accompanyingSignalIds'] != null
          ? List<String>.from(json['accompanyingSignalIds'] as List)
          : [],
      isGlobal: json['isGlobal'] as bool? ?? false,
      shareCode: json['shareCode']?.toString(),
    );
  }
}
