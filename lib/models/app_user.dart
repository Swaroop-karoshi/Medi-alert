import 'package:flutter/foundation.dart';

enum UserRole { doctor, patient }

@immutable
class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String shortCode;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.shortCode,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: map['role'] == 'doctor' ? UserRole.doctor : UserRole.patient,
      shortCode: map['short_code'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'short_code': shortCode,
        'created_at': createdAt.toIso8601String(),
      };
}
