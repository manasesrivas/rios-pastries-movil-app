import 'package:flutter/material.dart';

import '../../../data/models/reservation_model.dart';
import 'hall_image.dart';

class HallDetailScreen extends StatelessWidget {
  final HallModel hall;

  const HallDetailScreen({super.key, required this.hall});

  @override
  Widget build(BuildContext context) {
    final venue = hall.venue;
    return Scaffold(
      appBar: AppBar(title: Text(hall.hallName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: HallImage(
              image: hall.image,
              width: double.infinity,
              height: 200,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sala', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Capacidad',
                    value: hall.capacity == null
                        ? null
                        : '${hall.capacity} personas',
                  ),
                  _DetailRow(
                    label: 'Precio',
                    value: hall.price == null
                        ? null
                        : '\$${hall.price!.toStringAsFixed(2)}',
                  ),
                  _DetailRow(label: 'Estado', value: hall.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Nombre',
                    value: venue?.name.isNotEmpty == true
                        ? venue!.name
                        : hall.venueName,
                  ),
                  _DetailRow(label: 'Dirección', value: venue?.address),
                  _DetailRow(label: 'Descripción', value: venue?.descripcion),
                  _DetailRow(label: 'Estado', value: venue?.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Text(text == null || text.isEmpty ? 'No disponible' : text),
        ],
      ),
    );
  }
}
