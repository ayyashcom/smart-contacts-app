class AppContact {
  String id;
  String displayName;
  String englishName;
  String entityTag;
  List<String> phones;
  String lastContactDate;
  List<String> duplicateIdsToDelete; // المعرفات التابعة التي تم دمجها لحذفها لاحقاً

  AppContact({
    required this.id,
    required this.displayName,
    this.englishName = '',
    this.entityTag = 'GEN',
    required this.phones,
    this.lastContactDate = '',
    List<String>? duplicateIdsToDelete,
  }) : duplicateIdsToDelete = duplicateIdsToDelete ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'englishName': englishName,
      'entityTag': entityTag,
      'phones': phones.join(';'),
      'lastContactDate': lastContactDate,
    };
  }
}
