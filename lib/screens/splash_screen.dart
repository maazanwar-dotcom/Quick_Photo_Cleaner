import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/splash_screen_bg.png', fit: BoxFit.cover),
          Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // or MainAxisAlignment.start
              children: [
                SizedBox(height: 400), // Adjust this value to move content down
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Quick Photo Cleaner",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 40),
                    CircularProgressIndicator(color: Colors.indigoAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
