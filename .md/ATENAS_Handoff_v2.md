# ATENAS Software — Estado del Proyecto y Contexto de Continuación
## Documento de Handoff v2.0
> Subir este archivo a las fuentes del proyecto en Claude para contextualizar nuevas conversaciones.
> Versión anterior: Handoff v1.0 (obsoleto — reemplazado por este documento)

---

## ROL DEL CONSULTOR

Sos un consultor senior en Ingeniería de Software con experiencia en análisis de sistemas, arquitectura, diseño de bases de datos y APIs REST. Acompañás el desarrollo del proyecto final de Ingeniería de Software de la UTN.

**Reglas vigentes:**
- Cuando el usuario haga sugerencias de diseño, dar opinión brevemente antes de proceder
- Dar explicaciones educativas junto con cada decisión técnica (primera vez que aparece el concepto)
- Presentar opciones con tradeoffs y dejar que el usuario decida
- Mantener consistencia entre TODOS los documentos del proyecto simultáneamente

---

## CONTEXTO DEL NEGOCIO

**ATENAS Software** es un sistema de información para ATENAS, empresa de marketing y venta directa que actúa como intermediario entre proveedores de servicios (clínicas dentales, veterinarias, automotrices) y el público general. Opera en **Chile** (CLP) y **Argentina** (ARS).

- Los vendedores abordan clientes en la vía pública y centros comerciales
- El producto es un **cupón físico** con dos partes: una para el cliente, una para el vendedor
- El sistema gestiona: ventas, validaciones, comisiones, inventario de cupones, pagos semanales y dashboard operacional en tiempo real

**El proyecto tiene doble propósito:**
1. Proyecto final de la materia Ingeniería de Software (UTN)
2. Sistema real aplicable al negocio — el desarrollador trabaja como vendedor en ATENAS

---

## ACTORES DEL SISTEMA

| Actor | Descripción |
|---|---|
| **Vendedor** | Registra ventas en campo, sube comprobante fotográfico |
| **Líder de Equipo** | También es vendedor. Supervisa equipo, comisiona doble (individual + equipo) |
| **Secretario de Ventas** | Valida ventas revisando imágenes, ingresa datos del cliente |
| **Tesorero** | Registra pagos semanales, reportes financieros, configura comisiones |
| **Encargado de Juegos** | Estadísticas solo lectura + gestión de juegos diarios (V2) |
| **Clínica** | Solo lectura de sus propios pacientes validados (portal web) |
| **Gerencia** | Control total del sistema |
| **Cliente** | NO es usuario del sistema. Datos ingresados por Secretario al validar |

---

## ETAPAS COMPLETADAS

### ✅ Etapa 1 — Especificación Funcional
Archivo: `ATENAS_Especificacion_Funcional_v1_0.md`
- 7 módulos, 33 requisitos funcionales, 12 no funcionales
- Todas las reglas de negocio documentadas y cerradas

### ✅ Etapa 2 — Modelo de Dominio
27 entidades en 8 clusters:
1. Geográfico: `Pais`, `Ciudad`, `PuntoDeVenta`
2. Organizacional: `Equipo`, `Usuario`
3. Comercial: `Clinica`, `Cupon`, `Cliente`
4. Transacción Central: `Venta`, `ImagenVenta`, `TraspasoVenta`, `AsignacionEquipoPunto`
5. Dashboard: `JornadaDiaria` (global), `JornadaVendedor` (individual)
6. Comisiones y Pagos: `TablaComision`, `UmbralLider`, `SemanaLaboral`, `RegistroComision`, `PagoVendedor`, `RendicionEfectivo`
7. Inventario: `LoteIngresoCupones`, `MovimientoCupon`
8. Sistema: `NotificacionInterna`, `LogAuditoria`
9. Juegos V2: `Juego`, `RegistroJuego`, `PremioJuego`

### ✅ Etapa 3 — Diseño de Base de Datos
Motor: PostgreSQL 15+
Archivos: `schema.sql` (v1.4, 732 líneas) y `seeds.sql` (v1.4, 98 líneas)

### ✅ Etapa 4 — Diseño de API REST
Todos los módulos diseñados. Ver sección completa más abajo.

---

## SCHEMA v1.4 — DECISIONES CLAVE

### Convenciones
- **PK:** UUID con gen_random_uuid()
- **Fechas:** TIMESTAMPTZ (Chile UTC-3/-4, Argentina UTC-3)
- **Dinero:** NUMERIC(12,2)
- **Soft delete:** `fecha_baja TIMESTAMPTZ` (NULL = activo, NOT NULL = dado de baja)
- **FK manuales:** PostgreSQL no las indexa solo
- **FK diferidas:** `equipo.lider_id` → DEFERRABLE INITIALLY DEFERRED (circular con usuario)
- **FK post-CREATE:** `venta.rendicion_efectivo_id` y `venta.jornada_vendedor_id` (dependencias cruzadas)

### Decisiones de diseño cerradas

| ID | Decisión | Resolución |
|---|---|---|
| DD-01 | Deduplicación de Cliente | DNI UNIQUE en tabla cliente |
| DD-02 | Formato descuento en Cupón | `precio_con_descuento NUMERIC(12,2)` explícito |
| DD-03 | PuntoDeVenta en Venta | Derivado automáticamente del equipo, guardado en venta |
| DD-04 | Creación de SemanaLaboral | Automática por cron job cada lunes |
| DD-05 | Versioning de TablaComision | Sin versioning. RegistroComision persiste el monto histórico |
| DD-06 | Estrategia Usuario | STI: tabla única con campo `rol` ENUM |
| DD-07 | Efecto del traspaso | Se actualiza `venta.cupon_id` al destino |
| DD-08 | Jornada diaria | Jerarquía: jornada_diaria (global) → jornada_vendedor (individual) |
| DD-09 | Umbral líder | Solo `ventas_desde` (lookup por límite inferior, sin ventas_hasta) |
| DD-10 | Rendición efectivo | Ciclo automático: se crea al 1er efectivo de la semana, ABIERTA→CERRADA |
| DD-11 | Canal de pagos de juegos | PREMIO_JUEGO entra al ENUM comision_tipo — canal unificado |
| DD-12 | Portal clínicas | Adelantado de V3 a V1: rol CLINICA + equipo CLINICAS semilla |
| DD-13 | PDV en venta | Derivado automáticamente (no seleccionado por el vendedor) |

### ENUMs del sistema
```
moneda_tipo:       CLP | ARS
usuario_rol:       VENDEDOR | LIDER | SECRETARIO | TESORERO | ENCARGADO_JUEGOS | GERENCIA | CLINICA
equipo_categoria:  CAMPO | ADMINISTRACION | FINANZAS | GERENCIA | CLINICAS
cupon_estado:      BORRADOR | ACTIVO | INACTIVO
forma_pago_tipo:   EFECTIVO | TRANSFERENCIA | POSNET_CREDITO | POSNET_DEBITO | MERCADOPAGO | WEBPAY
autorizacion_origen: EXTERNO | INTERNO
venta_estado:      PENDIENTE | VALIDADA | INVALIDA
semana_estado:     ABIERTA | CERRADA
movimiento_tipo:   ASIGNACION_EQUIPO | ASIGNACION_VENDEDOR | PERDIDA | DANO | DEVOLUCION
comision_tipo:     VENDEDOR_INDIVIDUAL | LIDER_EQUIPO | BONO_FIN_SEMANA | BONO_RECORD | PREMIO_JUEGO
notificacion_tipo: VENTA_FUERA_CAMPANA
auditoria_operacion: (9 valores — ver schema)
inscripcion_tipo:  MANUAL | AUTO_VENTA
rendicion_estado:  ABIERTA | CERRADA
juego_tipo:        FOTOS_CLIENTES | ROBOS | POZO_DEL_DIA (V2)
juego_estado:      ABIERTO | CERRADO (V2)
```

### Reglas de negocio críticas
- Una venta no puede cancelarse. Solo puede registrarse un traspaso (máximo uno)
- Cupón INACTIVO → estado terminal, no vuelve a ACTIVO
- Pagos los martes. Cubren la semana laboral anterior (lunes a domingo)
- Comisiones del líder: retroactivas al cruzar umbral. UPDATE en lote sobre registro_comision
- Bono fin de semana: cada 5 ventas en sáb/dom = 1 comisión extra del tier mínimo
- Bono récord: al superar record_ventas_dia → 1 bono por jornada máximo (flag record_superado_hoy)
- Efectivo → autorización INTERNA. Electrónico → autorización EXTERNA del comprobante
- Rendición de efectivo: creada automáticamente al 1er efectivo de la semana. Cerrada por el líder
- El PDV de cada venta se deriva del equipo del vendedor (asignacion_equipo_punto de la semana)

---

## API REST v1 — DISEÑO COMPLETO

**Base URL:** `https://api.atenas.com/v1/`
**Auth:** Cookie HttpOnly (access 15 min + refresh 7 días)
**Formato:** Envelope estándar `{ success, data, message, error_code, errors }`
**Paginación:** `?page=1&limit=20` → `{ pagination: { page, limit, total, total_pages } }`

### Módulo Auth
```
POST   /v1/auth/login          → genera tokens, setea cookies
POST   /v1/auth/refresh        → renueva access token silenciosamente
POST   /v1/auth/logout         → borra cookies
GET    /v1/auth/me             → perfil del usuario autenticado
```

### Módulo Ventas
```
POST   /v1/ventas              → registrar venta (multipart: cupon_id, forma_pago, aplico_descuento, imagen)
GET    /v1/ventas              → listar ventas (RBAC filtra automáticamente por rol)
GET    /v1/ventas/:id          → detalle de una venta
```
El POST dispara 19 pasos en una transacción: PDV derivado, comisiones, bonos, jornada, rendición efectivo.

### Módulo Validación
```
GET    /v1/ventas/pendientes   → cola del secretario con imagen visible
PATCH  /v1/ventas/:id/validar  → VALIDAR (con datos cliente) o INVALIDAR (con observaciones)
POST   /v1/ventas/:id/traspaso → cambiar clínica (solo GERENCIA en MVP)
```

### Módulo Dashboard
```
GET    /v1/dashboard           → vista completa por equipos (polling 30s en V1)
PATCH  /v1/jornadas/hoy        → check-in manual o actualizar meta del día
GET    /v1/dashboard/ranking   → ranking diario o semanal
```

### Módulo Comisiones y Pagos
```
GET    /v1/comisiones                              → mis comisiones / equipo / todas (RBAC)
GET    /v1/semanas/:id/resumen-pago/:vendedor_id  → desglose previo al pago
POST   /v1/pagos                                   → registrar pago semanal (TESORERO/GERENCIA)
PATCH  /v1/rendiciones/:id/cerrar                 → confirmar recepción de efectivo (LIDER)
```

### Módulo Campañas e Inventario
```
POST   /v1/cupones                   → crear cupón en BORRADOR
PATCH  /v1/cupones/:id/activar       → BORRADOR → ACTIVO (verifica unicidad por clínica)
PATCH  /v1/cupones/:id/desactivar    → ACTIVO → INACTIVO (irreversible)
POST   /v1/inventario/lotes          → registrar ingreso de cupones físicos
POST   /v1/inventario/movimientos    → asignar cupones (equipo o vendedor)
POST   /v1/inventario/reportar-perdida → reportar pérdida o daño
```

### Módulo ABM (patrón CRUD por recurso)
```
/v1/admin/usuarios | equipos | clinicas | puntos-de-venta | ciudades
/v1/admin/tabla-comisiones | umbrales-lider | semanas
Verbos: GET (lista) | POST (crear) | PATCH /:id (editar) | PATCH /:id/baja (soft delete)
```

### Módulo Portal Clínicas
```
GET    /v1/clinica/pacientes          → lista paginada de pacientes validados (filtrada por clinica_id del token)
GET    /v1/clinica/pacientes/exportar → Excel descargable
```

### Manejo de Errores
```
400 CAMPO_REQUERIDO | FORMATO_INVALIDO | ARCHIVO_REQUERIDO
401 TOKEN_EXPIRADO  | TOKEN_INVALIDO   | SIN_TOKEN
403 ROL_INSUFICIENTE | RECURSO_AJENO
404 RECURSO_NO_ENCONTRADO
409 PAGO_YA_REGISTRADO | TRASPASO_YA_EXISTE | DUPLICADO
422 CUPON_INACTIVO | SIN_ASIGNACION_PDV | VENDEDOR_INACTIVO | SEMANA_CERRADA |
    VENTA_YA_PROCESADA | CUPON_YA_ACTIVO | RENDICION_YA_CERRADA
500 ERROR_INTERNO (nunca exponer stack trace)
```

---

## ARCHIVOS DEL PROYECTO

```
/
├── docs/
│   ├── 01-especificacion-funcional/
│   │   └── ATENAS_EF_v1.0.md
│   ├── 02-modelo-dominio/
│   │   └── (diagramas en DBeaver — pendiente exportar)
│   ├── 03-base-de-datos/
│   │   ├── schema.sql          ← v1.4 | 732 líneas | 27 tablas | 16 ENUMs
│   │   ├── seeds.sql           ← v1.4 | países + 4 equipos admin semilla
│   │   └── schema_oracle.sql   ← versión Oracle para SQL Developer Data Modeler
│   └── 04-api-rest/
│       └── (pendiente documentar endpoints formalmente)
├── ATENAS_Handoff_v2.md        ← este archivo
└── ATENAS_Guia_Aprendizaje.md  ← guía de aprendizaje completa (815 líneas)
```

---

## PRÓXIMA ETAPA — Implementación

Lo que falta antes de escribir código:

### 1. Selección de Stack (pendiente de decisión)
Opciones comunes para este tipo de proyecto:

| Capa | Opciones |
|---|---|
| Backend | Node.js + Express/Fastify · Python + FastAPI · Java + Spring Boot |
| Frontend | React · Vue · Angular |
| ORM | Prisma (Node) · SQLAlchemy (Python) · Hibernate (Java) |
| Auth | JWT + bcrypt |
| Storage imágenes | S3 / Cloudinary / filesystem local |
| Cron jobs | node-cron · APScheduler · Spring Scheduler |

### 2. Estructura del proyecto backend
- Carpetas: routes, controllers, services, middlewares, models
- Middleware de autenticación (verifica JWT en cada request)
- Middleware de RBAC (verifica rol contra endpoint)
- Manejo centralizado de errores

### 3. Orden de implementación sugerido
1. Setup del proyecto + conexión a BD
2. Middleware auth + endpoints /auth/*
3. Módulo Ventas (POST /ventas es el más complejo — validar primero)
4. Módulo Validación
5. Dashboard
6. Comisiones y Pagos
7. Campañas e Inventario
8. ABM
9. Portal Clínicas
10. Testing + documentación

---

## PENDIENTES MENORES

| ID | Punto | Impacto |
|---|---|---|
| PD-001 | Datos exactos del Excel exportado a clínicas (confirmar con gerencia) | RF-027 — ajuste menor antes de implementar |
| PD-002 | Exportar diagramas ER de DBeaver como imágenes | Documentación técnica |
| PD-003 | Diagrama ComisionesYPagos pendiente de revisión visual en DBeaver | Validar relaciones del circuito 4 |

---

## CÓMO USAR ESTE DOCUMENTO EN UNA NUEVA CONVERSACIÓN

1. Subir este archivo a las fuentes del proyecto en Claude
2. Iniciar la conversación con este prompt:

```
Leé el archivo ATENAS_Handoff_v2.md antes de responder.
Somos el proyecto ATENAS Software. Ya completamos:
- Especificación funcional
- Modelo de dominio
- Base de datos (schema v1.4, PostgreSQL)
- Diseño de API REST (todos los módulos)

Próxima etapa: [DESCRIBIR LO QUE QUERÉS HACER]

Recordá las reglas: dar opinión breve ante mis sugerencias,
explicar conceptos nuevos, mantener consistencia entre documentos.
```

---

*Handoff v2.0 — Generado al cierre de la Etapa de Diseño de API REST.*
*Próxima etapa: Selección de stack e implementación del backend.*
