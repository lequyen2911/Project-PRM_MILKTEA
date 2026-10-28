import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'customer' hoặc 'seller'
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.role = 'customer',
    this.createdAt,
  });

  bool get isSeller => role == 'seller';
  bool get isCustomer => role == 'customer';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? created;
    if (map['createdAt'] != null && map['createdAt'] is Timestamp) {
      created = (map['createdAt'] as Timestamp).toDate();
    }

    return UserModel(
      uid: docId ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'customer',
      createdAt: created,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, docId: doc.id);
  }
}
