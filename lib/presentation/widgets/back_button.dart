import 'package:flutter/material.dart';

class BackButtonOverlay extends StatelessWidget {
  const BackButtonOverlay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
      ),
    );
  }
}