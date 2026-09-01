import 'package:flutter/material.dart';
import 'ui/smart_wizard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartContactsApp());
}

class SmartContactsApp extends StatelessWidget {
  const SmartContactsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مدير جهات الاتصال الذكي',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SmartWizardScreen(),
    );
  }
}
