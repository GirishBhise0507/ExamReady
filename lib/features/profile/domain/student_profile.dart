class StudentProfile {
  const StudentProfile({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.city,
    this.institution,
    this.dateOfBirth,
  });

  final String userId;
  final String name;
  final String email;
  final String? phone;
  final Uri? photoUrl;
  final String? city;
  final String? institution;
  final DateTime? dateOfBirth;
}
