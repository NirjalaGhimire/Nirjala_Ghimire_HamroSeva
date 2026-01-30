import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const HamroSevaApp());
}

class HamroSevaApp extends StatelessWidget {
  const HamroSevaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String msg = "Checking backend...";

  @override
  void initState() {
    super.initState();

    ApiService.healthCheck().then((data) {
      setState(() => msg = data["message"]?.toString() ?? "OK");
    }).catchError((e) {
      setState(() => msg = "Error: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("HamroSeva")),
      body: Center(child: Text(msg, style: const TextStyle(fontSize: 18))),
    );
  }
}
