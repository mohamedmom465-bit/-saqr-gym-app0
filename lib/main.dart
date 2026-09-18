import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'screens/home_screen.dart';
import 'screens/inbody_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'services/feedback.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await store.init();
  runApp(const SaqrGymApp());
}

class SaqrGymApp extends StatelessWidget {
  const SaqrGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAQR GYM',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;

  final _pages = const [
    HomeScreen(),
    ReportsScreen(),
    InBodyScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        body: IndexedStack(index: index, children: _pages),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: C.bg,
            border: Border(top: BorderSide(color: C.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  _navItem(0, '🏠', 'الرئيسية'),
                  _navItem(1, '📊', 'التقارير'),
                  _navItem(2, '🧬', 'InBody'),
                  _navItem(3, '⚙️', 'التعديل'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, String icon, String label) {
    final active = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: TextStyle(fontSize: active ? 20 : 18)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: active ? C.accent : C.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
