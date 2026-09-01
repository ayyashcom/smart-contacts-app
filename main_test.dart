import 'core/contact_model.dart';
import 'core/rules_engine.dart';

void main() {
  print('========================================');
  print('[*] Testing App Core Logic...');
  print('========================================\n');

  // عينة تجريبية تحتوي أرقاماً متعددة واسماً عربياً
  AppContact testContact = AppContact(
    id: '1',
    displayName: 'دكتور احمد العبادي',
    phones: ['0791234567', '+962 78 888 9999', '0791234567'], // رقم مكرر للتجربة
  );

  print('[+] Original Contact:');
  print(' - Name: ${testContact.displayName}');
  print(' - Phones: ${testContact.phones}\n');

  // تطبيق المعالجة
  AppContact processed = RulesEngine.processContact(testContact);

  print('[✓] Processed Contact:');
  print(' - Display Name: ${processed.displayName}');
  print(' - English Name: ${processed.englishName}');
  print(' - Tag: [${processed.entityTag}]');
  print(' - Clean Phones (No Duplicates): ${processed.phones}');
  print('========================================');
}
