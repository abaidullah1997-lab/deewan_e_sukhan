import 'package:flutter/material.dart';

void main() => runApp(const DeewanApp());

class DeewanApp extends StatelessWidget {
  const DeewanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دیوانِ سخن',
      theme: ThemeData.dark(useMaterial3: true),
      home:  Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: Text('دیوانِ سخن')),
          body: Center(
            child: Text('دیوانِ سخن میں خوش آمدید',
              style: TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}
