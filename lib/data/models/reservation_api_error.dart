class ReservationApiItemError {
  final int? productId;
  final String name;
  final String error;

  const ReservationApiItemError({
    this.productId,
    this.name = '',
    required this.error,
  });

  factory ReservationApiItemError.fromJson(dynamic value) {
    if (value is String) return ReservationApiItemError(error: value);
    if (value is! Map) {
      return ReservationApiItemError(
        error: value?.toString() ?? 'Error de producto desconocido.',
      );
    }

    return ReservationApiItemError(
      productId: _toInt(value['product_id'] ?? value['productId']),
      name: value['name']?.toString() ?? '',
      error: _errorText(value['error']),
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'error': error,
  };
}

class ReservationApiError {
  final Map<String, List<String>> fieldErrors;
  final List<String> nonFieldErrors;
  final List<ReservationApiItemError> itemErrors;

  const ReservationApiError({
    this.fieldErrors = const {},
    this.nonFieldErrors = const [],
    this.itemErrors = const [],
  });

  factory ReservationApiError.fromJson(dynamic value) {
    if (value is! Map) {
      return ReservationApiError(
        nonFieldErrors: [value?.toString() ?? 'Error inesperado del servidor.'],
      );
    }

    final fieldErrors = <String, List<String>>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (key == 'items' ||
          key == 'non_field_errors' ||
          key == 'detail' ||
          key == 'message') {
        continue;
      }
      final messages = _stringList(entry.value);
      if (messages.isNotEmpty) fieldErrors[key] = messages;
    }

    final rawItems = value['items'];
    final itemErrors = rawItems is List
        ? rawItems.map(ReservationApiItemError.fromJson).toList()
        : rawItems is String
        ? [ReservationApiItemError(error: rawItems)]
        : <ReservationApiItemError>[];

    final nonFieldErrors = _stringList(
      value['non_field_errors'] ?? value['detail'] ?? value['message'],
    );

    return ReservationApiError(
      fieldErrors: fieldErrors,
      nonFieldErrors: nonFieldErrors,
      itemErrors: itemErrors,
    );
  }

  Map<String, dynamic> toJson() => {
    ...fieldErrors,
    if (nonFieldErrors.isNotEmpty) 'non_field_errors': nonFieldErrors,
    if (itemErrors.isNotEmpty)
      'items': itemErrors.map((item) => item.toJson()).toList(),
  };
}

class ReservationApiException implements Exception {
  final ReservationApiError error;

  const ReservationApiException(this.error);

  @override
  String toString() => 'La API rechazó la reservación.';
}

List<String> _stringList(dynamic value) {
  if (value == null) return [];
  if (value is Iterable) {
    return value.expand(_stringList).toList();
  }
  if (value is Map) {
    return value.values.expand(_stringList).toList();
  }
  return [value.toString()];
}

String _errorText(dynamic value) => _stringList(value).join(' ');

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
