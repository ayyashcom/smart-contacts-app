import 'package:flutter/material.dart';
import '../core/contact_model.dart';

class ContactsDashboardScreen extends StatelessWidget {
  final List<AppContact> contacts;
  final Map<String, int> tagStats;
  final List<AppContact> staleCandidates;
  final VoidCallback onSync;
  final VoidCallback onExport;

  const ContactsDashboardScreen({
    Key? key,
    required this.contacts,
    required this.tagStats,
    required this.staleCandidates,
    required this.onSync,
    required this.onExport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مدير جهات الاتصال الذكي'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة الإحصائيات العامة
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('الإجمالي', contacts.length.toString(), Colors.blue),
                    _buildStatCol('المرشحون للمراجعة', staleCandidates.length.toString(), Colors.orange),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // قائمة التصنيفات
            const Text(
              'التصنيفات المكتشفة:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tagStats.entries.map((e) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.blueGrey[800],
                    child: Text(e.value.toString(), style: const TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                  label: Text('[${e.key}]'),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // أزرار التحكم السريع
            ElevatedButton.icon(
              onPressed: onSync,
              icon: const Icon(Icons.sync),
              label: const Text('تحديث ودمج التاجات مع الهاتف'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.teal[700],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download),
              label: const Text('تصدير ملف CSV نظيف'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String title, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
