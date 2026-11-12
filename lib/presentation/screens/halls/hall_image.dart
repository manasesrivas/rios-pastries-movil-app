import 'package:flutter/material.dart';

import '../../../core/utils/image_url.dart';

class HallImage extends StatelessWidget {
  final String? image;
  final double width;
  final double height;

  const HallImage({
    super.key,
    required this.image,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final url = resolveImageUrl(image);
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.meeting_room_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    if (url == null) return placeholder;

    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('No se pudo cargar la imagen de la sala: $error');
        return placeholder;
      },
    );
  }
}
