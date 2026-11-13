# Ríos Pastries

Aplicación móvil de pastelería hecha con Flutter. Permite consultar productos,
administrar un carrito local por usuario autenticado, revisar órdenes y realizar
pedidos mediante una API Django REST Framework.

## Funcionalidades

### Navegación

La aplicación cuenta con una barra de navegación inferior:

- **Inicio:** catálogo de productos.
- **Órdenes:** historial de órdenes del usuario autenticado.
- **Reservas:** consulta y creación de reservaciones.
- **Salas:** salas registradas y detalles de su local.
- **Perfil:** datos disponibles de la cuenta y cierre de sesión.

El carrito está disponible desde la barra superior. El catálogo se puede consultar sin iniciar sesión. Las funciones que dependen de
la cuenta solicitan autenticación cuando es necesario.

### Autenticación y perfil

- Inicio de sesión conectado al servicio de autenticación de la API.
- Persistencia local del token y los datos del usuario mediante
  `shared_preferences`.
- Recuperación de la sesión guardada al iniciar la app.
- Renovación automática del token de acceso ante HTTP 401 con código
  `token_not_valid`: se envía el refresh a `authentication/token/refresh/`,
  se guardan los tokens recibidos y se repite una vez la solicitud original.
  Los cuerpos multipart o de flujo no se repiten automáticamente.
- Si el refresh es inválido, se limpia la sesión; ante errores de red o del
  servidor se conserva para poder reintentar.
- Cierre de sesión con confirmación.
- Perfil con ID, nombre, correo electrónico y rol disponibles en el usuario.
- El carrito local se conserva al cerrar sesión y se muestra separado por ID de
  usuario.
- Los fallos inesperados muestran «Ocurrió un error»; los detalles se registran
  con `debugPrint`, sin imprimir tokens. Las validaciones conservan sus mensajes.

### Productos

- Consulta del catálogo desde Django REST Framework.
- Pantalla de detalle con imagen, categoría, estado, precio y descripción.
- Las imágenes admiten URL completas, rutas relativas del backend y rutas de
  Cloudinary como `image/upload/...`. Para estas últimas, configura
  `cloudinaryCloudName` en `ApiConstants` con el nombre de tu nube.
- Selección de cantidad y acción para agregar el producto disponible al carrito.
- Manejo de carga, error y reintento para el catálogo.

### Carrito local

El carrito se guarda con SQLite mediante `sqflite`; la base de datos se conserva
entre ejecuciones de la app. Cada registro se asocia al ID del usuario y la
combinación de usuario y producto es única.

- Agregar productos e incrementar la cantidad si ya estaban en el carrito.
- Aumentar o disminuir cantidades, eliminar un producto y vaciar el carrito.
- Mostrar el subtotal y total de productos disponibles.
- Indicador con la cantidad de artículos en el botón del carrito.
- Mostrar productos no disponibles sin incluirlos en el total.
- Actualizar la disponibilidad al cargar o refrescar el catálogo.
- Para agregar al carrito o consultar el contenido es necesario iniciar sesión.

### Órdenes y checkout

- Consulta de las órdenes del usuario autenticado, con actualización manual.
- Detalle de una orden con estado, fecha, hora, entrega, pago, importes y
  productos.
- Fecha del detalle en formato `día/mes/año` y hora en formato de 12 horas.
- El botón **Realizar pedido** se desactiva si el carrito está vacío, se está
  cargando o contiene productos no disponibles.
- Antes de crear el pedido, se valida la disponibilidad en el backend.
- Si la validación es exitosa, se puede seleccionar:
  - Pago: `tarjeta` o `efectivo`.
  - Entrega: `domicilio` o `recojer` (valor requerido por el backend).
- El carrito se vacía solamente cuando la API confirma que creó el pedido.
- Los errores HTTP 409 actualizan SQLite en una transacción:
  - `PRODUCT_INACTIVE`: el producto permanece en el carrito y se marca como no
    disponible.
  - `PRODUCT_NOT_FOUND`: se elimina el registro de ese producto.
  - Los demás productos y los carritos de otros usuarios no se modifican.
- Los productos afectados se muestran con el mensaje devuelto por la API y deben
  eliminarse del carrito antes de volver a intentar.

### Reservaciones

- Consulta, creación y edición de reservaciones para el usuario autenticado.
- El formulario carga las salas desde `halls/` y crea o actualiza mediante
  `reservations/` y `reservations/<id>/`. Ajusta la ruta `halls/` en
  `ApiConstants` si el backend expone otra URL.
- Las salas se eligen mediante tarjetas con imagen, local, dirección y
  capacidad máxima.
- Valida fecha no pasada, cantidad positiva y sala obligatoria; los errores 400
  del backend se muestran junto al campo correspondiente.
- En edición permite conservar una fecha pasada sin cambios y muestra
  `total_productos` como dato de solo lectura.
- La solicitud no envía `cliente`; el backend lo asigna desde el usuario
  autenticado. `estado` al crear se envía como `CONFIRMADA`.

### Salas

- Consulta las salas desde `halls/` con sesión iniciada, recarga y reintento.
- Cada sala muestra los datos del local incluidos en la misma respuesta, sin
  realizar una solicitud adicional para el local.
- El detalle muestra un calendario con las fechas de `reservedDates` marcadas
  como bloqueadas. Si no se recibe ese campo, indica que no hay información.
  El calendario es informativo y no modifica el formulario de reservación.

## Requisitos

- Flutter y Dart compatibles con las versiones declaradas en `pubspec.yaml`.
- API Django REST Framework accesible desde el dispositivo.
- SQLite mediante `sqflite` en Android o iOS.

## Configuración y ejecución

1. Instala las dependencias:

   ```sh
   flutter pub get
   ```

2. Configura `baseUrl` en
   [`lib/core/constants/api_constants.dart`](lib/core/constants/api_constants.dart)
   para que apunte a tu API.

   - En el emulador Android normalmente se usa `http://10.0.2.2:<puerto>/api/`
     para llegar al servidor de desarrollo de la computadora.
   - En un dispositivo físico, usa la IP local de la computadora y asegúrate de
     que ambos estén en la misma red.
   - `127.0.0.1` apunta al propio dispositivo/emulador, no a la computadora
     desde la que se ejecuta Flutter.

3. Ejecuta la aplicación:

   ```sh
   flutter run
   ```

El endpoint de login, el token y las rutas de productos y órdenes se configuran
en `ApiConstants`. Dio agrega el token guardado a las solicitudes autenticadas.

## Contrato de checkout con el backend

La app usa las siguientes rutas:

### Validación de disponibilidad

`POST orders/validate/`

```json
{
  "items": [
    { "product_id": 1, "quantity": 2 },
    { "product_id": 5, "quantity": 1 }
  ]
}
```

Respuesta válida esperada:

```json
{
  "code": "CART_VALID",
  "message": "Todos los productos están disponibles.",
  "valid": true
}
```

Si hay productos no disponibles, la app espera HTTP 409 y una respuesta con
`code: "CART_UNAVAILABLE_PRODUCTS"` y una lista `errors` con `product_id`, `code`
y `message`. Los códigos de producto reconocidos son `PRODUCT_NOT_FOUND` y
`PRODUCT_INACTIVE`.

### Creación de la orden

`POST orders/`

```json
{
  "items": [
    { "product_id": 1, "quantity": 2 },
    { "product_id": 5, "quantity": 1 }
  ],
  "metodo_pago": "efectivo",
  "tipo_entrega": "recojer"
}
```

El endpoint de creación también debe validar nuevamente la disponibilidad y
crear la orden y sus detalles dentro de una transacción atómica en Django. La
app maneja un HTTP 409 de esta segunda validación del mismo modo que uno recibido
desde `orders/validate/`.

## Pruebas

Ejecuta todas las pruebas con:

```sh
flutter test
```

Las pruebas cubren el parseo de órdenes, las operaciones SQLite y el aislamiento
por usuario, el payload de checkout, el manejo de errores 409 y el renderizado
básico de la app.

## Alcance actual

- Avisos/notificaciones todavía no tienen una pantalla funcional.
- El formulario de checkout aún no solicita ni envía una dirección para entrega
  a domicilio; actualmente solo envía `items`, `metodo_pago` y `tipo_entrega`.
- La confirmación final del pedido y la segunda validación atómica dependen de la
  implementación del endpoint en Django.
- La persistencia del carrito con `sqflite` está destinada a Android e iOS.
