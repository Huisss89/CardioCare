import 'package:flutter/material.dart';

// Helper Widget (Put this anywhere outside your State classes, e.g., after saveReadingToFirestore)
class FingerPlacementGuide extends StatelessWidget {
  final bool isFingerPresent;
  // Use a variable to hold the path to your asset image
  final String imagePath ='C:/Users/60195/Downloads/Screenshot 2026-02-14 153420.png';

  const FingerPlacementGuide({super.key, required this.isFingerPresent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Put your index finger on one of the back cameras',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFingerPresent
                ? 'Signal is good. Tap START to measure.'
                : 'Cover the camera lens and flash completely so the heart turns red.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 16),
          // --- STATIC IMAGE GUIDE ---
          Center(
            child: Container(
              height: 200, // Adjust height as needed
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: AssetImage(imagePath), // Reference the asset path
                  fit: BoxFit.contain,
                ),
              ),
              // We overlay the text prompt onto the image container
              child: const Center(
                  // You can optionally put the text like "Cover the camera" here
                  ),
            ),
          ),
          // --- END STATIC IMAGE GUIDE ---
        ],
      ),
    );
  }
}
