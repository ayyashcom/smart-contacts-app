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

  List<AppContact> _rawContacts = [];
  List<AppContact> _processedContacts = [];
  List<String> _errorLogs = [];
  Map<String, int> _tagStats = {};

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndFetch();
  }

  Future<void> _checkPermissionsAndFetch() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري التحقق من أذونات جهات الاتصال...';
      _errorLogs.clear();
    });

    try {
      if (await FlutterContacts.requestPermission()) {
        List<Contact> deviceContacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        List<AppContact> loaded = [];
        for (var dc in deviceContacts) {
          try {
            List<String> phones = dc.phones.map((p) => p.number.trim()).where((p) => p.isNotEmpty).toList();
            if (dc.displayName.isNotEmpty || phones.isNotEmpty) {
              loaded.add(AppContact(
                id: dc.id,
                displayName: dc.displayName.isEmpty ? 'جهة اتصال بدون اسم' : dc.displayName,
                phones: phones,
              ));
            }
          } catch (itemErr) {
            _errorLogs.add('خطأ في قراءة: ${dc.displayName} -> $itemErr');
          }
        }

        setState(() {
          _rawContacts = loaded;
          _isLoading = false;
          _statusMessage = 'تم جلب ${_rawContacts.length} جهة اتصال بنجاح';
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'تم رفض الإذن. يرجى تفعيل إذن جهات الاتصال من إعدادات الهاتف.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'تعذر قراءة البيانات: $e';
        _errorLogs.add('System Error: $e');
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
        _errorLogs.add('خطأ أثناء معالجة ${item.displayName}: $err');
      }

      if (i % 20 == 0 || i == total - 1) {
        setState(() {
          _progressValue = (i + 1) / total;
          _statusMessage = 'جاري الفرز: تم فحص ${i + 1} من أصل $total جهة اتصال...';
        });
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }

    // دمج المتطابقات وإزالة التكرار مع توحيد الأرقام
    List<AppContact> merged = RulesEngine.deduplicateContacts(tempProcessed);

    setState(() {
      _processedContacts = merged;
      _tagStats = tags;
      _isLoading = false;
      _currentStep = 2;
      _statusMessage = 'اكتملت المعالجة! تم دمج الأسماء المتطابقة بنجاح.';
    });
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
                _buildStepHeader(2, '3. النتائج والتطبيق', Icons.check_circle),
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
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.amber[100],
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('تم تخطي ${_errorLogs.length} استثناء بأمان لضمان سلامة بياناتك.',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
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
                    label: const Text('إعادة المحاولة'),
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'تم دمج المتطابقات! إجمالي الأسماء بعد الدمج: ${_processedContacts.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            await ContactsService.exportToCsv(_processedContacts, '/sdcard/Download/app_smart_contacts.csv');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التصدير بنجاح إلى مجلد Download!')));
          },
          icon: const Icon(Icons.download),
          label: const Text('تصدير CSV النظيف'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
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
                subtitle: Text('EN: ${c.englishName}\nهواتف (${c.phones.length}): ${c.phones.join(", ")}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
