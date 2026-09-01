class AppContact {
  final String id;
  String displayName;
  String originalName;
  String englishName;
  String entityTag;
  List<String> phones;
  String lastContactDate;
  String contactChannel;
  String whatsAppStatus;
  bool isCandidateForDeletion;
  String notes;

  AppContact({
    required this.id,
    required this.displayName,
    this.originalName = '',
    this.englishName = '',
    this.entityTag = '',
    required this.phones,
    this.lastContactDate = '',
    this.contactChannel = '',
    this.whatsAppStatus = 'Unknown',
    this.isCandidateForDeletion = false,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'englishName': englishName,
      'entityTag': entityTag,
      'phones': phones,
      'lastContactDate': lastContactDate,
      'whatsAppStatus': whatsAppStatus,
      'isCandidateForDeletion': isCandidateForDeletion,
      'notes': notes,
    };
  }
}
