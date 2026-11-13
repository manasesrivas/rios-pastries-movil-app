import 'package:flutter/material.dart';

class HallCalendar extends StatefulWidget {
  const HallCalendar({super.key, required this.reservedDates});

  final List<DateTime>? reservedDates;

  @override
  State<HallCalendar> createState() => _HallCalendarState();
}

class _HallCalendarState extends State<HallCalendar> {
  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _weekdays = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _month = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final dates = widget.reservedDates;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calendario', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (dates == null)
              const Text('No hay información de fechas bloqueadas.')
            else ...[
              Row(
                children: [
                  IconButton(
                    tooltip: 'Mes anterior',
                    onPressed: _month.year == 1 && _month.month == 1
                        ? null
                        : () => setState(() {
                            _month = DateTime(_month.year, _month.month - 1);
                          }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${_months[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mes siguiente',
                    onPressed: _month.year == 9999 && _month.month == 12
                        ? null
                        : () => setState(() {
                            _month = DateTime(_month.year, _month.month + 1);
                          }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Row(
                children: _weekdays.map((day) => Expanded(
                  child: Semantics(
                    label: day,
                    excludeSemantics: true,
                    child: Text(day[0], textAlign: TextAlign.center),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
              _buildDays(dates, colors),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.circle, size: 14, color: colors.error),
                  const SizedBox(width: 8),
                  const Text('Fecha bloqueada'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDays(List<DateTime> dates, ColorScheme colors) {
    final reserved = dates.map(DateUtils.dateOnly).toSet();
    final firstWeekday = DateTime(_month.year, _month.month).weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final cellCount = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        final day = index - firstWeekday + 1;
        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
        final blocked = reserved.contains(DateTime(_month.year, _month.month, day));
        return Semantics(
          label: '$day de ${_months[_month.month - 1]} de ${_month.year}, '
              '${blocked ? 'bloqueado' : 'sin reserva registrada'}',
          excludeSemantics: true,
          child: Center(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: blocked ? colors.error : null,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  color: blocked ? colors.onError : colors.onSurface,
                  fontWeight: blocked ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
