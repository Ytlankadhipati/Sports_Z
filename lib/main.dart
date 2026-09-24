import 'package:flutter/material.dart';

void main() {
  runApp(const SportsZApp());
}

class SportsZApp extends StatelessWidget {
  const SportsZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SportsZ',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SportsZ'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_soccer,
                size: 80,
              ),
              SizedBox(height: 20),
              Text(
                'SportsZ is Running!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Flutter Emulator Test Successful ✅',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}