import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/cart_item.dart';
import 'package:rios_pastries/data/models/reservation_model.dart';
import 'package:rios_pastries/data/models/user_model.dart';
import 'package:rios_pastries/data/repositories/cart_repository.dart';
import 'package:rios_pastries/data/services/reservation_service.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';
import 'package:rios_pastries/presentation/providers/cart_provider.dart';
import 'package:rios_pastries/presentation/screens/halls/hall_image.dart';
import 'package:rios_pastries/presentation/screens/reservations/reservation_create_page.dart';
import 'package:rios_pastries/presentation/screens/reservations/reservations_page.dart';

void main() {
  testWidgets('shows hall details and submits the selected card', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {
            'id': 4,
            'name': 'Sala principal',
            'venueName': 'Local central',
            'venue': {
              'id': 1,
              'name': 'Local central',
              'address': 'San Miguel Centro',
              'descripcion': '',
              'status': 'activo',
            },
            'image': 'image/upload/v1/sala.webp',
            'capacity': 100,
            'price': '125.50',
          },
          {'id': 5, 'name': 'Sala pequeña', 'capacity': 10},
        ],
      },
      {
        'statusCode': 201,
        'data': {..._createdReservationResponse(), 'sala': 5},
      },
    ]);
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local: Local central'), findsOneWidget);
    expect(find.text('Dirección: San Miguel Centro'), findsOneWidget);
    expect(find.text('Capacidad máxima: 100 personas'), findsOneWidget);
    expect(find.text('Precio: \$125.50'), findsOneWidget);
    expect(find.text('Precio: No disponible'), findsOneWidget);
    expect(
      tester.widgetList<HallImage>(find.byType(HallImage)).first.image,
      'image/upload/v1/sala.webp',
    );
    expect(find.text('Local: No disponible'), findsOneWidget);
    expect(find.text('Dirección: No disponible'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '5');
    await tester.ensureVisible(find.text('Guardar reservación'));
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona una sala.'), findsOneWidget);
    expect(adapter.requests, hasLength(1));

    await tester.ensureVisible(find.text('Sala principal'));
    await tester.tap(find.text('Sala principal'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona una sala.'), findsNothing);
    await tester.ensureVisible(find.text('Sala pequeña'));
    await tester.tap(find.text('Sala pequeña'));
    await tester.pumpAndSettle();
    final selectedCard = find
        .ancestor(of: find.text('Sala pequeña'), matching: find.byType(Card))
        .first;
    final selectedRadio = find.descendant(
      of: selectedCard,
      matching: find.byType(Radio<int>),
    );
    expect(tester.widget<Radio<int>>(selectedRadio).value, 5);
    expect(
      tester
          .widget<RadioGroup<int>>(
            find.ancestor(
              of: selectedRadio,
              matching: find.byType(RadioGroup<int>),
            ),
          )
          .groupValue,
      5,
    );
    await tester.ensureVisible(find.text('Guardar reservación'));
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();
    final data = adapter.requests.last.data;
    final payload = data is String ? jsonDecode(data) : data;
    expect(payload['sala'], 5);
    expect(find.text('Reservación creada'), findsOneWidget);
  });

  testWidgets('changes the reserved dates when choosing another hall', (
    tester,
  ) async {
    final now = DateTime.now();
    String date(int day) =>
        DateTime(now.year, now.month, day).toIso8601String().substring(0, 10);
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {
            'id': 4,
            'name': 'Sala uno',
            'reservedDates': [date(3)],
          },
          {
            'id': 5,
            'name': 'Sala dos',
            'reservedDates': [date(5)],
          },
          {'id': 6, 'name': 'Sala sin fechas'},
        ],
      },
    ]);
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Calendario'), findsNothing);

    final firstRadio = find.descendant(
      of: find
          .ancestor(of: find.text('Sala uno'), matching: find.byType(Card))
          .first,
      matching: find.byType(Radio<int>),
    );
    await tester.ensureVisible(firstRadio);
    await tester.tap(firstRadio);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Disponibilidad de Sala uno'));
    await tester.pumpAndSettle();

    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    Finder day(int number, String status) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label ==
              '$number de ${months[now.month - 1]} de ${now.year}, $status',
    );
    expect(day(3, 'bloqueado'), findsOneWidget);
    expect(day(5, 'sin reserva registrada'), findsOneWidget);

    await tester.ensureVisible(find.text('Sala dos'));
    await tester.tap(find.text('Sala dos'));
    await tester.pumpAndSettle();
    expect(find.text('Disponibilidad de Sala dos'), findsOneWidget);
    expect(day(3, 'sin reserva registrada'), findsOneWidget);
    expect(day(5, 'bloqueado'), findsOneWidget);

    await tester.ensureVisible(find.text('Sala sin fechas'));
    await tester.tap(find.text('Sala sin fechas'));
    await tester.pumpAndSettle();
    expect(
      find.text('No hay información de fechas bloqueadas.'),
      findsOneWidget,
    );
    expect(adapter.requests, hasLength(1));
  });

  testWidgets('filters reservations by confirmed and finished statuses', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          _listedReservation(1, 'CONFIRMADA'),
          _listedReservation(2, 'FINALIZADA'),
          _listedReservation(3, 'CANCELADA'),
        ],
      },
    ]);
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReservationsPage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Finalizada'), findsNothing);
    expect(find.text('Cancelada'), findsNothing);

    await tester.tap(find.text('Finalizadas'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Finalizada'), findsOneWidget);

    await tester.tap(find.text('Finalizadas'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Finalizada'), findsNothing);
  });

  testWidgets('shows the server hall error and clears it on a new selection', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala uno'},
          {'id': 5, 'name': 'Sala dos'},
        ],
      },
      {
        'statusCode': 400,
        'data': {
          'sala': ['La sala no está disponible.'],
        },
      },
    ]);
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '5');
    await tester.tap(find.text('Sala uno'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar reservación'));
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ocurrió un error'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('La sala no está disponible.'), findsOneWidget);

    await tester.ensureVisible(find.text('Sala dos'));
    await tester.tap(find.text('Sala dos'));
    await tester.pumpAndSettle();
    expect(find.text('La sala no está disponible.'), findsNothing);
  });

  testWidgets('shows a dialog when halls fail to load and allows retry', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 503,
        'data': {'detail': 'server detail'},
      },
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal'},
        ],
      },
    ]);
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ocurrió un error'),
      ),
      findsOneWidget,
    );
    expect(find.text('server detail'), findsNothing);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Sala principal'), findsOneWidget);
    expect(adapter.requests, hasLength(2));
  });

  testWidgets('shows a dialog on save failure and permits a retry', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal'},
        ],
      },
      {
        'statusCode': 503,
        'data': {'detail': 'server detail'},
      },
      {'statusCode': 201, 'data': _createdReservationResponse()},
    ]);
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala principal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '5');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar reservación'));
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ocurrió un error'),
      ),
      findsOneWidget,
    );
    expect(find.text('server detail'), findsNothing);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Reservación creada'), findsOneWidget);
    expect(adapter.requests, hasLength(3));
  });

  testWidgets('shows a dialog when a cart action fails', (tester) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal'},
        ],
      },
    ]);
    final auth = _AuthenticatedAuthController();
    final provider = CartProvider(
      authController: auth,
      repository: _FailingCartRepository([
        _cartItem(id: 1, productId: 1, name: 'Pastel', price: '25.00'),
      ]),
    );
    addTearDown(provider.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: auth,
          cartProvider: provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adjuntar los productos del carrito'));
    await tester.tap(find.text('Adjuntar los productos del carrito'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Eliminar producto'));
    await tester.tap(find.byTooltip('Eliminar producto'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ocurrió un error'),
      ),
      findsOneWidget,
    );
    expect(provider.items, hasLength(1));
  });

  testWidgets('rejects attendee counts above the selected hall capacity', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal', 'capacity': 2},
        ],
      },
    ]);
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala principal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '3');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar reservación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();

    expect(
      find.text('La sala "Sala principal" tiene capacidad para 2 personas.'),
      findsOneWidget,
    );
    expect(adapter.requests, hasLength(1));
  });

  testWidgets('shows the shared cart without quantity controls or API fetch', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal', 'capacity': 100},
        ],
      },
    ]);
    final cart = _createCartProvider([
      _cartItem(
        id: 1,
        productId: 1,
        name: 'Pastel',
        price: '25.00',
        quantity: 2,
      ),
      _cartItem(
        id: 2,
        productId: 2,
        name: 'Mesa extra',
        price: '10.00',
        isAvailable: false,
      ),
    ]);
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Adjuntar los productos del carrito'));
    await tester.tap(find.text('Adjuntar los productos del carrito'));
    await tester.pumpAndSettle();
    expect(find.text('Pastel'), findsOneWidget);
    expect(find.text('\$25.00 c/u'), findsOneWidget);
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('Subtotal: \$50.00'), findsOneWidget);
    expect(find.text('Total: \$50.00'), findsOneWidget);
    expect(find.byTooltip('Aumentar cantidad'), findsNothing);
    expect(find.byTooltip('Disminuir cantidad'), findsNothing);
    expect(find.text('2'), findsNothing);

    await tester.tap(find.text('Solo crear reservación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjuntar los productos del carrito'));
    await tester.pumpAndSettle();
    expect(find.text('Subtotal: \$50.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar producto').first);
    await tester.pumpAndSettle();
    expect(find.text('Pastel'), findsNothing);
    expect(find.text('Mesa extra'), findsOneWidget);
    expect(find.text('Total: \$0.00'), findsOneWidget);
    expect(adapter.requests.map((request) => request.uri.path), [
      '/api/halls/',
    ]);
  });

  testWidgets('clears the shared cart after creating with products selected', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal', 'capacity': 100},
        ],
      },
      {'statusCode': 201, 'data': _createdReservationResponse()},
    ]);
    final cart = _createCartProvider([
      _cartItem(id: 1, productId: 1, name: 'Pastel', price: '25.00'),
    ]);
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala principal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '5');
    await tester.ensureVisible(find.text('Adjuntar los productos del carrito'));
    await tester.tap(find.text('Adjuntar los productos del carrito'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();

    expect(find.text('Reservación creada'), findsOneWidget);
    expect(cart.provider.items, isEmpty);
    expect(adapter.requests.last.method, 'POST');
  });

  testWidgets(
    'keeps the shared cart after creating without products selected',
    (tester) async {
      final adapter = _ReservationAdapter([
        {
          'statusCode': 200,
          'data': [
            {'id': 4, 'name': 'Sala principal', 'capacity': 100},
          ],
        },
        {'statusCode': 201, 'data': _createdReservationResponse()},
      ]);
      final cart = _createCartProvider([
        _cartItem(id: 1, productId: 1, name: 'Pastel', price: '25.00'),
      ]);
      addTearDown(cart.provider.dispose);
      addTearDown(cart.auth.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ReservationCreatePage(
            authController: cart.auth,
            cartProvider: cart.provider,
            reservationService: ReservationService(
              dio: _dioWithAdapter(adapter),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sala principal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '5');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar reservación'));
      await tester.tap(find.text('Guardar reservación'));
      await tester.pumpAndSettle();

      expect(find.text('Reservación creada'), findsOneWidget);
      expect(cart.provider.items, hasLength(1));
      expect(cart.provider.items.single.name, 'Pastel');
    },
  );

  testWidgets('rejects zero attendees before sending a reservation', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal'},
        ],
      },
    ]);
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          authController: cart.auth,
          cartProvider: cart.provider,
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.ensureVisible(find.text('Guardar reservación'));
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();

    expect(find.text('La cantidad debe ser mayor que cero.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
  });

  testWidgets('allows saving an unchanged past date when editing', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal'},
        ],
      },
      {
        'statusCode': 200,
        'data': {'id': 12},
      },
    ]);
    final reservation = ReservationModel(
      id: 12,
      fechaEvento: DateTime(2020, 1, 2),
      cantidadPersonas: 3,
      salaId: 4,
      estado: 'CONFIRMADA',
      hall: HallModel(id: 4, hallName: 'Sala principal'),
      venue: VenueModel(name: 'Local', address: '', descripcion: ''),
    );
    final cart = _createCartProvider();
    addTearDown(cart.provider.dispose);
    addTearDown(cart.auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ReservationCreatePage(
                      authController: cart.auth,
                      cartProvider: cart.provider,
                      reservation: reservation,
                      reservationService: ReservationService(
                        dio: _dioWithAdapter(adapter),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Abrir formulario'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
    expect(find.text('Editar reservación'), findsOneWidget);
    expect(
      tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
      4,
    );
    await tester.ensureVisible(find.text('Guardar reservación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();

    expect(adapter.requests.map((request) => request.method), ['GET', 'PATCH']);
    expect(adapter.requests.last.uri.path, '/api/reservations/12/');
  });
}

({AuthController auth, CartProvider provider}) _createCartProvider([
  List<CartItem> items = const [],
]) {
  final auth = _AuthenticatedAuthController();
  final provider = CartProvider(
    authController: auth,
    repository: _MemoryCartRepository(items),
  );
  return (auth: auth, provider: provider);
}

CartItem _cartItem({
  required int id,
  required int productId,
  required String name,
  required String price,
  bool isAvailable = true,
  int quantity = 1,
}) {
  return CartItem(
    id: id,
    userId: 1,
    productId: productId,
    name: name,
    price: price,
    image: null,
    quantity: quantity,
    isAvailable: isAvailable,
    createdAt: DateTime(2026),
  );
}

Map<String, dynamic> _createdReservationResponse() => {
  'id': 12,
  'fecha_evento': '2026-12-20',
  'cantidad_personas': 5,
  'sala': 4,
  'estado': 'CONFIRMADA',
  'hallName': 'Sala principal',
  'venueName': 'Local',
  'total_productos': '25.00',
  'items': [],
};

Map<String, dynamic> _listedReservation(int id, String status) => {
  'id': id,
  'fecha_evento': '2026-12-${id.toString().padLeft(2, '0')}',
  'cantidad_personas': 5,
  'sala': 4,
  'estado': status,
  'hallName': 'Sala principal',
  'venueName': 'Local',
  'hall': null,
  'venue': null,
};

Dio _dioWithAdapter(_ReservationAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.example.test/api/',
      validateStatus: (status) => status != null && status < 300,
    ),
  )..httpClientAdapter = adapter;
}

class _AuthenticatedAuthController extends AuthController {
  @override
  bool get isAuthenticated => true;

  @override
  UserModel? get currentUser =>
      const UserModel(id: '1', email: 'test@example.com', name: 'Test');
}

class _MemoryCartRepository extends CartRepository {
  _MemoryCartRepository(List<CartItem> items) : _items = List.of(items);

  final List<CartItem> _items;

  @override
  Future<List<CartItem>> getItems(int userId) async => List.of(_items);

  @override
  Future<void> updateQuantity(int userId, int productId, int quantity) async {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) _items[index] = _items[index].copyWith(quantity: quantity);
  }

  @override
  Future<void> removeProduct(int userId, int productId) async {
    _items.removeWhere((item) => item.productId == productId);
  }

  @override
  Future<void> clearCart(int userId) async {
    _items.clear();
  }
}

class _FailingCartRepository extends _MemoryCartRepository {
  _FailingCartRepository(super.items);

  @override
  Future<void> removeProduct(int userId, int productId) async {
    throw Exception('Error de prueba');
  }
}

class _ReservationAdapter implements HttpClientAdapter {
  _ReservationAdapter(this._responses);

  final List<Map<String, dynamic>> _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response['data']),
      response['statusCode'] as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
