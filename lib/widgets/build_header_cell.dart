import 'package:flutter/material.dart';

class BuildHeaderCell extends StatelessWidget {
  final String text;
  final TextAlign alignment;
  final int flex;

  // Corrected Const Constructor
  const BuildHeaderCell({
    Key? key,
    required this.text,
    this.alignment = TextAlign.center,
    required this.flex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignment,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF718096),
        ),
      ),
    );
  }
}
