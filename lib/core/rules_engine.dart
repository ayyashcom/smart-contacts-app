import 'contact_model.dart';

class ProcessingOptions {
  bool enableDeduplication;
  bool enableTagging;
  bool useArabicTags;
  bool enableTransliteration;
  bool normalizePhones;

  ProcessingOptions({
    this.enableDeduplication = true,
    this.enableTagging = true,
    this.useArabicTags = false,
    this.enableTransliteration = true,
    this.normalizePhones = true,
  });
}

class RulesEngine {
  static const Map<String, String> _charMap = {
    'ا': 'A', 'أ': 'A', 'إ': 'E', 'آ': 'Aa',
    'ب': 'B', 'ت': 'T', 'ث': 'Th', 'ج': 'J',
    'ح': 'H', 'خ': 'Kh', 'د': 'D', 'ذ': 'Th',
    'ر': 'R', 'ز': 'Z', 'س': 'S', 'ش': 'Sh',
    'ص': 'S', 'ض': 'D', 'ط': 'T', 'ظ': 'Z',
    'ع': 'A', 'غ': 'Gh', 'ف': 'F', 'ق': 'Q',
    'ك': 'K', 'ل': 'L', 'م': 'M', 'ن': 'N',
    'ه': 'H', 'و': 'W', 'ي': 'Y', 'ى': 'A',
    'ة': 'h', 'ء': '', 'ئ': 'Y', 'ؤ': 'W'
  };

  static String normalizePhoneNumber(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length >= 9) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }

  static String cleanDisplayName(String text) {
    if (text.trim().isEmpty) return '';
    String clean = text.replaceAll(RegExp(r'\[.*?\]|\(.*?\)|<.*?>'), '');
    clean = clean.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), '');
    clean = clean.replaceAll(RegExp(r'[\*#_\-=+~|/\\:;!؟?]'), ' ');
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String transliterate(String text) {
    String clean = cleanDisplayName(text);
    if (clean.isEmpty) return '';

    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      String char = clean[i];
      buffer.write(_charMap[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String extractTag(String name, String organization, bool useArabic) {
    String combined = '$name $organization'.toLowerCase();
    if (combined.contains('دكتور') || combined.contains('د.') || combined.contains('dr') || combined.contains('مستشفى') || combined.contains('عيادة') || combined.contains('صيدلية')) {
      return useArabic ? 'طبيب' : 'MED';
    }
    if (combined.contains('صيانة') || combined.contains('ميكانيك') || combined.contains('كهربجي') || combined.contains('تصليح') || combined.contains('سباك') || combined.contains('منجد') || combined.contains('حداد') || combined.contains('نجار')) {
      return useArabic ? 'صيانة' : 'MAINT';
    }
    if (combined.contains('شركة') || combined.contains('مكتب') || combined.contains('مهندس') || combined.contains('مؤسسة') || combined.contains('تجارة') || combined.contains('معرض')) {
      return useArabic ? 'أعمال' : 'BIZ';
    }
    if (combined.contains('طوارئ') || combined.contains('دفاع مدني') || combined.contains('شرطة') || combined.contains('امن') || combined.contains('انضباط') || combined.contains('خدمة')) {
      return useArabic ? 'خدمات' : 'SRV-GEN';
    }
    return useArabic ? 'عام' : 'GEN';
  }

  static AppContact processContact(AppContact contact, ProcessingOptions opts, {String organization = '', Set<String>? activePhones, Set<String>? vipPhones}) {
    contact.displayName = cleanDisplayName(contact.displayName);

    if (opts.enableTagging) {
      contact.entityTag = extractTag(contact.displayName, organization, opts.useArabicTags);
    } else {
      contact.entityTag = '';
    }

    if (opts.enableTransliteration) {
      contact.englishName = transliterate(contact.displayName);
    } else {
      contact.englishName = '';
    }

    if (opts.normalizePhones) {
      List<String> normalizedPhones = [];
      for (var phone in contact.phones) {
        String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
        if (cleanPhone.isNotEmpty && !normalizedPhones.contains(cleanPhone)) {
          normalizedPhones.add(cleanPhone);
        }
      }
      contact.phones = normalizedPhones;
    }

    // تحديد الحالة بدقة متناهية
    bool isVip = false;
    bool isActive = false;

    if (vipPhones != null) {
      isVip = contact.phones.any((p) => vipPhones.contains(normalizePhoneNumber(p)));
    }
    if (activePhones != null) {
      isActive = contact.phones.any((p) => activePhones.contains(normalizePhoneNumber(p)));
    }

    if (isVip) {
      contact.status = ContactStatus.vip;
    } else if (isActive) {
      contact.status = ContactStatus.active;
    }

    return contact;
  }

  // دمج آمن: حصراً برقم الهاتف (Phone-Only Deduplication) لحماية تشابه الأسماء
  static List<AppContact> deduplicateContactsSafe(List<AppContact> contacts) {
    Map<String, AppContact> phoneRegistry = {};
    List<AppContact> mergedList = [];

    for (var contact in contacts) {
      AppContact? matchedContact;

      for (var p in contact.phones) {
        String pKey = normalizePhoneNumber(p);
        if (pKey.length >= 7 && phoneRegistry.containsKey(pKey)) {
          matchedContact = phoneRegistry[pKey];
          break;
        }
      }

      if (matchedContact != null) {
        // دمج كامل الأرقام في السجل الأصلي
        for (var p in contact.phones) {
          if (!matchedContact.phones.contains(p)) {
            matchedContact.phones.add(p);
          }
          String pKey = normalizePhoneNumber(p);
          if (pKey.length >= 7) phoneRegistry[pKey] = matchedContact;
        }

        // إضافة المعرف للحذف الآمن فقط إذا لم تكن جهة الاتصال VIP
        if (contact.id != matchedContact.id && !matchedContact.duplicateIdsToDelete.contains(contact.id)) {
          if (contact.status != ContactStatus.vip) {
            matchedContact.duplicateIdsToDelete.add(contact.id);
          }
        }

        // إذا كان أحدهما نشط أو VIP يرث السجل الأصلي الحالة الأقوى
        if (contact.status == ContactStatus.vip || matchedContact.status == ContactStatus.vip) {
          matchedContact.status = ContactStatus.vip;
        } else if (contact.status == ContactStatus.active || matchedContact.status == ContactStatus.active) {
          matchedContact.status = ContactStatus.active;
        }

        // تفضيل الاسم العربي الأطول والأوضح
        if (contact.displayName.length > matchedContact.displayName.length) {
          matchedContact.displayName = contact.displayName;
          matchedContact.englishName = contact.englishName;
          matchedContact.entityTag = contact.entityTag;
        }
      } else {
        for (var p in contact.phones) {
          String pKey = normalizePhoneNumber(p);
          if (pKey.length >= 7) phoneRegistry[pKey] = contact;
        }
        mergedList.add(contact);
      }
    }

    return mergedList;
  }
}
