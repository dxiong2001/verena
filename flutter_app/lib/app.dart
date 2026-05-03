import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class Verena extends StatelessWidget {
  const Verena({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verena',
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              /// Fake window border
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Container(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: child!,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
