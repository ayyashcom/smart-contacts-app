import 'contact_model.dart';

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

  // 1. تنظيف الرقم وتوحيده للمقارنة (آخر 9 أرقام لتجاوز مفاتيح الدول والصفر الدولي)
  static String normalizePhoneNumber(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 9) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }

  // 2. تجريد الاسم من التاجات القديمة والرموز التعبيرية والهمزات و"الـ" التعريف
  static String cleanDisplayName(String text) {
    if (text.trim().isEmpty) return '';
    // إزالة أي تاجات مربعة مثل [SRV-MAINT] أو (GEN)
    String clean = text.replaceAll(RegExp(r'\[.*?\]|\(.*?\)|<.*?>'), '');
    // إزالة الرموز التعبيرية والخاصة
    clean = clean.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), '');
    clean = clean.replaceAll(RegExp(r'[\*#_\-=+~|/\\:;!؟?]'), ' ');
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String normalizeForMatching(String text) {
    String clean = cleanDisplayName(text);
    if (clean.isEmpty) return '';

    clean = clean
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');

    List<String> words = clean.split(RegExp(r'\s+'));
    List<String> strippedWords = [];

    for (var w in words) {
      if (w.startsWith('ال') && w.length > 3) {
        strippedWords.add(w.substring(2));
      } else {
        strippedWords.add(w);
      }
    }
    return strippedWords.join(' ').toLowerCase().trim();
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

  static String extractTag(String name, String organization) {
    String combined = '$name $organization'.toLowerCase();
    if (combined.contains('دكتور') || combined.contains('د.') || combined.contains('dr') || combined.contains('مستشفى') || combined.contains('عيادة') || combined.contains('صيدلية')) {
      return 'MED';
    }
    if (combined.contains('صيانة') || combined.contains('ميكانيك') || combined.contains('كهربجي') || combined.contains('تصليح') || combined.contains('سباك') || combined.contains('منجد') || combined.contains('حداد') || combined.contains('نجار')) {
      return 'MAINT';
    }
    if (combined.contains('شركة') || combined.contains('مكتب') || combined.contains('مهندس') || combined.contains('مؤسسة') || combined.contains('تجارة') || combined.contains('معرض')) {
      return 'BIZ';
    }
    if (combined.contains('طوارئ') || combined.contains('دفاع مدني') || combined.contains('شرطة') || combined.contains('امن') || combined.contains('انضباط') || combined.contains('خدمة')) {
      return 'SRV-GEN';
    }
    return 'GEN';
  }

  static AppContact processContact(AppContact contact, {String organization = ''}) {
    contact.displayName = cleanDisplayName(contact.displayName);
    contact.entityTag = extractTag(contact.displayName, organization);
    contact.englishName = transliterate(contact.displayName);

    List<String> normalizedPhones = [];
    for (var phone in contact.phones) {
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.isNotEmpty && !normalizedPhones.contains(cleanPhone)) {
        normalizedPhones.add(cleanPhone);
      }
    }
    contact.phones = normalizedPhones;
    return contact;
  }

  // محرك الفحص والدمج الثنائي: بالرقم أولاً، ثم بالاسم المطبع
  static List<AppContact> deduplicateContacts(List<AppContact> contacts) {
    Map<String, AppContact> phoneRegistry = {};
    Map<String, AppContact> nameRegistry = {};
    List<AppContact> mergedList = [];

    for (var contact in contacts) {
      AppContact? matchedContact;

      // أ. فحص التطابق بأرقام الهواتف
      for (var p in contact.phones) {
        String pKey = normalizePhoneNumber(p);
        if (pKey.isNotEmpty && phoneRegistry.containsKey(pKey)) {
          matchedContact = phoneRegistry[pKey];
          break;
        }
      }

      // ب. إذا لم يتطابق بالرقم، نفحص تطابق الاسم المجرّد
      if (matchedContact == null) {
        String nKey = normalizeForMatching(contact.displayName);
        if (nKey.isNotEmpty && nameRegistry.containsKey(nKey)) {
          matchedContact = nameRegistry[nKey];
        }
      }

      if (matchedContact != null) {
        // دمج أرقام الهاتف
        for (var p in contact.phones) {
          if (!matchedContact.phones.contains(p)) {
            matchedContact.phones.add(p);
          }
          String pKey = normalizePhoneNumber(p);
          if (pKey.isNotEmpty) phoneRegistry[pKey] = matchedContact;
        }

        // تسجيل ID السجل الزائد للحذف
        if (contact.id != matchedContact.id && !matchedContact.duplicateIdsToDelete.contains(contact.id)) {
          matchedContact.duplicateIdsToDelete.add(contact.id);
        }

        // الاحتفاظ بالاسم الأوضح والأطول
        if (contact.displayName.length > matchedContact.displayName.length) {
          matchedContact.displayName = contact.displayName;
          matchedContact.englishName = contact.englishName;
          matchedContact.entityTag = contact.entityTag;
        }
      } else {
        // إدخال جهة جديدة وتسجيل أرقامها واسمها في السجلات
        for (var p in contact.phones) {
          String pKey = normalizePhoneNumber(p);
          if (pKey.isNotEmpty) phoneRegistry[pKey] = contact;
        }
        String nKey = normalizeForMatching(contact.displayName);
        if (nKey.isNotEmpty) nameRegistry[nKey] = contact;
        mergedList.add(contact);
      }
    }

    return mergedList;
  }
}
