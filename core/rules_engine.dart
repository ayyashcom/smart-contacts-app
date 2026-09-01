import 'contact_model.dart';

class RulesEngine {
  // جدول التحويل الصوتي المبسط من العربي للاتيني
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

  // 1. توليد الاسم الإنجليزي الصوتي
  static String transliterate(String arabicText) {
    if (arabicText.trim().isEmpty) return '';
    
    // إزالة التاجات السابقة إن وجدت مثل [WRK]
    String clean = arabicText.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      String char = clean[i];
      buffer.write(_charMap[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // 2. تطبيق التاجات والتصنيف الذكي
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
    if (combined.contains('طوارئ') || combined.contains('دفاع مدني') || combined.contains('شرطة') || combined.contains('امن')) {
      return 'SRV-GEN';
    }
    return 'GEN';
  }

  // 3. معالجة وتدقيق كائن جهة الاتصال بالكامل
  static AppContact processContact(AppContact contact, {String organization = ''}) {
    // تحديد التاج
    String tag = extractTag(contact.displayName, organization);
    contact.entityTag = tag;

    // توليد الاسم الإنجليزي إذا كان مفقوداً
    if (contact.englishName.isEmpty) {
      contact.englishName = transliterate(contact.displayName);
    }

    // تنظيف وتوحيد أرقام الهواتف
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
}
