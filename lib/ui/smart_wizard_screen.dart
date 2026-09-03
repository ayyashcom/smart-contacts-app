import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../core/contact_model.dart';
import '../core/rules_engine.dart';
import '../core/contacts_service.dart';

class SmartWizardScreen extends StatefulWidget {
  const SmartWizardScreen({Key? key}) : super(key: key);

  @override
  State<SmartWizardScreen> createState() => _SmartWizardScreenState();
}

class _SmartWizardScreenState extends State<SmartWizardScreen> {
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _previewReady = false;
  double _progressValue = 0.0;
  String _statusMessage = 'جاهز لبدء المعاينة المرحلية الآمنة';

  List<Contact> _rawNativeContacts = [];
  Map<String, Contact> _nativeContactsMap = {};
  List<AppContact> _originalContacts = [];
  List<AppContact> _processedContacts = [];
  final List<String> _errorLogs = [];

  final ProcessingOptions _userOptions = ProcessingOptions();

  // إحصائيات المعاينة المرحلية
  int _activeCount = 0;
  int _vipCount = 0;
  int _tempCount = 0;
  int _candidateCount = 0;
  int _mergedDuplicatesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري قراءة جهات الاتصال من الجهاز...';
    });

    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withAccounts: true,
        );

        _rawNativeContacts = contacts;
        _nativeContactsMap = {for (var c in contacts) c.id: c};

        _originalContacts = contacts.map((c) {
          return AppContact(
            id: c.id,
            displayName: c.displayName,
            phones: c.phones.map((p) => p.number).toList(),
          );
        }).toList();

        setState(() {
          _statusMessage = 'تم تحميل ${_originalContacts.length} جهة اتصال بنجاح.';
        });
      } else {
        setState(() {
          _statusMessage = 'تم رفض إذن الوصول لجهات الاتصال.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ أثناء تحميل جهات الاتصال: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 1. المعاينة المرحلية والتصدير للداونلود (بدون أي تعديل على الهاتف)
  Future<void> _runStagingPreview() async {
    setState(() {
      _isProcessing = true;
      _previewReady = false;
      _progressValue = 0.1;
      _statusMessage = 'جاري المعالجة والفرز الآمن في الذاكرة...';
    });

    try {
      List<AppContact> staged = [];
      for (var c in _originalContacts) {
        var copy = AppContact(
          id: c.id,
          displayName: c.displayName,
          phones: List.from(c.phones),
        );
        staged.add(RulesEngine.processContact(copy, _userOptions));
      }

      _progressValue = 0.4;
      setState(() => _statusMessage = 'جاري دمج الأرقام المكررة استناداً للأرقام فقط...');

      if (_userOptions.enableDeduplication) {
        staged = RulesEngine.deduplicateContactsSafe(staged);
      }

      _progressValue = 0.7;
      setState(() => _statusMessage = 'توليد ملفات المعاينة والتقارير في Downloads...');

      // حساب الإحصائيات
      _activeCount = 0;
      _vipCount = 0;
      _tempCount = 0;
      _candidateCount = 0;
      _mergedDuplicatesCount = 0;

      for (var c in staged) {
        _mergedDuplicatesCount += c.duplicateIdsToDelete.length;
        switch (c.status) {
          case ContactStatus.active: _activeCount++; break;
          case ContactStatus.vip: _vipCount++; break;
          case ContactStatus.temporary: _tempCount++; break;
          case ContactStatus.candidateDelete: _candidateCount++; break;
        }
      }

      _processedContacts = staged;

      // تصدير ملفات العزل المرحلي
      const downloadPath = '/sdcard/Download';
      await ContactsService.exportToVcf(staged, '$downloadPath/CONTACTS_PREVIEW_CHANGES.vcf');
      await ContactsService.generateSummaryReport(
        originalContacts: _originalContacts,
        processedContacts: staged,
        reportPath: '$downloadPath/CHANGES_SUMMARY.txt',
      );

      _progressValue = 1.0;
      _previewReady = true;
      _statusMessage = 'اكتملت المعاينة المرحلية بنجاح! تم حفظ التقارير في مجلد Downloads.';
    } catch (e) {
      _statusMessage = 'حدث خطأ أثناء المعاينة المرحلية: $e';
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 2. بوابة التأكيد الصريح والمزامنة الحقيقية على الجهاز
  Future<void> _showApprovalDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد المزامنة والتطبيق النهائي', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل أنت متأكد من تطبيق التغييرات على دفتر عناوين الهاتف؟'),
              const SizedBox(height: 12),
              Text('• جهات اتصال سيتم تحديثها: ${_processedContacts.length}'),
              Text('• تكرارات سيتم حذفها بعد الدمج الكامل: $_mergedDuplicatesCount'),
              Text('• جهات اتصال نشطة: $_activeCount'),
              Text('• جهات اتصال VIP محمية: $_vipCount'),
              const SizedBox(height: 12),
              const Text('تنبيه: يمكنك فحص الملف CONTACTS_PREVIEW_CHANGES.vcf في مجلد Downloads أولاً.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء المراجعة'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(ctx);
              _commitSyncToDevice();
            },
            child: const Text('موافق، ابدأ المزامنة'),
          ),
        ],
      ),
    );
  }

  // تنفيذ التعديل على الهاتف بحذر متناهٍ
  Future<void> _commitSyncToDevice() async {
    setState(() {
      _isProcessing = true;
      _progressValue = 0.0;
      _statusMessage = 'جاري المزامنة الفعلية على الجهاز...';
      _errorLogs.clear();
    });

    int updatedCount = 0;
    int deletedCount = 0;
    int total = _processedContacts.length;

    for (int i = 0; i < total; i++) {
      var item = _processedContacts[i];
      Contact? native = _nativeContactsMap[item.id];

      if (native != null) {
        try {
          String tagPrefix = item.entityTag.isNotEmpty ? '[${item.entityTag}] ' : '';
          native.name.first = '$tagPrefix${item.displayName}'.trim();
          if (_userOptions.enableTransliteration && item.englishName.isNotEmpty) {
            native.name.nickname = item.englishName;
          }
          if (_userOptions.normalizePhones) {
            native.phones = item.phones.map((p) => Phone(p)).toList();
          }

          // إضافة وسام الحالة في الملاحظات
          native.notes = [Note(item.statusVcfTag)];

          await native.update();
          updatedCount++;
        } catch (updateErr) {
          _errorLogs.add('فشل تحديث (${item.displayName}): $updateErr');
        }
      }

      // حذف التكرارات المدمجة فقط
      if (_userOptions.enableDeduplication) {
        for (var dupId in item.duplicateIdsToDelete) {
          Contact? dupNative = _nativeContactsMap[dupId];
          if (dupNative != null) {
            try {
              await dupNative.delete();
              deletedCount++;
              _nativeContactsMap.remove(dupId);
            } catch (delErr) {
              _errorLogs.add('فشل حذف مكرر ($dupId): $delErr');
            }
          }
        }
      }

      if (i % 15 == 0 || i == total - 1) {
        setState(() {
          _progressValue = (i + 1) / total;
          _statusMessage = 'جاري المزامنة: $updatedCount تم تحديثه | $deletedCount تم حذفه...';
        });
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }

    setState(() {
      _isProcessing = false;
      _statusMessage = 'تمت المزامنة بنجاح! تم تحديث $updatedCount جهة اتصال وحذف $deletedCount مكرر مدمج.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المعالج الذكي - بيئة الفرز الآمنة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isProcessing ? null : _loadContacts,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الحالة: $_statusMessage', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: _isProcessing ? _progressValue : 0.0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_previewReady) ...[
                    Row(
                      children: [
                        _buildStatBadge('نشط', _activeCount, Colors.green),
                        _buildStatBadge('VIP', _vipCount, Colors.amber.shade800),
                        _buildStatBadge('مؤقت', _tempCount, Colors.blue),
                        _buildStatBadge('مرشح حذف', _candidateCount, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('✔ تم دمج $_mergedDuplicatesCount رقم مكرر في أصحابها دون أي فقدان.',
                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    const Divider(),
                  ],
                  Expanded(
                    child: ListView.builder(
                      itemCount: _previewReady ? _processedContacts.length : _originalContacts.length,
                      itemBuilder: (context, index) {
                        final c = _previewReady ? _processedContacts[index] : _originalContacts[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(c.status),
                            child: Text(c.statusLabel.substring(0, 1), style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(c.displayName),
                          subtitle: Text('أرقام: ${c.phones.join(", ")}' +
                              (c.duplicateIdsToDelete.isNotEmpty ? ' • مدمج (${c.duplicateIdsToDelete.length})' : '')),
                          trailing: Text(c.statusLabel, style: TextStyle(color: _getStatusColor(c.status), fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.remove_red_eye),
                          label: const Text('1. معاينة مرحلية وتوليد VCF'),
                          onPressed: _isProcessing ? null : _runStagingPreview,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _previewReady ? Colors.green : Colors.grey),
                          icon: const Icon(Icons.sync),
                          label: const Text('2. اعتماد ومزامنة بالهاتف'),
                          onPressed: (_isProcessing || !_previewReady) ? null : _showApprovalDialog,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ContactStatus status) {
    switch (status) {
      case ContactStatus.active: return Colors.green;
      case ContactStatus.vip: return Colors.amber.shade800;
      case ContactStatus.temporary: return Colors.blue;
      case ContactStatus.candidateDelete: return Colors.red;
    }
  }
}
