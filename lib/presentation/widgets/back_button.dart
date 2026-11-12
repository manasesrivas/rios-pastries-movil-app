import 'package:flutter/material.dart';

class BackButtonOverlay extends StatelessWidget {
  const BackButtonOverlay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: const CircleBorder(),
          elevation: 2,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
      ),
    );
  }
}