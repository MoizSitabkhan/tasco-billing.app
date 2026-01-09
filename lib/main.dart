import 'package:flutter/material.dart';
import 'screens/items_screen.dart';
import 'screens/create_bill_screen.dart';

void main() {
  runApp(const MyApp());
}

const Color appPrimaryColor = Color(0xFF7C4DFF);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: appPrimaryColor,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: appPrimaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      home: const ItemsScreen(),
      routes: {
        '/bill': (context) => const CreateBillScreen(),
      },
    );
  }
}
