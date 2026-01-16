
import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'ui/theme.dart';

import 'services/oui_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OuiService.init();
  runApp(const CiberRadarApp());
}

class CiberRadarApp extends StatelessWidget {
  const CiberRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CiberRadar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const MainScreen(),
    );
  }
}
