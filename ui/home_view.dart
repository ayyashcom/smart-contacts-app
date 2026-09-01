import '../core/contact_model.dart';

class HomeView {
  static void renderDashboard({
    required List<AppContact> contacts,
    required Map<String, int> tagStats,
    required List<AppContact> staleCandidates,
  }) {
    print('\n======================================================');
    print('          📱 SMART CONTACTS MANAGER (DART ENGINE)     ');
    print('======================================================');
    print(' [📊 DASHBOARD OVERVIEW]');
    print('  • Total Active Contacts : ${contacts.length}');
    print('  • Review / Stale Contacts: ${staleCandidates.length}');
    print('------------------------------------------------------');
    print(' [🏷️ CATEGORIES BREAKDOWN]');
    tagStats.forEach((tag, count) {
      String bar = '█' * (count ~/ 50).clamp(1, 20);
      print('  • [${tag.padRight(7)}] : ${count.toString().padLeft(4)} contacts  $bar');
    });
    print('------------------------------------------------------');
    print(' [⚠️ STALE REVIEW QUEUE (Top Candidates)]');
    for (var i = 0; i < staleCandidates.take(3).length; i++) {
      var c = staleCandidates[i];
      print('  ${i + 1}. ${c.displayName} (${c.englishName})');
      print('     ↳ Status: Stale/Inactive | Last: ${c.lastContactDate.isEmpty ? "No Record" : c.lastContactDate}');
    }
    print('======================================================');
    print(' [ACTIONS AVAILABLE]:');
    print('  [1] Sync & Update Tags to Phone');
    print('  [2] Export Clean Master CSV');
    print('  [3] Batch Clean Stale Contacts');
    print('======================================================\n');
  }
}
