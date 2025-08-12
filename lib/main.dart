import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'page/login_page.dart';

void main() {
  runApp(const AbsensiProApp());
}

class AbsensiProApp extends StatelessWidget {
  const AbsensiProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
