import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'register.dart'; // Import halaman Register
import 'login.dart';   // Import halaman Login
import 'package:ecomweb/utils/supabase_init.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null); // Inisialisasi format tanggal untuk Indonesia
  await SupabaseInit.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(), // Halaman awal adalah RegisterPage
      routes: {
        '/login': (context) => LoginPage(), // Route untuk halaman Login
      },
    );
  }
}