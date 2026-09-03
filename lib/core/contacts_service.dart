import 'dart:convert';
import 'dart:io';
import 'contact_model.dart';

class ContactsService {
  static List<AppContact> parseRawJson(String rawJson) {
    List<AppContact> contacts = [];
    try {
      final List<dynamic> data = jsonDecode(rawJson);
      for (var item in data) {
        String name = item['name'] ?? '';
        String number = item['number'] ?? '';
        List<String> phones = [];

        if (number.isNotEmpty) {
          phones.add(number);
        }

        if (item['numbers'] != null && item['numbers'] is List) {
          for (var n in item['numbers']) {
            if (n != null && n.toString().isNotEmpty) {
              phones.add(n.toString());
            }
          }
        }

        contacts.add(AppContact(
          id: item['id']?.toString() ?? UniqueKey().toString(),
          displayName: name,
          phones: phones,
        ));
      }
    } catch (e) {
      print('Error parsing JSON: $e');
    }
    return contacts;
  }

  // قراءة وتحليل ملف VCF الماستر بالكامل
  static Future<List<AppContact>> parseVcfFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    final cards = content.split('END:VCARD');
    List<AppContact> contacts = [];

    for (var card in cards) {
      if (!card.contains('BEGIN:VCARD')) continue;
      String name = '';
      List<String> phones = [];
      ContactStatus status = ContactStatus.temporary;

      for (var line in card.split('\n')) {
        line = line.trim();
        if (line.startsWith('FN:')) {
          name = line.substring(3).trim();
        } else if (line.startsWith('TEL')) {
          final parts = line.split(':');
          if (parts.length > 1) {
            final p = parts.sublist(1).join(':').trim();
            if (p.isNotEmpty) phones.add(p);
          }
        } else if (line.startsWith('NOTE:STATUS_')) {
          final tag = line.substring(5).trim();
          if (tag == 'STATUS_ACTIVE') status = ContactStatus.active;
          if (tag == 'STATUS_VIP') status = ContactStatus.vip;
          if (tag == 'STATUS_CANDIDATE_DELETE') status = ContactStatus.candidateDelete;
          if (tag == 'STATUS_TEMP') status = ContactStatus.temporary;
        }
      }

      if (name.isNotEmpty || phones.isNotEmpty) {
        contacts.add(AppContact(
          id: UniqueKey().toString(),
          displayName: name.isEmpty ? (phones.isNotEmpty ? phones.first : 'بدون اسم') : name,
          phones: phones,
          status: status,
        ));
      }
    }
    return contacts;
  }

  // تصدير ملف VCF للمعاينة المرحلية دون المساس بالجهاز
  static Future<File> exportToVcf(List<AppContact> contacts, String outPath) async {
    final buffer = StringBuffer();

    for (var c in contacts) {
      buffer.writeln('BEGIN:VCARD');
      buffer.writeln('VERSION:3.0');
      buffer.writeln('FN:${c.displayName}');
      if (c.englishName.isNotEmpty) {
        buffer.writeln('X-PHONETIC-FIRST-NAME:${c.englishName}');
      }
      for (var p in c.phones) {
        buffer.writeln('TEL;TYPE=CELL:$p');
      }
      buffer.writeln('NOTE:${c.statusVcfTag}');
      if (c.entityTag.isNotEmpty) {
        buffer.writeln('CATEGORIES:${c.entityTag}');
      }
      buffer.writeln('END:VCARD');
    }

    final file = File(outPath);
    return await file.writeAsString(buffer.toString());
  }

  // توليد تقرير الشفافية والفروقات المفصل
  static Future<File> generateSummaryReport({
    required List<AppContact> originalContacts,
    required List<AppContact> processedContacts,
    required String reportPath,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('========================================================');
    buffer.writeln('           تقرير المعاينة المرحلية الشامل لجهات الاتصال           ');
    buffer.writeln('========================================================\n');
    buffer.writeln('إجمالي السجلات المدخلة: ${originalContacts.length}');
    buffer.writeln('إجمالي السجلات بعد الدمج النظيف: ${processedContacts.length}');

    int active = 0, vip = 0, temp = 0, candidate = 0, mergedTotal = 0;
    for (var c in processedContacts) {
      mergedTotal += c.duplicateIdsToDelete.length;
      switch (c.status) {
        case ContactStatus.active: active++; break;
        case ContactStatus.vip: vip++; break;
        case ContactStatus.temporary: temp++; break;
        case ContactStatus.candidateDelete: candidate++; break;
      }
    }

    buffer.writeln('إجمالي التكرارات المعزولة والمدمجة بأمان: $mergedTotal');
    buffer.writeln('\n--- توزيع الحالات الديناميكية ---');
    buffer.writeln(' • نشط مؤخراً (Active): $active');
    buffer.writeln(' • أرقام مهمة (VIP): $vip');
    buffer.writeln(' • مؤقت (Temporary): $temp');
    buffer.writeln(' • مرشح للحذف والمراجعة (Candidate): $candidate\n');

    buffer.writeln('========================================================');
    buffer.writeln('ملاحظة أمان: هذا التقرير يمثل المعاينة المرحلية فقط.');
    buffer.writeln('لم يتم تعديل أو حذف أي جهة اتصال على ذاكرة هاتفك الفعلية.');
    buffer.writeln('========================================================');

    final file = File(reportPath);
    return await file.writeAsString(buffer.toString());
  }
}

class UniqueKey {
  static int _id = 0;
  @override
  String toString() => '${++_id}';
}
