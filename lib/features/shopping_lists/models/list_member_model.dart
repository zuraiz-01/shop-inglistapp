class ListMemberModel {
  const ListMemberModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String? photoUrl;

  bool get isOwner => role == 'owner';

  factory ListMemberModel.fromMap(
    Map<String, dynamic> map, {
    required String uid,
    required String role,
  }) {
    return ListMemberModel(
      uid: uid,
      name: map['name'] as String? ?? 'Unknown user',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: role,
    );
  }
}
