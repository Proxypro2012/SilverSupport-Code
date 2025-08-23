// lib/theme.dart

import 'package:flutter/material.dart';

class GlassTheme {
  // Glass container decoration
  static BoxDecoration glassContainer() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.25),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.4)),
    );
  }

  // Glass text style → default color now black
  static TextStyle textStyle({
    double size = 16,
    FontWeight weight = FontWeight.normal,
    Color color = Colors.black,
  }) {
    return TextStyle(color: color, fontSize: size, fontWeight: weight);
  }

  // Glass text field decoration → hint color black
  static InputDecoration glassTextFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black),
      filled: true,
      fillColor: Colors.white.withOpacity(0.2),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  // Glass button style → black text + black border
  static ButtonStyle glassButtonStyle({Color borderColor = Colors.white}) {
    return ElevatedButton.styleFrom(
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.white.withOpacity(0.2),
      foregroundColor: Colors.black, // <-- text color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}
