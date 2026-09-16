import 'package:cloud_firestore/cloud_firestore.dart';

// ── СЕСІЯ ІСПИТУ ────────────────────────────────────────────────────────────
class ExamSession {
  final String id;
  final String code;          // 6 символів, напр. "A1B2C3"
  final String title;
  final DateTime createdAt;
  final DateTime? deadline;
  final String status;        // 'draft' | 'active' | 'closed'
  final int passingScore;     // мінімальний прохідний бал

  // Теоретичний тест
  final bool theoryEnabled;
  final String? theoryTopicId;
  final String? theoryTopicName;
  final int theoryMaxPoints;
  final int theoryQuestionCount;

  // Аудіо тест
  final bool audioEnabled;
  final String? audioDifficulty; // null = усі рівні
  final int audioMaxPoints;
  final int audioQuestionCount;

  // Файлове завдання
  final bool fileEnabled;
  final int fileMaxPoints;
  final String fileTaskDescription;

  const ExamSession({
    required this.id,
    required this.code,
    required this.title,
    required this.createdAt,
    this.deadline,
    this.status = 'draft',
    this.passingScore = 60,
    this.theoryEnabled = false,
    this.theoryTopicId,
    this.theoryTopicName,
    this.theoryMaxPoints = 0,
    this.theoryQuestionCount = 10,
    this.audioEnabled = false,
    this.audioDifficulty,
    this.audioMaxPoints = 0,
    this.audioQuestionCount = 10,
    this.fileEnabled = false,
    this.fileMaxPoints = 0,
    this.fileTaskDescription = '',
  });

  int get totalMaxPoints => theoryMaxPoints + audioMaxPoints + fileMaxPoints;
  bool get isActive => status == 'active';
  bool get isExpired => deadline != null && DateTime.now().isAfter(deadline!);

  Map<String, dynamic> toJson() => {
    'id': id, 'code': code, 'title': title,
    'createdAt': Timestamp.fromDate(createdAt),
    'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
    'status': status, 'passingScore': passingScore,
    'theoryEnabled': theoryEnabled,
    'theoryTopicId': theoryTopicId,
    'theoryTopicName': theoryTopicName,
    'theoryMaxPoints': theoryMaxPoints,
    'theoryQuestionCount': theoryQuestionCount,
    'audioEnabled': audioEnabled,
    'audioDifficulty': audioDifficulty,
    'audioMaxPoints': audioMaxPoints,
    'audioQuestionCount': audioQuestionCount,
    'fileEnabled': fileEnabled,
    'fileMaxPoints': fileMaxPoints,
    'fileTaskDescription': fileTaskDescription,
  };

  factory ExamSession.fromJson(Map<String, dynamic> j) => ExamSession(
    id:    j['id']?.toString() ?? '',
    code:  j['code']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    createdAt: (j['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    deadline:  (j['deadline']  as Timestamp?)?.toDate(),
    status:       j['status']?.toString() ?? 'draft',
    passingScore: (j['passingScore'] as num?)?.toInt() ?? 60,
    theoryEnabled:       j['theoryEnabled'] == true,
    theoryTopicId:       j['theoryTopicId'],
    theoryTopicName:     j['theoryTopicName'],
    theoryMaxPoints:     (j['theoryMaxPoints']     as num?)?.toInt() ?? 0,
    theoryQuestionCount: (j['theoryQuestionCount'] as num?)?.toInt() ?? 10,
    audioEnabled:       j['audioEnabled'] == true,
    audioDifficulty:    j['audioDifficulty'],
    audioMaxPoints:     (j['audioMaxPoints']     as num?)?.toInt() ?? 0,
    audioQuestionCount: (j['audioQuestionCount'] as num?)?.toInt() ?? 10,
    fileEnabled:          j['fileEnabled'] == true,
    fileMaxPoints:        (j['fileMaxPoints'] as num?)?.toInt() ?? 0,
    fileTaskDescription:  j['fileTaskDescription']?.toString() ?? '',
  );

  ExamSession copyWith({String? status, DateTime? deadline, String? title,
      int? passingScore}) => ExamSession(
    id: id, code: code,
    title: title ?? this.title,
    createdAt: createdAt,
    deadline: deadline ?? this.deadline,
    status: status ?? this.status,
    passingScore: passingScore ?? this.passingScore,
    theoryEnabled: theoryEnabled, theoryTopicId: theoryTopicId,
    theoryTopicName: theoryTopicName, theoryMaxPoints: theoryMaxPoints,
    theoryQuestionCount: theoryQuestionCount,
    audioEnabled: audioEnabled, audioDifficulty: audioDifficulty,
    audioMaxPoints: audioMaxPoints, audioQuestionCount: audioQuestionCount,
    fileEnabled: fileEnabled, fileMaxPoints: fileMaxPoints,
    fileTaskDescription: fileTaskDescription,
  );
}

// ── ВІДПОВІДЬ СТУДЕНТА ───────────────────────────────────────────────────────
class ExamSubmission {
  final String id;
  final String sessionId;
  final String sessionCode;
  final String studentName;
  final DateTime submittedAt;

  // Теоретичний тест
  final int theoryCorrect;
  final int theoryTotal;
  final int theoryAutoPoints;
  final int? adminTheoryPoints;

  // Аудіо тест
  final int audioCorrect;
  final int audioTotal;
  final int audioAutoPoints;
  final int? adminAudioPoints;

  // Файл
  final String? fileUrl;
  final String? fileName;
  final int? adminFilePoints;

  // Адмін
  final String? adminNote;
  final String status; // 'pending' | 'graded'

  const ExamSubmission({
    required this.id,
    required this.sessionId,
    required this.sessionCode,
    required this.studentName,
    required this.submittedAt,
    this.theoryCorrect = 0,
    this.theoryTotal = 0,
    this.theoryAutoPoints = 0,
    this.adminTheoryPoints,
    this.audioCorrect = 0,
    this.audioTotal = 0,
    this.audioAutoPoints = 0,
    this.adminAudioPoints,
    this.fileUrl,
    this.fileName,
    this.adminFilePoints,
    this.adminNote,
    this.status = 'pending',
  });

  int get theoryPoints => adminTheoryPoints ?? theoryAutoPoints;
  int get audioPoints  => adminAudioPoints  ?? audioAutoPoints;
  int get filePoints   => adminFilePoints   ?? 0;
  int get totalPoints  => theoryPoints + audioPoints + filePoints;
  bool get isGraded    => status == 'graded';

  Map<String, dynamic> toJson() => {
    'id': id, 'sessionId': sessionId, 'sessionCode': sessionCode,
    'studentName': studentName,
    'submittedAt': Timestamp.fromDate(submittedAt),
    'theoryCorrect': theoryCorrect, 'theoryTotal': theoryTotal,
    'theoryAutoPoints': theoryAutoPoints, 'adminTheoryPoints': adminTheoryPoints,
    'audioCorrect': audioCorrect, 'audioTotal': audioTotal,
    'audioAutoPoints': audioAutoPoints, 'adminAudioPoints': adminAudioPoints,
    'fileUrl': fileUrl, 'fileName': fileName,
    'adminFilePoints': adminFilePoints,
    'adminNote': adminNote, 'status': status,
  };

  factory ExamSubmission.fromJson(Map<String, dynamic> j) => ExamSubmission(
    id:            j['id']?.toString() ?? '',
    sessionId:     j['sessionId']?.toString() ?? '',
    sessionCode:   j['sessionCode']?.toString() ?? '',
    studentName:   j['studentName']?.toString() ?? '',
    submittedAt:   (j['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    theoryCorrect: (j['theoryCorrect'] as num?)?.toInt() ?? 0,
    theoryTotal:   (j['theoryTotal']   as num?)?.toInt() ?? 0,
    theoryAutoPoints:  (j['theoryAutoPoints']  as num?)?.toInt() ?? 0,
    adminTheoryPoints: (j['adminTheoryPoints'] as num?)?.toInt(),
    audioCorrect:  (j['audioCorrect'] as num?)?.toInt() ?? 0,
    audioTotal:    (j['audioTotal']   as num?)?.toInt() ?? 0,
    audioAutoPoints:  (j['audioAutoPoints']  as num?)?.toInt() ?? 0,
    adminAudioPoints: (j['adminAudioPoints'] as num?)?.toInt(),
    fileUrl:  j['fileUrl'],
    fileName: j['fileName'],
    adminFilePoints: (j['adminFilePoints'] as num?)?.toInt(),
    adminNote: j['adminNote'],
    status:    j['status']?.toString() ?? 'pending',
  );

  ExamSubmission copyWith({
    int? adminTheoryPoints,
    int? adminAudioPoints,
    int? adminFilePoints,
    String? adminNote,
    String? status,
  }) => ExamSubmission(
    id: id, sessionId: sessionId, sessionCode: sessionCode,
    studentName: studentName, submittedAt: submittedAt,
    theoryCorrect: theoryCorrect, theoryTotal: theoryTotal,
    theoryAutoPoints: theoryAutoPoints,
    adminTheoryPoints: adminTheoryPoints ?? this.adminTheoryPoints,
    audioCorrect: audioCorrect, audioTotal: audioTotal,
    audioAutoPoints: audioAutoPoints,
    adminAudioPoints: adminAudioPoints ?? this.adminAudioPoints,
    fileUrl: fileUrl, fileName: fileName,
    adminFilePoints: adminFilePoints ?? this.adminFilePoints,
    adminNote: adminNote ?? this.adminNote,
    status: status ?? this.status,
  );
}
