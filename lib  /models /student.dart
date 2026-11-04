import 'dart:convert';

class Student {
  const Student({
    required this.id,
    required this.name,
    this.birthDate = '',
    this.gender = 'غير محدد',
    this.className = 'القسم التحضيري',
    this.nationalId = '',
    this.notes = '',
    this.evaluations = const {},
    this.history = const [],
    this.legacy = const {},
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String name;
  final String birthDate;
  final String gender;
  final String className;
  final String nationalId;
  final String notes;
  final Map<String, dynamic> evaluations;
  final List<dynamic> history;
  final Map<String, dynamic> legacy;
  final String createdAt;
  final String updatedAt;

  Student copyWith({
    String? id, String? name, String? birthDate, String? gender,
    String? className, String? nationalId, String? notes,
    Map<String, dynamic>? evaluations, List<dynamic>? history,
    Map<String, dynamic>? legacy, String? createdAt, String? updatedAt,
  }) => Student(
    id: id ?? this.id, name: name ?? this.name,
    birthDate: birthDate ?? this.birthDate, gender: gender ?? this.gender,
    className: className ?? this.className, nationalId: nationalId ?? this.nationalId,
    notes: notes ?? this.notes, evaluations: evaluations ?? this.evaluations,
    history: history ?? this.history, legacy: legacy ?? this.legacy,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'birth_date': birthDate, 'gender': gender,
    'class_name': className, 'national_id': nationalId, 'notes': notes,
    'evaluations_json': jsonEncode(evaluations), 'history_json': jsonEncode(history),
    'legacy_json': jsonEncode(legacy), 'created_at': createdAt, 'updated_at': updatedAt,
  };

  factory Student.fromMap(Map<String, dynamic> m) => Student(
    id: '${m['id']}', name: '${m['name']}', birthDate: '${m['birth_date'] ?? ''}',
    gender: '${m['gender'] ?? 'غير محدد'}', className: '${m['class_name'] ?? 'القسم التحضيري'}',
    nationalId: '${m['national_id'] ?? ''}', notes: '${m['notes'] ?? ''}',
    evaluations: _decodeMap(m['evaluations_json']), history: _decodeList(m['history_json']),
    legacy: _decodeMap(m['legacy_json']), createdAt: '${m['created_at'] ?? ''}',
    updatedAt: '${m['updated_at'] ?? ''}',
  );

  static Map<String, dynamic> _decodeMap(dynamic value) {
    try { final v = jsonDecode(value as String); return v is Map<String, dynamic> ? v : {}; }
    catch (_) { return {}; }
  }
  static List<dynamic> _decodeList(dynamic value) {
    try { final v = jsonDecode(value as String); return v is List ? v : []; }
    catch (_) { return []; }
  }
}
