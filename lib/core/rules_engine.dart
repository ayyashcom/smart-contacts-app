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

  // 1. تطبيع النص العربي وتجريد "الـ" التعريف للمقارنة والمطابقة
  static String normalizeForMatching(String text) {
    if (text.trim().isEmpty) return '';

    // إزالة التاجات السابقة والأقواس
    String clean = text.replaceAll(RegExp(r'\[.*?\]'), '').trim();

    // توحيد الألف والياء والتاء المربوطة
    clean = clean
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');

    // تقسيم النص لكلمات وحذف "ال" التعريف من بداية أي كلمة تتجاوز 3 أحرف
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

  // 2. التحويل اللاتيني الصوتي
  static String transliterate(String arabicText) {
    if (arabicText.trim().isEmpty) return '';
    String clean = arabicText.replaceAll(RegExp(r'\[.*?\]'), '').trim();

    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      String char = clean[i];
      buffer.write(_charMap[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // 3. استخراج التاج
  static String extractTag(String name, String organization) {
    String combined = '$name $organization'.toLowerCase();

    if (combined.contains('دكتور') || combined.contains('د.') || combined.contains('dr') || combined.contains('مستشفى') || combined.contains('عيادة')) {
      return 'MED';
    }
    if (combined.contains('صيانة') || combined.contains('ميكانيك') || combined.contains('كهربجي') || combined.contains('تصليح') || combined.contains('سباك')) {
      return 'MAINT';
    }
    if (combined.contains('شركة') || combined.contains('مكتب') || combined.contains('مهندس') || combined.contains('مؤسسة')) {
      return 'BIZ';
    }
    if (combined.contains('طوارئ') || combined.contains('دفاع مدني') || combined.contains('شرطة') || combined.contains('امن') || combined.contains('انضباط')) {
      return 'SRV-GEN';
    }
    return 'GEN';
  }

  // 4. معالجة وتدقيق جهة الاتصال الفردية
  static AppContact processContact(AppContact contact, {String organization = ''}) {
    contact.entityTag = extractTag(contact.displayName, organization);

    if (contact.englishName.isEmpty) {
      contact.englishName = transliterate(contact.displayName);
    }

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

  // 5. دمج المكررات عبر مقارنة الاسم المطبع وأرقام الهواتف
  static List<AppContact> deduplicateContacts(List<AppContact> contacts) {
    Map<String, AppContact> uniqueMap = {};

    for (var contact in contacts) {
      String normKey = normalizeForMatching(contact.displayName);

      // إذا لم يتوفر اسم واضح، اعتمد على الرقم الأول كمفتاح فريد
      if (normKey.isEmpty && contact.phones.isNotEmpty) {
        normKey = contact.phones.first;
      }

      if (uniqueMap.containsKey(normKey)) {
        // دمج أرقام الهواتف بدون تكرار
        var existing = uniqueMap[normKey]!;
        for (var p in contact.phones) {
          if (!existing.phones.contains(p)) {
            existing.phones.add(p);
          }
        }
        // الاحتفاظ بالاسم الأطول والأكثر تفصيلاً
        if (contact.displayName.length > existing.displayName.length) {
          existing.displayName = contact.displayName;
          existing.englishName = contact.englishName;
        }
      } else {
        uniqueMap[normKey] = contact;
      }
    }

    return uniqueMap.values.toList();
  }
}
