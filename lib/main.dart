import 'package:flutter/material.dart';
import 'ui/flutter_dashboard_screen.dart';
import 'core/contact_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Contacts',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: ContactsDashboardScreen(
        contacts: [
          AppContact(id: '1', displayName: 'د. عيادة الأمل', phones: ['0790000000']),
        ],
        tagStats: {'MED': 1, 'GEN': 0},
        staleCandidates: [],
        onSync: () {},
        onExport: () {},
      ),
    );
  }
}
