# ATENAS — Sistema de Información
## Especificación Funcional v1.0
### Ingeniería de Software — Proyecto Final UTN

---

> **Estado del documento:** Cerrado — Relevamiento completo, pendientes resueltos  
> **Última actualización:** Junio 2025  
> **Próxima etapa:** Modelo de Dominio y Diseño de Base de Datos

---

## 1. CONTEXTO DEL NEGOCIO

ATENAS es una empresa de marketing y venta directa que actúa como **intermediario comercial** entre proveedores de servicios (clínicas dentales, veterinarias, automotrices, entre otras) y el público general.

Los proveedores definen planes anuales de servicios y fijan su precio. ATENAS los vende mediante vendedores en puntos de venta ubicados en centros comerciales, vía pública y espacios públicos de alta circulación. El cliente no busca el producto: es abordado por el vendedor.

**El producto es un cupón físico** impreso previamente, asociado a una clínica desde su impresión. El cupón tiene dos partes separadas por una perforación: una mitad para el cliente y una mitad para el vendedor. Ambas partes se completan manualmente al momento de la venta.

La empresa opera actualmente en **Chile** (norte a sur) y está iniciando operaciones en **Argentina**.

---

## 2. ACTORES DEL SISTEMA

| Actor | Descripción |
|---|---|
| **Vendedor** | Realiza ventas en campo. Registra la venta en el sistema y sube el comprobante fotográfico. |
| **Líder de Equipo** | También es vendedor. Supervisa un equipo. Comisiona por sus ventas individuales y por las ventas de su equipo. Asigna cupones físicos a sus vendedores. |
| **Secretario de Ventas** | Valida las ventas revisando las imágenes. Transcribe los datos del cliente al sistema. Envía la lista de clientes validados a cada clínica. |
| **Tesorero** | Registra los pagos semanales a vendedores. Accede a reportes financieros completos. Configura la tabla de comisiones junto con gerencia. |
| **Encargado de Juegos** | Accede a estadísticas de ventas (solo lectura). Gestiona los juegos diarios y registra premios. |
| **Gerencia** | Control total del sistema. Gestiona todas las entidades, campañas, usuarios, configuraciones y reportes. |
| **Cliente** | No es usuario del sistema. Sus datos son ingresados por el Secretario de Ventas al validar una venta. |

### 2.1 Matriz de Permisos

| Funcionalidad | Vendedor | Líder | Secretario | Tesorero | Enc. Juegos | Gerencia |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Registrar propia venta | ✅ | ✅ | — | — | — | — |
| Ver propias ventas | ✅ | ✅ | — | — | — | ✅ |
| Ver ventas del equipo | — | ✅ | — | — | — | ✅ |
| Ver todas las ventas | — | — | ✅ | ✅ | ✅ (lectura) | ✅ |
| Validar ventas | — | — | ✅ | — | — | — |
| Ingresar datos de cliente | — | — | ✅ | — | — | — |
| Exportar lista a clínicas | — | — | ✅ | — | — | ✅ |
| Registrar traspaso de venta | — | TBD | ✅ | — | — | ✅ |
| Ver propia comisión | ✅ | ✅ | — | — | — | ✅ |
| Ver comisiones de equipo | — | ✅ | — | — | — | ✅ |
| Ver todas las comisiones | — | — | — | ✅ | — | ✅ |
| Registrar pagos a vendedores | — | — | — | ✅ | — | ✅ |
| Ver reportes financieros | — | — | — | ✅ | — | ✅ |
| Asignar cupones a vendedores | — | ✅ | — | — | — | ✅ |
| Registrar ingreso de cupones | — | — | — | — | — | ✅ |
| Gestionar usuarios y entidades | — | — | — | — | — | ✅ |
| Activar/desactivar cupones | — | — | — | — | — | ✅ |
| Configurar tabla de comisiones | — | — | — | ✅ | — | ✅ |
| Gestionar juegos | — | — | — | — | ✅ | ✅ |

> **TBD:** Pendiente de definición si el líder puede autorizar traspasos.

---

## 3. REQUISITOS FUNCIONALES

### RF-010 — Módulo de Registro de Venta (Vendedor)

**RF-011** El sistema debe permitir al vendedor autenticado registrar una venta seleccionando: clínica/cupón (de una lista activa) y forma de pago.

**RF-012** El sistema debe permitir al vendedor subir una imagen como comprobante de la venta (foto del cupón + comprobante de pago, en una sola imagen).

**RF-013** El sistema debe registrar automáticamente fecha, hora y vendedor al crear una venta.

**RF-014** El sistema debe permitir al vendedor indicar si aplicó el descuento predefinido en la venta.

**RF-015** Si el cupón de la clínica seleccionada está inactivo, el sistema debe advertir al vendedor en el momento del registro y permitir continuar con la venta marcada como fuera de campaña.

**RF-016** Para ventas en efectivo, el sistema debe generar automáticamente un código de autorización interno al momento del registro.

**RF-017** El vendedor debe poder consultar su historial de ventas del día y de la semana en curso.

**RF-018** El vendedor debe poder consultar su comisión acumulada en la semana en curso.

---

### RF-020 — Módulo de Validación (Secretario de Ventas)

**RF-021** El sistema debe mostrar al secretario una cola de ventas pendientes de validación, con la imagen adjunta visible.

**RF-022** El secretario debe poder ingresar los datos del cliente al validar una venta: nombre, DNI, teléfono, correo electrónico, fecha de compra y forma de pago confirmada.

**RF-023** Para ventas electrónicas, el secretario debe ingresar y confirmar el número de autorización del comprobante.

**RF-024** El sistema debe permitir al secretario marcar una venta como **validada** o **inválida**, con campo de observaciones obligatorio en caso de invalidez.

**RF-025** El sistema debe advertir al secretario cuando intenta validar una venta con cupón inactivo.

**RF-026** El sistema debe permitir al secretario registrar un traspaso de venta a otra clínica, manteniendo el mismo número de autorización y actualizando la asignación de clínica.

**RF-027** El sistema debe generar un archivo exportable en formato Excel con la lista de clientes validados por clínica, incluyendo: nombre, DNI, número de autorización y fecha de venta.

---

### RF-030 — Módulo de Comisiones y Pagos

**RF-031** El sistema debe calcular automáticamente la comisión de cada venta según la tabla de comisiones configurada, considerando el precio final de venta (con o sin descuento).

**RF-032** El sistema debe recalcular retroactivamente las comisiones del líder por ventas de su equipo cuando se supera un umbral semanal.

**RF-033** El sistema debe calcular automáticamente el bono de fin de semana para cada vendedor (sábados y domingos): por cada 5 ventas del día, se suma 1 comisión extra al nivel del tier más bajo.

**RF-034** El sistema debe mostrar el estado de comisiones de la semana actual por vendedor: ventas realizadas, comisión acumulada, nivel de umbral del líder si aplica.

**RF-035** El sistema debe llevar un registro del dinero en efectivo pendiente de rendición por vendedor.

**RF-036** El tesorero debe poder registrar los pagos realizados a cada vendedor, cerrando el período semanal correspondiente.

**RF-037** El sistema debe generar un resumen de pago semanal por vendedor: detalle de ventas, comisiones individuales, comisiones por equipo (si aplica), bonos y total a pagar.

---

### RF-040 — Módulo de Campañas y Cupones

**RF-041** La gerencia debe poder crear un nuevo cupón para una clínica con estado inicial BORRADOR.

**RF-042** La gerencia debe poder activar un cupón (cambiar estado a ACTIVO). Solo puede haber un cupón activo por clínica.

**RF-043** La gerencia debe poder desactivar manualmente un cupón activo (cambiar estado a INACTIVO).

**RF-044** El sistema debe enviar una notificación interna al secretario y al líder de equipo cuando se registra una venta con cupón inactivo.

**RF-045** La gerencia debe poder configurar el precio del cupón y si permite descuento.

---

### RF-050 — Módulo de Inventario de Cupones (básico)

**RF-051** La gerencia debe poder registrar el ingreso de nuevos lotes de cupones físicos, indicando clínica y cantidad.

**RF-052** La gerencia debe poder asignar cupones de un lote a un equipo.

**RF-053** El líder de equipo debe poder asignar cupones a vendedores individuales de su equipo.

**RF-054** El sistema debe mostrar el stock estimado de cupones por: clínica, equipo y vendedor.

**RF-055** El vendedor o líder debe poder reportar cupones perdidos o dañados, descontándolos del stock estimado.

---

### RF-060 — Módulo de Reportes

**RF-061** El sistema debe generar reportes de ventas filtrables por: período de tiempo, vendedor, equipo, clínica, punto de venta, ciudad, país y forma de pago.

**RF-062** El sistema debe mostrar rankings de ventas: diario y semanal, por vendedor y por equipo.

**RF-063** El tesorero debe poder ver reportes de pagos de todos los vendedores por período configurable.

**RF-064** El sistema debe calcular estadísticas por vendedor: promedio de ventas diario, semanas de mayor rendimiento, evolución mensual.

**RF-065** El sistema debe permitir exportar reportes en formato Excel.

---

### RF-070 — Módulo de Administración (ABM)

**RF-071** La gerencia debe poder gestionar (crear, editar, activar/desactivar): países, ciudades, clínicas, puntos de venta, equipos y usuarios de todos los roles.

**RF-072** La gerencia y el tesorero deben poder configurar la tabla de comisiones: precio de venta → monto de comisión por venta.

**RF-073** La gerencia y el tesorero deben poder configurar los umbrales de comisión del líder de equipo.

**RF-074** El sistema debe implementar roles con permisos diferenciados, no pudiendo un usuario acceder a funcionalidades fuera de su rol.

---

### RF-080 — Módulo de Juegos (V2)

**RF-081** El sistema debe soportar juegos diarios de tipo: fotos con clientes (registro de puntos), robos entre vendedores y pozo del día (vendedor con más ventas).

**RF-082** El vendedor debe poder subir fotos vinculadas a juegos diarios.

**RF-083** El sistema debe permitir al vendedor elegir a quién robar en el juego de robos.

**RF-084** El encargado de juegos debe poder gestionar, cerrar y declarar ganadores de los juegos del día.

**RF-085** El sistema debe registrar los premios de juegos como pagos separados de las comisiones semanales.

---

## 4. REQUISITOS NO FUNCIONALES

**RNF-001** La interfaz debe ser completamente responsive: funcional en móvil (campo) y escritorio (oficina).

**RNF-002** El sistema debe implementar autenticación con usuario y contraseña, con sesiones con tiempo de expiración.

**RNF-003** El control de acceso debe estar basado en roles (RBAC); cada usuario solo accede a las funcionalidades de su rol.

**RNF-004** Las imágenes de comprobantes deben almacenarse en un servidor de archivos y referenciarse desde la base de datos (no como BLOBs en la BD).

**RNF-005** El tiempo de respuesta de las operaciones comunes no debe superar 3 segundos en condiciones normales de red.

**RNF-006** Los datos deben persistir en una base de datos relacional (PostgreSQL recomendado).

**RNF-007** El sistema debe operar de forma completamente independiente de WhatsApp o cualquier plataforma de mensajería.

**RNF-008** El sistema debe estar disponible los 7 días de la semana; objetivo de disponibilidad del 99% en horario laboral (8:00–22:00).

**RNF-009** Las imágenes subidas deben ser comprimidas antes de almacenarse para optimizar el uso de almacenamiento.

**RNF-010** El sistema debe registrar logs de auditoría para operaciones críticas: validaciones, anulaciones, cambios de campaña, pagos y modificaciones de comisiones.

**RNF-011** El backend debe exponer una API REST que sirva al frontend web.

**RNF-012** El sistema debe soportar dos monedas: CLP (Chile) y ARS (Argentina), almacenando cada transacción con su moneda de origen.

---

## 5. REGLAS DE NEGOCIO

### RN-01x — Ventas

**RN-011** Una venta solo puede registrarse si el vendedor está autenticado y activo en el sistema.

**RN-012** Toda venta debe tener asociada una imagen de comprobante al momento del registro.

**RN-013** Una venta registrada con el cupón de una clínica inactiva se almacena igualmente pero queda marcada como **FUERA_DE_CAMPAÑA**, generando notificaciones al secretario y al líder de equipo.

**RN-014** Una venta no puede cancelarse. Solo puede registrarse un traspaso a otra clínica.

**RN-015** Un traspaso mantiene el mismo número de autorización original y transfiere la venta a la nueva clínica para la lista de clientes.

**RN-016** Una venta queda en estado **PENDIENTE** hasta que el secretario la valide.

**RN-017** Una venta solo puede ser marcada como **VALIDADA** o **INVÁLIDA** por el secretario de ventas.

**RN-018** El descuento aplicable por venta es único y predefinido en el sistema; no es un valor arbitrario ingresado por el vendedor.

### RN-02x — Flujo según forma de pago

**RN-021** Para ventas electrónicas (posnet crédito, posnet débito, transferencia, MercadoPago, WebPay): el número de autorización proviene del comprobante generado por el sistema externo de cobro y debe ser confirmado por el secretario al validar.

**RN-022** Para ventas en efectivo: el sistema genera automáticamente un código de autorización interno en el momento del registro. El vendedor sube una fotografía del cupón junto con el dinero en efectivo visible. El secretario valida revisando visualmente la foto.

**RN-023** El dinero en efectivo cobrado por el vendedor queda registrado como deuda del vendedor hacia la empresa hasta que sea rendido al líder de equipo.

### RN-03x — Comisiones

**RN-031** La comisión de cada venta se determina por el precio final de venta (precio del cupón aplicando descuento si corresponde), consultando la tabla de comisiones configurada.

**RN-032** La tabla de comisiones es global: aplica por igual a todos los vendedores, todas las clínicas y todos los países.

**RN-033** El líder de equipo cobra la misma comisión por sus ventas individuales que cualquier vendedor.

**RN-034** El líder de equipo cobra adicionalmente una comisión por cada venta de los vendedores de su equipo en la semana. El monto varía según el total de ventas semanales del equipo (umbrales configurables). Esta comisión es retroactiva: al superar un umbral, todas las ventas de la semana se recalculan al nuevo monto.

**RN-035** Los sábados y domingos: por cada 5 ventas realizadas por un vendedor en el día, se suma 1 comisión extra equivalente al monto del tier más bajo de la tabla de comisiones. Este cálculo es proporcional (10 ventas = 2 extras).

**RN-036** Las comisiones se calculan por semana laboral: de lunes a domingo.

### RN-04x — Pagos

**RN-041** Los pagos a vendedores se realizan los martes de cada semana, cubriendo la semana laboral anterior (lunes a domingo).

**RN-042** Los pagos por premios de juegos diarios son independientes de las comisiones semanales y se registran el mismo día del juego.

**RN-043** El sistema no gestiona pagos hacia las clínicas; ese proceso está fuera del alcance del sistema.

### RN-05x — Campañas y Cupones

**RN-051** Cada clínica tiene exactamente un cupón activo a la vez.

**RN-052** Solo la gerencia puede crear, activar y desactivar cupones.

**RN-053** Los cupones físicos no tienen identificador individual preimpreso. El inventario de cupones se gestiona por conteo estimado.

**RN-054** Un cupón perdido o dañado debe ser reportado por el vendedor o el líder de equipo, ajustando el conteo estimado.

### RN-06x — Estructura Organizacional

**RN-061** Un vendedor pertenece a exactamente un equipo y no puede pertenecer a más de uno simultáneamente.

**RN-062** Un equipo tiene exactamente un líder de equipo.

**RN-063** Un equipo puede operar en uno o más puntos de venta. Un punto de venta pertenece a un único equipo.

---

## 6. ALCANCE DEL PROYECTO

### MVP — Primera Versión (obligatorio)

| Módulo | Prioridad |
|---|---|
| Autenticación y control de acceso por roles | CRÍTICA |
| Registro de ventas por el vendedor | CRÍTICA |
| Validación de ventas por el secretario | CRÍTICA |
| Ingreso de datos de clientes | CRÍTICA |
| Cálculo automático de comisiones | CRÍTICA |
| Bono de fin de semana | ALTA |
| Cálculo retroactivo del líder | ALTA |
| Registro de pagos por el tesorero | ALTA |
| Resumen semanal de pagos | ALTA |
| ABM de entidades principales | ALTA |
| Gestión de campañas/cupones | ALTA |
| Inventario básico de cupones | MEDIA |
| Reportes de ventas filtrables | ALTA |
| Exportación de lista de clientes a Excel | ALTA |
| Notificaciones internas (fuera de campaña) | MEDIA |
| Traspaso de venta a otra clínica | MEDIA |
| Registro de efectivo pendiente por vendedor | ALTA |

### Versión 2 — Segunda iteración

- Módulo completo de juegos (fotos, robos, pozo del día)
- Dashboard con gráficos e indicadores en tiempo real
- Notificaciones automáticas por correo electrónico
- Estadísticas históricas avanzadas

### Versión 3 — Expansión futura

- Aplicación móvil nativa (Android/iOS)
- Integración con APIs de pago externas para verificación automática
- Portal de acceso para clínicas

---

## 7. PROPUESTA: FLUJO DE VENTAS EN EFECTIVO

Este es un punto de diseño crítico. Se propone el siguiente flujo para estandarizar el manejo de ventas en efectivo dentro del sistema:

### Flujo propuesto

```
VENDEDOR (en campo)
  1. Selecciona clínica/cupón
  2. Selecciona forma de pago: "Efectivo"
  3. Sube foto: [mitad del cupón] + [dinero en efectivo visible]
  4. El sistema genera automáticamente:
       Código de autorización interno: EF-YYYYMMDD-NNNNN
  5. Venta creada en estado: PENDIENTE_EFECTIVO

SECRETARIO (en oficina)
  6. Ve la venta en la cola con badge "EFECTIVO"
  7. Revisa visualmente que la foto muestra efectivo
  8. Ingresa datos del cliente leídos del cupón
  9. Confirma la validación
  10. Estado cambia a: VALIDADA
  11. La venta queda registrada con el código interno como autorización
```

### Justificación

Este enfoque elimina la ambigüedad del proceso actual (donde el encargado "ve la foto y anota el número"), lo reemplaza con un código generado automáticamente y mantiene trazabilidad completa desde el momento del registro.

### Implicación en el modelo de datos

La entidad `Venta` tendrá:
- `forma_pago`: ENUM (EFECTIVO, TRANSFERENCIA, POSNET_CREDITO, POSNET_DEBITO, MERCADOPAGO, WEBPAY)
- `numero_autorizacion`: String — externo para ventas electrónicas, generado internamente para efectivo
- `origen_autorizacion`: ENUM (EXTERNO, INTERNO)
- `estado`: ENUM (PENDIENTE, VALIDADA, INVALIDA, FUERA_DE_CAMPAÑA)

---

## 8. ENTIDADES DEL DOMINIO (Preliminar)

Lista preliminar de entidades identificadas. Sujeta a refinamiento en el modelo de dominio.

| Entidad | Descripción |
|---|---|
| `Pais` | País de operación (Argentina, Chile) |
| `Ciudad` | Ciudad dentro de un país |
| `PuntoDeVenta` | Ubicación física donde opera un equipo |
| `Clinica` | Proveedor del plan (dental, veterinaria, etc.) |
| `Cupon` | Plan activo de una clínica. Tiene precio, estado y descuento aplicable. |
| `TablaComision` | Mapeo precio de venta → monto de comisión del vendedor |
| `UmbralLider` | Tramos de ventas semanales del equipo → comisión por venta del líder |
| `Equipo` | Grupo de vendedores bajo un líder |
| `Usuario` | Entidad base de todos los perfiles del sistema |
| `Vendedor` | Usuario con rol Vendedor, pertenece a un Equipo |
| `LiderDeEquipo` | Usuario con rol Líder, también es Vendedor |
| `SecretarioDeVentas` | Usuario con rol Secretario |
| `Tesorero` | Usuario con rol Tesorero |
| `EncargadoDeJuegos` | Usuario con rol Encargado de Juegos |
| `Gerente` | Usuario con rol Gerencia |
| `Cliente` | Persona que adquirió un plan. Datos ingresados por el Secretario. |
| `Venta` | Transacción central del sistema |
| `ImagenVenta` | Imagen del comprobante asociada a una Venta |
| `SemanaLaboral` | Período lunes–domingo usado para agrupación de comisiones y pagos |
| `PagoVendedor` | Pago semanal registrado por el Tesorero a un Vendedor |
| `TraspasoVenta` | Registro de cambio de clínica de una Venta |
| `StockCupon` | Conteo estimado de cupones físicos por clínica y equipo/vendedor |
| `RendicionEfectivo` | Registro de rendición de dinero en efectivo del vendedor al líder |

---

## 9. DEFINICIONES RESUELTAS

| ID | Decisión | Impacto en diseño |
|---|---|---|
| PD-001 | Un cupón desactivado **no puede reactivarse**. Si se quiere volver a operar con esa clínica, se crea un cupón nuevo. | La entidad `Cupon` no necesita lógica de reactivación. El historial de ventas del cupón anterior queda intacto. |
| PD-002 | En el MVP, **solo Gerencia** puede autorizar traspasos. En V2 se evaluará si se le da ese permiso al Líder de Equipo. | Permisos de `TraspasoVenta` acotados a rol Gerencia en v1. |
| PD-003 | Los datos exactos del Excel a clínicas **están pendientes de confirmación** con la gerencia. Por defecto se incluirá: nombre, DNI y número de autorización del cliente. | RF-027 sujeto a revisión menor antes de implementar la exportación. |
| PD-004 | La rendición de efectivo la **registra el Líder de Equipo** al recibir el dinero de su vendedor. El vendedor no tiene acción en este flujo. | La entidad `RendicionEfectivo` se asocia al Líder como actor que confirma la recepción. El sistema lleva el saldo pendiente por vendedor hasta que el líder registra la rendición. |

### Reglas de negocio derivadas de las resoluciones

**RN-055** Un cupón en estado INACTIVO no puede volver a ACTIVO. Para retomar operaciones con una clínica se debe crear un nuevo cupón.

**RN-056** La rendición de efectivo la registra el Líder de Equipo en el sistema al recibir físicamente el dinero de su vendedor. Hasta ese momento el sistema mantiene un saldo de efectivo pendiente a cargo del vendedor.

**RN-057** Solo Gerencia puede registrar traspasos de venta a otra clínica (MVP). Esta decisión se revisará en V2.

---

## 10. PENDIENTES MENORES

| ID | Punto | Impacto |
|---|---|---|
| PD-003 | Datos exactos del Excel exportado a clínicas (confirmar con gerencia) | RF-027 — ajuste menor antes de implementar |

---

*Fin del documento — Especificación Funcional v1.0*
