import 'dart:convert';
import 'dart:io';
import 'contact_model.dart';
import 'rules_engine.dart';

class ContactsService {
  // 1. قراءة جهات الاتصال من مخرجات النظام (JSON)
  static List<AppContact> parseRawJson(String jsonString) {
    final List<dynamic> rawList = jsonDecode(jsonString);
    List<AppContact> contacts = [];

    for (var item in rawList) {
      String name = (item['name'] ?? '').toString().trim();
      List<String> rawNumbers = [];

      var numbers = item['numbers'];
      if (numbers is List) {
        for (var n in numbers) {
          if (n is Map && n.containsKey('number')) {
            rawNumbers.add(n['number'].toString());
          } else if (n != null) {
            rawNumbers.add(n.toString());
          }
        }
      } else if (item.containsKey('number') && item['number'] != null) {
        rawNumbers.add(item['number'].toString());
      }

      if (name.isEmpty && rawNumbers.isEmpty) continue;

      contacts.add(AppContact(
        id: (item['id'] ?? contacts.length + 1).toString(),
        displayName: name,
        originalName: name,
        phones: rawNumbers,
      ));
    }
    return contacts;
  }

  // 2. معالجة وتدقيق كامل القائمة دفعة واحدة
  static List<AppContact> processAll(List<AppContact> rawContacts) {
    List<AppContact> processed = [];
    for (var contact in rawContacts) {
      processed.add(RulesEngine.processContact(contact));
    }
    return processed;
  }

  // 3. تصدير النتيجة إلى ملف CSV جاهز للنظام
  static Future<void> exportToCsv(List<AppContact> contacts, String filePath) async {
    final file = File(filePath);
    final sink = file.openWrite();

    // ترويسة CSV متوافقة
    sink.writeln('Name,Given Name,Nickname,Notes,Phone 1 - Value,Phone 2 - Value,Phone 3 - Value');

    for (var c in contacts) {
      String p1 = c.phones.isNotEmpty ? c.phones[0] : '';
      String p2 = c.phones.length > 1 ? c.phones[1] : '';
      String p3 = c.phones.length > 2 ? c.phones[2] : '';

      String tagPrefix = c.entityTag.isNotEmpty ? '[${c.entityTag}] ' : '';
      String finalName = '$tagPrefix${c.displayName}'.trim();
      String note = c.englishName.isNotEmpty ? 'EN: ${c.englishName}' : '';

      sink.writeln('"$finalName","$finalName","${c.englishName}","$note","$p1","$p2","$p3"');
    }

    await sink.flush();
    await sink.close();
  }
}
