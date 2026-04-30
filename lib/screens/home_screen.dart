import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: <Widget>[
          // Other widgets
          // ... 

          // Replace withOpacity at line 254
          Container(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
          ),

          // Replace withOpacity at line 356
          Container(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
          ),

          // Replace withOpacity at line 408
          Container(
            color: color.withOpacity(0.12),
          ),
        ],
      ),
    );
  }
}