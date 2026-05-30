class Patient {
  final String id;
  final String userId;
  final String name;
  final int age;
  final String relation;

  const Patient({
    required this.id,
    required this.userId,
    required this.name,
    required this.age,
    required this.relation,
  });

  factory Patient.fromMap(Map<String, dynamic> map) => Patient(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        age: map['age'] as int,
        relation: map['relation'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'age': age,
        'relation': relation,
      };
}
