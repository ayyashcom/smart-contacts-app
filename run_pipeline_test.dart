import 'dart:io';
import 'core/contact_model.dart';
import 'core/contacts_service.dart';

void main() async {
  print('==============================================');
  print('[*] Reading Live Contacts from Device...');
  print('==============================================');

  // جلب جهات الاتصال عبر أمر النظام في Termux
  ProcessResult result = await Process.run('termux-contact-list', []);
  
  if (result.exitCode != 0 || result.stdout.toString().isEmpty) {
    print('[!] Error reading contacts. Make sure Termux permissions are granted.');
    return;
  }

  List<AppContact> contacts = ContactsService.parseRawJson(result.stdout.toString());
  print('[✓] Successfully loaded: ${contacts.length} contacts from phone.\n');

  print('[*] Processing & Tagging with RulesEngine...');
  List<AppContact> processed = ContactsService.processAll(contacts);

  // إحصائيات التاجات
  Map<String, int> tagStats = {};
  int multiPhoneCount = 0;

  for (var c in processed) {
    tagStats[c.entityTag] = (tagStats[c.entityTag] ?? 0) + 1;
    if (c.phones.length > 1) multiPhoneCount++;
  }

  print('==============================================');
  print('[✓] Processing Complete! Summary Statistics:');
  print('==============================================');
  print(' • Total Processed Contacts: ${processed.length}');
  print(' • Contacts with Multiple Numbers: $multiPhoneCount');
  print(' • Category Tags Breakdown:');
  tagStats.forEach((tag, count) {
    print('   - [$tag]: $count contacts');
  });
  print('==============================================\n');

  // حفظ نسخة مخرجات للتأكد
  await ContactsService.exportToCsv(processed, 'dart_processed_contacts.csv');
  print('[✓] Exported test result to: dart_processed_contacts.csv');
}
