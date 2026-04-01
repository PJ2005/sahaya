enum UserRole { ngo, volunteer }

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email, 'name': name, 'role': role.name};
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.volunteer,
      ),
    );
  }
}
