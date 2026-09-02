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
  int _currentStep = 0;
  bool _isLoading = false;
  String _statusMessage = 'جاهز للبدء';
  double _progressValue = 0.0;

  // الاحتفاظ بكائنات النظام الأصلية لتجنب فشل البحث بالـ ID
  Map<String, Contact> _nativeContactsMap = {};
  List<AppContact> _rawContacts = [];
  List<AppContact> _processedContacts = [];
  List<String> _errorLogs = [];
  Map<String, int> _tagStats = {};
  int _totalDuplicatesFound = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndFetch();
  }

  // طلب إذن القراءة والكتابة الصريح (readonly: false)
  Future<void> _checkPermissionsAndFetch() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري التحقق من أذونات القراءة والكتابة الكاملة...';
      _errorLogs.clear();
      _nativeContactsMap.clear();
    });

    try {
      bool granted = await FlutterContacts.requestPermission(readonly: false);
      if (granted) {
        List<Contact> deviceContacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        List<AppContact> loaded = [];
        for (var dc in deviceContacts) {
          _nativeContactsMap[dc.id] = dc;
          List<String> phones = dc.phones
              .map((p) => p.number.trim())
              .where((p) => p.isNotEmpty)
              .toList();

          loaded.add(AppContact(
            id: dc.id,
            displayName: dc.displayName.isEmpty ? 'جهة اتصال بدون اسم' : dc.displayName,
            phones: phones,
          ));
        }

        setState(() {
          _rawContacts = loaded;
          _isLoading = false;
          _statusMessage = 'تم جلب ${_rawContacts.length} جهة اتصال بنجاح مع صلاحية التعديل.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'تم رفض إذن الكتابة. يرجى تفعيل الصلاحية من إعدادات الهاتف.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'خطأ أثناء طلب الصلاحيات: $e';
        _errorLogs.add('Permission Failure: $e');
      });
    }
  }

  Future<void> _runProcessingPipeline() async {
    setState(() {
      _isLoading = true;
      _currentStep = 1;
      _progressValue = 0.0;
      _processedContacts.clear();
      _tagStats.clear();
      _errorLogs.clear();
    });

    int total = _rawContacts.length;
    List<AppContact> tempProcessed = [];
    Map<String, int> tags = {};

    for (int i = 0; i < total; i++) {
      var item = _rawContacts[i];
      try {
        AppContact clean = RulesEngine.processContact(item);
        tempProcessed.add(clean);
        tags[clean.entityTag] = (tags[clean.entityTag] ?? 0) + 1;
      } catch (err) {
        _errorLogs.add('معالجة ${item.displayName}: $err');
      }

      if (i % 25 == 0 || i == total - 1) {
        setState(() {
          _progressValue = (i + 1) / total;
          _statusMessage = 'جاري الفرز: ${i + 1} من أصل $total...';
        });
        await Future.delayed(const Duration(milliseconds: 2));
      }
    }

    List<AppContact> merged = RulesEngine.deduplicateContacts(tempProcessed);

    int duplicatesCount = 0;
    for (var c in merged) {
      duplicatesCount += c.duplicateIdsToDelete.length;
    }

    setState(() {
      _processedContacts = merged;
      _tagStats = tags;
      _totalDuplicatesFound = duplicatesCount;
      _isLoading = false;
      _currentStep = 2;
      _statusMessage = 'اكتمل الفرز! تم تجهيز ${_processedContacts.length} جهة اتصال.';
    });
  }

  // المزامنة الحقيقية باستخدام الكائنات الأصلية المحملة
  Future<void> _syncChangesToDevice() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد المزامنة المباشرة'),
        content: Text(
          'سيتم تعديل تاجات وأسماء ${_processedContacts.length} جهة اتصال وحذف $_totalDuplicatesFound نسخة مكررة مباشرة في هاتفك.\n\nهل أنت متأكد من المتابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('بدء التحديث المباشر'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _progressValue = 0.0;
      _statusMessage = 'جاري تطبيق التعديلات على ذاكرة الهاتف...';
      _errorLogs.clear();
    });

    int total = _processedContacts.length;
    int updatedCount = 0;
    int deletedCount = 0;

    for (int i = 0; i < total; i++) {
      var item = _processedContacts[i];
      Contact? native = _nativeContactsMap[item.id];

      if (native != null) {
        try {
          String tagPrefix = item.entityTag.isNotEmpty ? '[${item.entityTag}] ' : '';
          native.name.first = '$tagPrefix${item.displayName}'.trim();
          native.name.nickname = item.englishName;
          native.phones = item.phones.map((p) => Phone(p)).toList();

          await native.update();
          updatedCount++;
        } catch (updateErr) {
          _errorLogs.add('فشل تحديث (${item.displayName}): $updateErr');
        }
      }

      // حذف النسخ المكررة
      for (var dupId in item.duplicateIdsToDelete) {
        Contact? dupNative = _nativeContactsMap[dupId];
        if (dupNative != null) {
          try {
            await dupNative.delete();
            deletedCount++;
          } catch (delErr) {
            _errorLogs.add('فشل حذف مكرر ($dupId): $delErr');
          }
        }
      }

      if (i % 15 == 0 || i == total - 1) {
        setState(() {
          _progressValue = (i + 1) / total;
          _statusMessage = 'جاري التحديث الفعلي: $updatedCount معدل | $deletedCount محذوف...';
        });
        await Future.delayed(const Duration(milliseconds: 2));
      }
    }

    setState(() {
      _isLoading = false;
      _statusMessage = 'اكتملت العملية: نجح تعديل $updatedCount وحذف $deletedCount.';
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تقرير المزامنة الفعلي'),
          content: Text(
            '✔ تم التحديث بنجاح: $updatedCount\n'
            '✔ تم حذف المكررات: $deletedCount\n'
            '✖ الأخطاء المتبقية: ${_errorLogs.length}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    }
  }

  void _showErrorsModal() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تفاصيل الاستثناءات والأخطاء المسجلة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _errorLogs.length,
                itemBuilder: (c, idx) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${idx + 1}. ${_errorLogs[idx]}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعد الذكي لجهات الاتصال'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: Colors.blueGrey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStepHeader(0, '1. المعاينة', Icons.visibility),
                _buildStepHeader(1, '2. المعالجة', Icons.tune),
                _buildStepHeader(2, '3. النتائج والمزامنة', Icons.check_circle),
              ],
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator(value: _progressValue > 0 ? _progressValue : null, color: Colors.teal),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              _statusMessage,
              style: TextStyle(fontSize: 13, color: Colors.blueGrey[800], fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _currentStep == 0
                ? _buildInitialAuditView()
                : _currentStep == 1
                    ? _buildProcessingProgressView()
                    : _buildFinalReviewView(),
          ),
          if (_errorLogs.isNotEmpty)
            InkWell(
              onTap: _showErrorsModal,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.amber[100],
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('تم تسجيل ${_errorLogs.length} استثناء أثناء العمل (اضغط هنا لمعاينة التفاصيل)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(int step, String title, IconData icon) {
    bool isActive = _currentStep == step;
    return Row(
      children: [
        Icon(icon, size: 18, color: isActive ? Colors.teal[800] : Colors.grey),
        const SizedBox(width: 4),
        Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.teal[800] : Colors.grey)),
      ],
    );
  }

  Widget _buildInitialAuditView() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('العدد: ${_rawContacts.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_rawContacts.isEmpty)
                  ElevatedButton.icon(
                    onPressed: _checkPermissionsAndFetch,
                    icon: const Icon(Icons.refresh),
                    label: const Text('منح الإذن والتحديث'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _runProcessingPipeline,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('بدء التنظيف والفرز'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _rawContacts.length,
            itemBuilder: (context, index) {
              var c = _rawContacts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal[50],
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                ),
                title: Text(c.displayName),
                subtitle: Text(c.phones.join(', ')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingProgressView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: _progressValue, strokeWidth: 6),
          const SizedBox(height: 20),
          Text('${(_progressValue * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFinalReviewView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8,
            children: _tagStats.entries.map((e) => Chip(label: Text('${e.key}: ${e.value}'))).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            'العدد بعد التنظيف: ${_processedContacts.length} (المكررات المطلوب حذفها: $_totalDuplicatesFound)',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _syncChangesToDevice,
                  icon: const Icon(Icons.sync),
                  label: const Text('مزامنة وتطبيق في الهاتف'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await ContactsService.exportToCsv(_processedContacts, '/sdcard/Download/app_smart_contacts.csv');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ نسخة احتياطية في مجلد Download.')));
                },
                icon: const Icon(Icons.save_alt),
                label: const Text('نسخة CSV'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _processedContacts.length,
            itemBuilder: (context, index) {
              var c = _processedContacts[index];
              return ListTile(
                leading: Chip(label: Text(c.entityTag)),
                title: Text(c.displayName),
                subtitle: Text('EN: ${c.englishName}\nأرقام (${c.phones.length})${c.duplicateIdsToDelete.isNotEmpty ? " • مدمج (${c.duplicateIdsToDelete.length})" : ""}: ${c.phones.join(", ")}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
