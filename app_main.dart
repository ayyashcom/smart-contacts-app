import 'dart:io';
import 'core/contact_model.dart';
import 'core/contacts_service.dart';
import 'ui/home_view.dart';

void main() async {
  print('[*] Initializing Smart Contacts Engine...');

  ProcessResult result = await Process.run('termux-contact-list', []);
  if (result.exitCode != 0 || result.stdout.toString().isEmpty) {
    print('[!] Permission denied or no contacts found.');
    return;
  }

  List<AppContact> raw = ContactsService.parseRawJson(result.stdout.toString());
  List<AppContact> processed = ContactsService.processAll(raw);

  Map<String, int> tagStats = {};
  List<AppContact> staleCandidates = [];

  for (var c in processed) {
    tagStats[c.entityTag] = (tagStats[c.entityTag] ?? 0) + 1;
    if (c.entityTag == 'GEN' && c.phones.length <= 1) {
      staleCandidates.add(c);
    }
  }

  HomeView.renderDashboard(
    contacts: processed,
    tagStats: tagStats,
    staleCandidates: staleCandidates,
  );
}
