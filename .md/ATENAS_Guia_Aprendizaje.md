# ATENAS Software — Guía de Aprendizaje
## Diseño de Software: Conceptos, Decisiones y Aprendizajes
> Documento acumulativo. Se actualiza al cerrar cada módulo.
> Usarlo junto con el proyecto terminado para evaluar la aplicación real de cada concepto.

---

# FASE 1 — API REST: Fundamentos y Diseño Inicial

---

## 1.1 — ¿Qué es una API REST?

**En una línea:** Es el intermediario entre la pantalla que ven los usuarios y la base de datos donde viven los datos.

```
[App del vendedor]      ←→  [API REST]  ←→  [Base de datos PostgreSQL]
[Web del secretario]    ←→  [API REST]
[Web del tesorero]      ←→  [API REST]
```

La app del vendedor nunca habla directamente con la base de datos. Le hace pedidos a la API, y la API responde con datos en formato JSON.

**REST** es un estilo de diseño. Sus dos reglas principales:
- Las URLs nombran **recursos** (ventas, usuarios, clínicas)
- Los métodos HTTP dicen **qué hacés** con ese recurso

| Método HTTP | Significado | Ejemplo ATENAS |
|---|---|---|
| `GET` | Leer / consultar | Ver mis ventas del día |
| `POST` | Crear algo nuevo | Registrar una venta |
| `PATCH` | Modificar algo parcialmente | Validar una venta |
| `PUT` | Reemplazar algo completo | (raro en ATENAS) |
| `DELETE` | Eliminar (raro; ATENAS usa soft delete) | — |

---

## 1.2 — Estructura General de la API

### A) Versionado en la URL — Decisión: `/v1/`

```
https://api.atenas.com/v1/ventas
https://api.atenas.com/v1/usuarios
```

**❓ ¿Las dos versiones corren juntas por si una falla?**

No. La protección no es contra fallas. Ambas versiones apuntan a **la misma base de datos**. El versionado resuelve **compatibilidad hacia atrás**:

> Si lanzás V2 con cambios que rompen la API, la app de V1 que ya tienen
> los vendedores en sus celulares sigue funcionando. Las dos versiones
> conviven hasta que todos migren.

Es un seguro contra **romper lo que ya funciona**, no contra perder datos.

### B) Formato Envelope — Decisión: Estilo A

Todas las respuestas tienen la misma estructura:

```json
{
  "success": true,
  "data": { "venta_id": "uuid", "estado": "PENDIENTE" },
  "message": "Venta registrada correctamente",
  "errors": null
}
```

En caso de error:
```json
{
  "success": false,
  "data": null,
  "message": "No se pudo registrar la venta",
  "error_code": "SIN_ASIGNACION_PDV",
  "errors": ["Tu equipo no tiene un punto de venta asignado esta semana"]
}
```

Con 6 roles distintos y flujos complejos, el frontend siempre sabe:
- `data` → el dato útil
- `success` → si salió bien o mal
- `message` → qué decirle al usuario
- `error_code` → constante para decisiones programáticas
- `errors` → lista de errores específicos

### C) Paginación — Decisión: Clásica

```
GET /v1/ventas?page=1&limit=20
```

```json
{
  "success": true,
  "data": [ ...20 ventas... ],
  "pagination": { "page": 1, "limit": 20, "total": 147, "total_pages": 8 }
}
```

### 🔖 Para explorar después
- Sin versionado vs. con versionado: simular un cambio de contrato y ver qué le pasa a un cliente viejo
- Bare response vs. Envelope: ver cómo el frontend cambia su código si la estructura varía

---

## 1.3 — Autenticación: JWT y Tokens

### El problema de HTTP sin estado

HTTP es **stateless**: cada pedido es independiente. El servidor no recuerda que el vendedor se logueó 5 segundos antes. La autenticación resuelve esto.

### Sesiones vs. JWT

**Sesiones (descartado):** el servidor guarda la sesión en BD y la consulta en cada pedido. Con muchos usuarios simultáneos, genera carga innecesaria.

**JWT — JSON Web Token (elegido):** el servidor genera un "carnet firmado digitalmente" con la info del usuario. En cada pedido el cliente lo manda y el servidor verifica la firma matemáticamente, sin tocar la BD.

```json
{
  "user_id": "uuid-del-vendedor",
  "rol": "VENDEDOR",
  "equipo_id": "uuid-del-equipo",
  "exp": 1749600000
}
```

→ El servidor sabe quién sos, qué rol tenés y qué podés hacer **sin ir a la base de datos**.

### Access Token + Refresh Token

Un solo token con vida larga es un riesgo. La solución son dos tokens:

```
ACCESS TOKEN  → vida corta (15 min) — se usa en cada pedido
REFRESH TOKEN → vida larga (7 días)  — solo sirve para renovar el access token
```

**Flujo completo:**
```
Login → recibís AMBOS tokens

Pedidos normales → usás el ACCESS TOKEN

Access token vence → la app detecta 401
    → usa el REFRESH TOKEN silenciosamente
    → servidor devuelve ACCESS TOKEN nuevo
    → usuario no nota nada

Refresh token vence (7 días sin actividad) → re-login obligatorio
```

Para el usuario, la "sesión" dura lo que dura el **refresh token**. El access token es un detalle interno de seguridad, invisible.

### Almacenamiento — Decisión: Cookie HttpOnly (web)

| Cliente | Almacenamiento | Envío |
|---|---|---|
| Navegador web (V1) | Cookie HttpOnly | El navegador la adjunta automáticamente |
| App nativa (V2) | Secure Storage | Header `Authorization: Bearer <token>` |

Cookie HttpOnly: JavaScript no puede leerla. Protegida contra ataques XSS.
En V2 (app nativa), se agrega el Header como opción adicional. Sin reescribir nada del backend.

**Decisiones tomadas:**
- Estrategia: JWT
- Access token: 15 minutos
- Refresh token: 7 días
- Almacenamiento V1: Cookie HttpOnly

---

## 1.4 — RBAC: Control de Acceso Basado en Roles

El rol viaja DENTRO del JWT. En cada pedido el servidor lo lee y decide sin ir a la BD:

```
Token: { "rol": "VENDEDOR" }
Vendedor intenta ver "todas las comisiones" (solo Tesorero/Gerencia)
→ Servidor lee rol → RECHAZADO (HTTP 403 Forbidden)
```

**Tabla de permisos ATENAS:**

| Rol | Permisos |
|---|---|
| VENDEDOR | Registrar venta · Ver propias ventas · Ver propia comisión |
| LÍDER | Todo lo de Vendedor + Ver ventas de equipo · Asignar cupones · Ver comisiones de equipo |
| SECRETARIO | Cola de validación · Ingresar clientes · Ver todas las ventas · Exportar Excel |
| TESORERO | Ver todas las ventas · Registrar pagos · Ver comisiones · Reportes financieros · Configurar comisiones |
| ENC. JUEGOS | Ver estadísticas (solo lectura) · Gestionar juegos (V2) |
| CLINICA | Solo lectura de sus propios pacientes validados |
| GERENCIA | Acceso total |

**❓ ¿Se pueden agregar roles después?**
Sí. El rol es un ENUM en PostgreSQL: `ALTER TYPE usuario_rol ADD VALUE 'SUPERVISOR';`
Una línea. No se pueden eliminar valores (sin recrear el tipo), pero para ATENAS no es un problema.

**HTTP 401 vs 403 — distinción importante:**
- `401 Unauthorized` = "no sé quién sos" → token inválido o vencido
- `403 Forbidden` = "sé quién sos pero no podés hacer eso" → rol insuficiente

---

## 1.5 — Dashboard: Descubrimiento de Requisitos y Diseño de Entidades

### Requisitos tardíos

El dashboard apareció durante el diseño de la API — no estaba en la especificación original. Esto es **normal** en ingeniería de software real. La habilidad está en detectar el impacto rápido y hacer cambios aditivos sin romper lo que ya existe.

### El 🎁 no es una entidad nueva

```
BONO_FIN_SEMANA (ya en spec): cada 5 ventas en sábado/domingo
BONO_RECORD (nuevo):          al superar el récord personal del día
```

Ambos ya van a `registro_comision`. El dashboard solo los cuenta y muestra como 🎁. Esto es **reutilización de diseño**: en vez de crear una tabla nueva, se aprovechó la estructura existente.

### Jerarquía de jornadas

```
semana_laboral (1)
    └── jornada_diaria (hasta 7 — una por día, creadas al crear la semana)
            └── jornada_vendedor (1 por vendedor por día — se crea al primer check-in o venta)
```

`jornada_diaria` existe aunque nadie venda ese día. `jornada_vendedor` se crea al primer evento del vendedor.

### Flag como mecanismo de control

`record_superado_hoy BOOLEAN` en `jornada_vendedor`: evita dar dos 🎁 por récord en el mismo día.
```
Venta #9 → rompe récord (era 8) → flag FALSE → genera 🎁 → flag → TRUE
Venta #10 → flag TRUE → NO genera otro 🎁
```

---

# FASE 2 — Revisión del Schema con DBeaver

---

## 2.1 — Flujo de Actualización de Base de Datos

> Usar este flujo cada vez que se modifica `schema.sql`.
> Durante diseño: destruir y recrear el contenedor es la estrategia correcta.

**Paso 1 — Modificar schema.sql**
Actualizar archivo maestro. Nunca modificar la BD directamente sin antes cambiar el archivo.
Actualizar versión en el header y registrar el cambio en el historial.

**Paso 2 — Guardar cambios en Git**
```bash
git checkout -b refactor/schema-vX-Y-descripcion
git add docs/03-base-de-datos/schema.sql
git commit -m "refactor(db): schema vX.Y — descripción breve
- Detalle 1
- Detalle 2"
git checkout main && git merge refactor/schema-vX-Y-descripcion
git push
```

**Paso 3 — Detener el contenedor**
```bash
docker stop postgres-atenas
```

**Paso 4 — Eliminar el contenedor**
```bash
docker rm postgres-atenas
```
Durante diseño esto es deseable: evita inconsistencias del schema anterior.

**Paso 5 — Crear nuevo contenedor**
```bash
docker run --name postgres-atenas \
  -e POSTGRES_USER=atenas \
  -e POSTGRES_PASSWORD=123456 \
  -e POSTGRES_DB=atenas \
  -p 5432:5432 -d postgres:15
```
Para arranque automático: `docker update --restart=always postgres-atenas`

**Paso 6 — Copiar y ejecutar schema.sql**
```bash
docker cp "C:\ruta\schema.sql" postgres-atenas:/schema.sql
docker exec -it postgres-atenas psql -U atenas -d atenas -f /schema.sql
```

**Paso 7 — Copiar y ejecutar seeds.sql**
```bash
docker cp "C:\ruta\seeds.sql" postgres-atenas:/seeds.sql
docker exec -it postgres-atenas psql -U atenas -d atenas -f /seeds.sql
```
Los seeds no son idempotentes: ejecutar solo una vez por contenedor.

**Paso 8 — Reconectar DBeaver**
Click derecho sobre la conexión → Connect → Refresh.
Si hay error de TimeZone: Settings → PostgreSQL → timezone → `America/Argentina/Buenos_Aires`

**Paso 9 — Validar**
```sql
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
SELECT * FROM pais;
SELECT * FROM equipo;
```

**Concepto: Migraciones vs. Recreación**
En producción con datos reales, no se puede destruir el contenedor. Se usan migraciones (scripts que modifican la estructura sin borrar datos). Herramientas: Flyway, Liquibase (Java), Alembic (Python). No necesarias ahora — suficiente saber que existen.

---

## 2.2 — Circuito 1: Ventas ✅

Tablas: `venta`, `cliente`, `imagen_venta`, `traspaso_venta`, `jornada_vendedor`, `jornada_diaria`, `semana_laboral`, `usuario`

**Desnormalización intencional:**
`venta` mantiene `semana_laboral_id` Y `vendedor_id` aunque sean derivables desde `jornada_vendedor_id`. Esto protege el rendimiento de las queries más frecuentes (cálculo retroactivo de comisiones). La redundancia controlada y documentada no es un error — es una decisión de diseño.

**v1.3:** `venta.jornada_vendedor_id` (enlace al día del dashboard), `venta.rendicion_efectivo_id` (trazabilidad de efectivo).

---

## 2.3 — Circuito 2: Estructura Comercial ✅

Tablas: `pais`, `ciudad`, `punto_de_venta`, `equipo`, `asignacion_equipo_punto`, `clinica`, `cupon`, `usuario`

**Decisión 1 — Relación clínica:cupón es 1:N**
Una clínica puede tener muchos cupones históricos pero solo uno ACTIVO. El índice parcial `WHERE estado = 'ACTIVO'` garantiza la unicidad sin romper el historial.

**Decisión 2 — clinica.ciudad_id (v1.3)**
Las clínicas se asocian a una ciudad para reportes geográficos cruzados y el portal de clínicas (V3).

---

## 2.4 — Circuito 3: Inventario y Sistema ✅

**Inventario:**
- `lote_ingreso_cupones`: entrada de cupones físicos a la empresa
- `movimiento_cupon`: cada fila es un movimiento de stock. El stock se calcula sumando movimientos (ASIGNACION_EQUIPO, ASIGNACION_VENDEDOR, PERDIDA, DANO, DEVOLUCION)

**Sistema:**
- `notificacion_interna`: alertas dentro del sistema (VENTA_FUERA_CAMPANA)
- `log_auditoria`: registro inmutable append-only. Nunca se borra. JSONB guarda estado anterior y nuevo

**Juegos (V2):** `juego`, `registro_juego`, `premio_juego` diseñadas en el schema para no migrar después.

---

## 2.5 — Circuito 4: Comisiones y Pagos ✅

**`semana_laboral`:** contenedor temporal. `estado` (ABIERTA/CERRADA) es el campo más importante. Una semana puede haber terminado y seguir ABIERTA hasta que el tesorero la cierre el martes.

**`tabla_comision`:** mapea precio_venta → monto_comision. Global. Sin versioning (el monto histórico queda en `registro_comision`).

**`umbral_lider` — lookup por límite inferior (v1.4):**
Solo `ventas_desde`. Sin `ventas_hasta` (eliminaba riesgo de huecos entre tramos).
```sql
SELECT monto_comision_lider FROM umbral_lider
WHERE ventas_desde <= :total_ventas_semana AND fecha_baja IS NULL
ORDER BY ventas_desde DESC LIMIT 1
```
Al cruzar un umbral, TODAS las comisiones del líder esa semana se recalculan (UPDATE en lote). El `umbral_lider_id` en `registro_comision` refleja siempre el umbral definitivo.

**`registro_comision` — el libro contable:**

| Tipo | Cuándo | venta_id |
|---|---|---|
| VENDEDOR_INDIVIDUAL | Cada venta | ✅ |
| LIDER_EQUIPO | Cada venta del equipo (retroactiva) | ✅ |
| BONO_FIN_SEMANA | Cada 5 ventas en sáb/dom | ❌ |
| BONO_RECORD | Al superar récord del día | ❌ |
| PREMIO_JUEGO (v1.4) | Premio de juego diario | ❌ |

Campos de trazabilidad: `pago_vendedor_id`, `tabla_comision_id`, `umbral_lider_id`, `jornada_vendedor_id`.

**`pago_vendedor` (v1.4):**
```
total = comisiones_vendedor + comisiones_equipo + bonos + premios − descuento_efectivo
```
El sistema notifica al operador si hay efectivo pendiente antes de procesar el pago.

**`rendicion_efectivo` — ciclo automático (v1.4):**
```
1ra venta en efectivo → sistema crea rendicion_efectivo ABIERTA
Más ventas → se vinculan a la misma rendición
Líder recibe dinero → CERRADA (con monto y fecha confirmados)
Al pagar → rendiciones ABIERTAS → descuento en pago_vendedor
```
UNIQUE (vendedor_id, semana_laboral_id): una sola rendición por vendedor por semana en V1.

**Snapshot vs. live reference:**
`registro_comision.monto` es un snapshot congelado. Si cambia la configuración después, los montos históricos no se tocan. Esto es correcto para auditoría contable.

---

# FASE 3 — API REST: Diseño Completo de Endpoints

---

## 3.1 — La conexión entre Flujos de Sucesos y Endpoints

En tus clases de diseño de sistemas estudiás **flujos de sucesos** (también llamados flujos de eventos o flujos de casos de uso). Describen:
1. El actor que inicia la acción
2. Los pasos que ejecuta el sistema
3. Los flujos alternativos (errores, excepciones)

Un endpoint REST **ES** la implementación técnica de un flujo de sucesos:

```
FLUJO DE SUCESOS (diseño)          ENDPOINT REST (implementación)
─────────────────────────────      ──────────────────────────────
Actor                          →   Rol en el JWT (RBAC)
Acción que inicia              →   Verbo HTTP + URL
Datos que proporciona          →   Body del request
Pasos del sistema              →   Flujo del backend
Resultado normal               →   Respuesta 200/201 + data
Flujos alternativos            →   Códigos de error (400, 422, etc.)
```

Cuando en clase describís "el vendedor registra una venta y el sistema calcula la comisión", eso se convierte exactamente en `POST /v1/ventas` con los 19 pasos del backend que documentamos.

---

## 3.2 — Template de Diseño de Endpoints

Para diseñar cualquier endpoint de ATENAS (o de cualquier sistema):

```
1. CASO DE USO        ¿Qué quiere hacer el actor?
                      "El vendedor registra una venta en campo"

2. ACTOR Y ACCESO     ¿Qué rol puede hacerlo?
                      VENDEDOR, LIDER

3. VERBO HTTP         ¿Es leer, crear, modificar?
                      POST (crea un recurso nuevo)

4. URL                /v1/[recurso]/[acción_opcional]
                      POST /v1/ventas

5. BODY               ¿Qué datos manda el cliente?
                      multipart/form-data: cupon_id, forma_pago,
                      aplico_descuento, imagen

6. FLUJO BACKEND      Pasos que ejecuta el servidor (en una transacción)
                      1. Verificar vendedor activo
                      2. Buscar PDV desde asignación del equipo
                      ...19 pasos...

7. RESPUESTA OK       Código HTTP + estructura de data
                      201 Created + { venta_id, numero_autorizacion, estado }

8. ERRORES            Código HTTP + error_code para cada caso
                      422 SIN_ASIGNACION_PDV
                      400 ARCHIVO_REQUERIDO
                      422 VENDEDOR_INACTIVO
```

---

## 3.3 — Módulo Auth (4 endpoints)

**POST /v1/auth/login**
```
Acceso: público
Body:   { username, password }
Acción: valida credenciales → genera access + refresh tokens → los setea como cookies HttpOnly
201: { user: { id, nombre, rol, equipo_id, emoji_personal } }
401: TOKEN_INVALIDO (credenciales incorrectas o usuario inactivo)
```

**POST /v1/auth/refresh**
```
Acceso: público (usa refresh cookie automáticamente)
Body:   vacío
Acción: verifica refresh token → genera nuevo access token
200: { success: true }
401: si el refresh también venció → re-login obligatorio
```

**POST /v1/auth/logout**
```
Acceso: autenticado
Acción: borra ambas cookies (Max-Age = 0)
200: { success: true }
```

**GET /v1/auth/me**
```
Acceso: autenticado
Acción: decodifica el token → devuelve perfil completo
200: { id, nombre, apellido, rol, equipo_id, emoji_personal, meta_ventas_default }
Uso: la app lo llama al cargar para saber quién está logueado
```

**Refresh silencioso:**
Cuando la app recibe 401 por token vencido → llama /refresh → reintenta el pedido original → usuario no nota nada.

---

## 3.4 — Módulo Ventas (3 endpoints)

**POST /v1/ventas**
```
Acceso: VENDEDOR, LIDER
Body:   multipart/form-data { cupon_id, forma_pago, aplico_descuento, imagen }
        ← sin punto_de_venta_id: se deriva del equipo del vendedor automáticamente
201: { venta_id, numero_autorizacion, precio_final, moneda, estado, fuera_de_campana }

Flujo backend (19 pasos en 1 transacción):
  1.  Verificar vendedor activo
  2.  Buscar equipo → asignacion_equipo_punto → PDV (422 si no hay asignación)
  3.  Resolver cupón → fuera_de_campana si inactivo + notificaciones
  4.  Calcular precio_final
  5.  Buscar comisión en tabla_comision
  6.  Determinar moneda (PDV → ciudad → país)
  7.  Obtener semana_laboral activa
  8.  Si EFECTIVO → generar código EF-YYYYMMDD-NNNNN
  9.  Subir imagen → URL
  10. Crear/recuperar jornada_diaria de hoy
  11. Crear/recuperar jornada_vendedor de hoy
  12. INSERT venta
  13. INSERT imagen_venta
  14. Si EFECTIVO → crear/recuperar rendicion_efectivo ABIERTA + vincular venta
  15. INSERT registro_comision VENDEDOR_INDIVIDUAL
  16. Si LIDER → INSERT LIDER_EQUIPO + verificar umbral retroactivo
  17. Si fin de semana y ventas_hoy % 5 == 0 → INSERT BONO_FIN_SEMANA
  18. Si ventas_hoy > record y record_superado_hoy=FALSE → INSERT BONO_RECORD
  19. COMMIT → 201

Errores clave:
  422 SIN_ASIGNACION_PDV, 422 VENDEDOR_INACTIVO, 400 ARCHIVO_REQUERIDO
```

**GET /v1/ventas**
```
Acceso: todos (el backend filtra por rol automáticamente)
  VENDEDOR → solo propias | LIDER → propias + equipo | SECRETARIO/TESORERO/GERENCIA → todas
Filtros: page, limit, fecha_inicio, fecha_fin, estado, forma_pago, clinica_id, vendedor_id, equipo_id
200: lista paginada con envelope estándar
```

**GET /v1/ventas/:id**
```
Acceso: propietario | LIDER (si es de su equipo) | SECRETARIO | TESORERO | GERENCIA
200: detalle completo + comision_generada + datos_cliente (si validada)
403: RECURSO_AJENO | 404: no existe
```

---

## 3.5 — Módulo Validación (3 endpoints)

**GET /v1/ventas/pendientes**
```
Acceso: SECRETARIO, GERENCIA
200: lista de ventas en estado PENDIENTE con imagen_url visible
Filtros: fuera_de_campana, forma_pago, equipo_id
```

**PATCH /v1/ventas/:id/validar**
```
Acceso: SECRETARIO, GERENCIA
Body:
  { "accion": "VALIDAR",
    "cliente": { nombre, apellido, dni, telefono, email },
    "numero_autorizacion_externo": "123456" }   ← solo ventas electrónicas

  { "accion": "INVALIDAR",
    "observaciones": "texto obligatorio" }

Flujo VALIDAR: buscar/crear cliente por DNI (deduplicación) →
               UPDATE venta estado=VALIDADA + cliente_id + validador + fecha → log auditoría
Flujo INVALIDAR: UPDATE estado=INVALIDA + observaciones → log auditoría + notificación vendedor

Errores: 400 VENTA_YA_PROCESADA, 400 CAMPO_REQUERIDO (cliente o motivo)
```

**POST /v1/ventas/:id/traspaso**
```
Acceso: GERENCIA (MVP)
Body:   { cupon_destino_id, motivo }
Flujo:  verificar no hay traspaso previo → INSERT traspaso_venta →
        UPDATE venta.cupon_id → log auditoría
Errores: 409 TRASPASO_YA_EXISTE, 400 mismo cupón origen y destino
```

---

## 3.6 — Módulo Dashboard (3 endpoints)

**GET /v1/dashboard**
```
Acceso: todos los autenticados
Polling: cada 30 segundos (V1) | WebSockets con efectos (V2)
200: { fecha, semana_laboral_id, equipos: [{ nombre, emoji, vendedores: [
  { nombre, emoji_personal, meta_dia, ventas_hoy, bonos_hoy, record_historico, display }
] }] }
El backend construye `display` = emoji × ventas + "🎁" × bonos. El frontend solo lo renderiza.
Solo incluye vendedores con jornada_vendedor activa hoy.
```

**PATCH /v1/jornadas/hoy**
```
Acceso: VENDEDOR, LIDER
Body:   { meta_ventas: 12 }  ← actualizar meta del día
        {}                    ← solo check-in manual
Flujo:  crear jornada_diaria si no existe → crear/actualizar jornada_vendedor
200: { meta_ventas, inscripcion: "MANUAL" }
```

**GET /v1/dashboard/ranking**
```
Acceso: todos los autenticados
Filtro: periodo=DIA | SEMANA (default DIA)
200: { periodo, fecha, ranking: [{ posicion, vendedor, equipo, ventas }] }
```

---

## 3.7 — Módulo Comisiones y Pagos (4 endpoints)

**GET /v1/comisiones**
```
Acceso: VENDEDOR (propias) | LIDER (propias + equipo) | TESORERO/GERENCIA (todas)
Filtros: semana_laboral_id (default semana actual), tipo, vendedor_id
200: lista de registro_comision con monto, tipo, fecha, venta vinculada, estado del pago
```

**GET /v1/semanas/:id/resumen-pago/:vendedor_id**
```
Acceso: TESORERO, GERENCIA
Propósito: ver desglose ANTES de registrar el pago
200: { vendedor, semana, desglose: {
  comisiones_vendedor, comisiones_equipo, bonos_finde, premios_juegos,
  descuento_efectivo, ventas_efectivo_pendientes: [...], total }, moneda }
```

**POST /v1/pagos**
```
Acceso: TESORERO, GERENCIA
Body:   { vendedor_id, semana_laboral_id, fecha_pago, confirmar_descuento_efectivo: true }
Flujo:  calcular desglose → calcular descuento_efectivo desde rendiciones ABIERTAS →
        INSERT pago_vendedor → UPDATE registro_comision.pago_vendedor_id →
        si todos pagados → CERRAR semana_laboral → log auditoría
Errores: 409 PAGO_YA_REGISTRADO, 422 SEMANA_CERRADA, 422 confirmar_descuento requerido
```

**PATCH /v1/rendiciones/:id/cerrar**
```
Acceso: LIDER (solo la de su equipo), GERENCIA
Body:   { monto, observaciones }
Flujo:  UPDATE rendicion_efectivo estado=CERRADA + monto + fecha_rendicion
Errores: 400 RENDICION_YA_CERRADA, 403 si el líder no es responsable del vendedor
```

---

## 3.8 — Módulo Campañas e Inventario (6 endpoints)

**POST /v1/cupones** — crear en BORRADOR
```
Acceso: GERENCIA | Body: { clinica_id, precio, permite_descuento, precio_con_descuento, prestaciones }
```

**PATCH /v1/cupones/:id/activar** — BORRADOR → ACTIVO
```
Acceso: GERENCIA | Verifica cupón único activo por clínica | Log auditoría obligatorio
```

**PATCH /v1/cupones/:id/desactivar** — ACTIVO → INACTIVO (irreversible)
```
Acceso: GERENCIA | UPDATE estado=INACTIVO + fecha_baja | Log + notificación a secretario y líderes
```

**POST /v1/inventario/lotes** — registrar ingreso de cupones físicos
```
Acceso: GERENCIA | Body: { cupon_id, cantidad, observaciones }
```

**POST /v1/inventario/movimientos** — asignar cupones
```
Acceso: GERENCIA (empresa→equipo) | LIDER (equipo→vendedor)
Body:   { lote_id, tipo: ASIGNACION_EQUIPO|ASIGNACION_VENDEDOR, cantidad, equipo_id|vendedor_id }
```

**POST /v1/inventario/reportar-perdida**
```
Acceso: VENDEDOR, LIDER | Body: { lote_id, cantidad, tipo: PERDIDA|DANO, motivo }
```

---

## 3.9 — Módulo ABM — Patrón CRUD

Todos los recursos administrativos siguen el mismo patrón:

| Recurso | GET lista | POST crear | PATCH /:id editar | PATCH /:id/baja |
|---|---|---|---|---|
| `/v1/admin/usuarios` | ✅ | ✅ | ✅ | ✅ |
| `/v1/admin/equipos` | ✅ | ✅ | ✅ | ✅ |
| `/v1/admin/clinicas` | ✅ | ✅ | ✅ | ✅ |
| `/v1/admin/puntos-de-venta` | ✅ | ✅ | ✅ | ✅ |
| `/v1/admin/ciudades` | ✅ | ✅ | ✅ | — |
| `/v1/admin/tabla-comisiones` | ✅ | ✅ | ✅ | ✅ |
| `/v1/admin/umbrales-lider` | ✅ | ✅ | ✅ | ✅ |
| `/v1/admin/semanas` | ✅ | ✅ (cron) | — | — |

**PATCH /:id/baja** en vez de DELETE: mantiene la convención de soft delete.
**Semanas**: la creación es automática vía cron job cada lunes. El endpoint POST existe para emergencias y tests.

---

## 3.10 — Módulo Portal Clínicas (2 endpoints)

**GET /v1/clinica/pacientes**
```
Acceso: CLINICA (filtra automáticamente por usuario.clinica_id del token)
Filtros: fecha_inicio, fecha_fin, page, limit
200: { nombre, apellido, dni, telefono, email, numero_autorizacion, fecha_venta }
Solo ventas VALIDADAS con cliente_id completo.
```

**GET /v1/clinica/pacientes/exportar**
```
Acceso: CLINICA
Mismos filtros de fecha
Respuesta: archivo Excel
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
```

---

## 3.11 — Manejo de Errores Estándar

### Códigos HTTP usados en ATENAS

| Código | Cuándo |
|---|---|
| `200` | GET o PATCH exitoso |
| `201` | POST exitoso — recurso creado |
| `400` | Request malformado o campos faltantes |
| `401` | Sin token o token vencido |
| `403` | Token válido pero rol insuficiente |
| `404` | Recurso no existe |
| `409` | Recurso ya existe (duplicado) |
| `422` | Request válido pero regla de negocio lo rechaza |
| `500` | Error inesperado del servidor |

**La distinción 400 / 409 / 422:**
```
400 → el REQUEST está roto         "Falta el campo cupon_id"
409 → CHOCA con algo existente     "Ya hay un pago para este vendedor esta semana"
422 → REGLA DE NEGOCIO lo impide   "Tu equipo no tiene PDV asignado esta semana"
```

### Catálogo de error_codes

```
Autenticación (401):  TOKEN_EXPIRADO | TOKEN_INVALIDO | SIN_TOKEN
Autorización  (403):  ROL_INSUFICIENTE | RECURSO_AJENO
Validación    (400):  CAMPO_REQUERIDO | FORMATO_INVALIDO | ARCHIVO_REQUERIDO
Negocio       (422):  CUPON_INACTIVO | SIN_ASIGNACION_PDV | VENDEDOR_INACTIVO |
                      SEMANA_CERRADA | VENTA_YA_PROCESADA | CUPON_YA_ACTIVO |
                      RENDICION_YA_CERRADA
Conflicto     (409):  PAGO_YA_REGISTRADO | TRASPASO_YA_EXISTE | DUPLICADO
Servidor      (500):  ERROR_INTERNO (nunca exponer stack trace al cliente)
```

### Errores múltiples — todos juntos

```json
{
  "success": false, "data": null,
  "message": "Los datos ingresados son inválidos",
  "error_code": "VALIDACION_FALLIDA",
  "errors": [
    "El campo cupon_id es obligatorio",
    "La forma de pago BITCOIN no es válida"
  ]
}
```

### Regla de oro: nunca exponer el stack trace

El servidor loguea el error completo internamente. Al cliente solo le llega:
```json
{ "success": false, "error_code": "ERROR_INTERNO",
  "message": "Ocurrió un error inesperado. Intentá de nuevo.", "errors": [] }
```

---

## 🔖 Para explorar después del proyecto

**Base de datos:**
- Ver con EXPLAIN ANALYZE el impacto de los índices parciales en PostgreSQL
- Comparar snapshot vs. live reference: qué pasa si cambia tabla_comision con comisiones históricas
- Lookup por límite inferior: aplicar a otros sistemas con tablas de rangos

**API REST:**
- Comparar sesiones vs. JWT en escala (1000 usuarios simultáneos)
- Simular un token robado para entender el valor del access token corto
- Ver XSS en acción para entender por qué Cookie HttpOnly protege más
- Trazar un flujo de sucesos de tus clases → implementarlo como endpoint completo
- Explorar JWT en https://jwt.io: decodificar un token real y ver su contenido
- Comparar paginación clásica vs. cursor-based en feeds de alto volumen

---

*Guía cerrada al final de la etapa de Diseño de API REST.*
*Próxima etapa: selección de stack e implementación.*
