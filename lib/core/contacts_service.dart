import 'dart:convert';
import 'dart:io';
import 'contact_model.dart';
import 'rules_engine.dart';

class ContactsService {
  // تحليل ناتج JSON القادم من Termux API إن وُجد
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

  // تصدير جهات الاتصال إلى ملف CSV
  static Future<File> exportToCsv(List<AppContact> contacts, String filePath) async {
    final StringBuffer csvData = StringBuffer();
    csvData.writeln('ID,Display_Name,English_Name,Tag,Phones,Last_Contact');

    for (var c in contacts) {
      String cleanName = c.displayName.replaceAll('"', '""');
      String phonesStr = c.phones.join(';');
      csvData.writeln('"${c.id}","$cleanName","${c.englishName}","${c.entityTag}","$phonesStr","${c.lastContactDate}"');
    }

    final File file = File(filePath);
    return await file.writeAsString(csvData.toString());
  }
}

class UniqueKey {
  static int _id = 0;
  @override
  String toString() => '${++_id}';
}
