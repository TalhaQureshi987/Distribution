// lib/screens/donor/donation_widgets/HeroBanner.dart
import 'package:flutter/material.dart';

class HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color cardColor = const Color(0xFFD6B6A4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          image: DecorationImage(
            image: AssetImage('images/donations2.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              cardColor.withOpacity(0.25),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Support a Cause",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black26)],
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: Colors.yellow[700],
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Over 1,000,000 PKR donated this month!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black26),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}