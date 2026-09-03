enum ContactStatus {
  active,          // نشط مؤخراً
  temporary,       // مؤقت
  candidateDelete, // مرشح للحذف
  vip              // رقم مهم
}

class AppContact {
  String id;
  String displayName;
  String englishName;
  String entityTag;
  List<String> phones;
  String lastContactDate;
  ContactStatus status;
  List<String> duplicateIdsToDelete;

  AppContact({
    required this.id,
    required this.displayName,
    this.englishName = '',
    this.entityTag = 'GEN',
    required this.phones,
    this.lastContactDate = '',
    this.status = ContactStatus.temporary,
    List<String>? duplicateIdsToDelete,
  }) : duplicateIdsToDelete = duplicateIdsToDelete ?? [];

  String get statusLabel {
    switch (status) {
      case ContactStatus.active: return 'نشط';
      case ContactStatus.temporary: return 'مؤقت';
      case ContactStatus.candidateDelete: return 'مرشح للحذف';
      case ContactStatus.vip: return 'رقم مهم';
    }
  }

  String get statusVcfTag {
    switch (status) {
      case ContactStatus.active: return 'STATUS_ACTIVE';
      case ContactStatus.temporary: return 'STATUS_TEMP';
      case ContactStatus.candidateDelete: return 'STATUS_CANDIDATE_DELETE';
      case ContactStatus.vip: return 'STATUS_VIP';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'englishName': englishName,
      'entityTag': entityTag,
      'phones': phones.join(';'),
      'lastContactDate': lastContactDate,
      'status': status.name,
      'mergedDuplicatesCount': duplicateIdsToDelete.length,
    };
  }
}
