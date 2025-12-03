import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navic_ss/screens/home_screen.dart';

//import 'services/permission_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NavIC Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

