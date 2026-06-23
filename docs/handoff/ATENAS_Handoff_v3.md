# ATENAS Software — Estado del Proyecto y Contexto de Continuación
## Documento de Handoff v3.0
> Subir este archivo a las fuentes del proyecto en Claude para contextualizar nuevas conversaciones.
> Versión anterior: Handoff v2.0 (obsoleto — reemplazado por este documento)

---

## ROL DEL CONSULTOR

Sos un consultor senior en Ingeniería de Software con experiencia en análisis de sistemas, arquitectura, diseño de bases de datos y APIs REST. Acompañás el desarrollo del proyecto final de Ingeniería de Software de la UTN.

**Reglas vigentes:**
- Cuando el usuario haga sugerencias de diseño, dar opinión brevemente antes de proceder
- Dar explicaciones educativas junto con cada decisión técnica (primera vez que aparece el concepto)
- Presentar opciones con tradeoffs y dejar que el usuario decida
- Mantener consistencia entre TODOS los documentos del proyecto simultáneamente
- **MODO PROFESOR (vigente desde Etapa 5):** El usuario NO tiene experiencia con Spring Boot ni Spring Security. Quiere aprender chocándose con los conceptos. Explicar cada concepto nuevo como si no supiera nada, pero asumiendo conocimientos técnicos básicos (Java, POO, SQL). Está bien demorarse para hacerlo didáctico — esa es la intención del proyecto.
- **Respuestas concisas:** el usuario prefiere explicaciones breves junto al código/solución.

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

### 🔄 Etapa 5 — Implementación Backend (EN CURSO)
Stack confirmado e implementación iniciada. Ver sección "ESTADO DE IMPLEMENTACIÓN" más abajo.

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

Repo: `github.com/GLSchiaffino/ATENAS-software` (rama `main`)

```
ATENAS-software/
├── README.md                     ← README principal (descripción, stack, setup)
├── LICENSE
├── backend/                      ← proyecto Spring Boot
│   ├── build.gradle
│   ├── gradlew / gradlew.bat
│   ├── .gitignore                ← ignora build/, .idea/, application-local.yml
│   └── src/
│       ├── main/
│       │   ├── java/com/atenas/backend/
│       │   │   └── BackendApplication.java
│       │   └── resources/
│       │       ├── application.yml         ← config base (al repo, sin secretos)
│       │       ├── application-local.yml   ← credenciales (NO al repo, ignorado)
│       │       ├── static/
│       │       └── templates/
│       └── test/
└── docs/
    ├── 01-especificacion-funcional/
    │   └── ATENAS_Especificacion_Funcional_v1.0.md
    ├── 02-modelo-dominio/
    │   ├── atenas_erd_final_v2.html
    │   ├── atenas_erd_diagrams.html
    │   ├── atenas_erd_diagram2_zoom.html
    │   └── atenas_flujo_venta.svg
    ├── 03-base-de-datos/
    │   ├── schema.sql            ← v1.4 vigente | 27 tablas | 16 ENUMs
    │   ├── seeds.sql             ← v1.4
    │   ├── schema_oracle.sql
    │   ├── diagramas/            ← PNG del circuito de venta, estructura comercial, inventario
    │   └── historico/           ← v1.1 y v1.3 archivadas (evolución de diseño)
    ├── 04-api-rest/
    │   └── auth_silent_refresh_flow.svg
    ├── 05-guia-aprendizaje/
    │   └── ATENAS_Guia_Aprendizaje.md   ← incluye FASE 4 (Spring Boot, IoC, secretos)
    ├── handoff/
    │   └── ATENAS_Handoff_v3.md         ← este archivo
    └── presentacion/
        ├── presentacion_atenas.html
        └── presentacion_atenas_celular.html
```

**Nota sobre reorganización:** El repo fue reestructurado de carpetas-por-tipo a carpetas-por-etapa. Se eliminó andamiaje interno (handoff v1, prompts de contexto de ChatGPT, PDFs internos). Se conservaron las versiones históricas de BD (v1.1, v1.3) para mostrar la evolución del diseño.

---

## ESTADO DE IMPLEMENTACIÓN (Etapa 5)

### Stack confirmado

| Capa | Tecnología | Notas |
|---|---|---|
| Runtime | Java 21 (LTS) | JDK 21 descargado vía IntelliJ (Temurin/MS). Sistema tiene Java 17 en PATH — conviven sin conflicto |
| Framework | Spring Boot 4.1.0 | — |
| ORM | Spring Data JPA + Hibernate 7.4 | `ddl-auto: validate` (schema.sql es la fuente de verdad, Hibernate NO modifica la BD) |
| Seguridad | Spring Security + JWT | Configuración pendiente (Bloque 3). Por ahora Security activo con login autogenerado |
| Validación | Bean Validation | — |
| Excel | Apache POI | Pendiente (módulo Portal Clínicas) |
| Cron | Spring `@Scheduled` | Pendiente (semana_laboral) |
| Build | Gradle (Groovy DSL) | — |
| BD | PostgreSQL 15 (Docker) | Contenedor `postgres-atenas`, puerto 5432, credenciales atenas/123456/atenas |
| IDE | IntelliJ IDEA | Recomendado por soporte Java/Spring superior |
| Lombok | Sí | ⚠️ REGLA: `@Data` solo en DTOs, NUNCA en entities (rompe con FK circular y lazy loading) |

### Estructura de paquetes objetivo

```
com.atenas.backend/
├── config/       → SecurityConfig, CorsConfig, JwtConfig
├── controller/   → un controller por módulo
├── service/      → lógica de negocio (los 19 pasos viven acá)
├── repository/   → interfaces JPA (una por entidad)
├── entity/       → clases JPA (mapeadas al schema v1.4)
├── dto/          → request/response (NUNCA exponer entities)
│   ├── request/
│   └── response/
├── exception/    → excepciones custom + GlobalExceptionHandler
├── scheduler/    → cron de semana_laboral
└── util/         → JwtUtil, generador código EF-YYYYMMDD-NNNNN
```

### Decisiones de configuración tomadas

| ID | Decisión | Resolución |
|---|---|---|
| IMP-01 | Formato de config | YAML (`application.yml`), no `.properties` — estándar moderno |
| IMP-02 | Gestión de secretos | `application.yml` (al repo, lee variables) + `application-local.yml` (ignorado por Git, credenciales reales) |
| IMP-03 | Zona horaria | UTC forzado vía `-Duser.timezone=UTC` (VM option). El contenedor postgres:15 no reconocía America/Buenos_Aires. Decisión de fondo: UTC en BD, conversión a hora local en presentación (soporte multi-país CLP/ARS) |
| IMP-04 | Storage de imágenes | Filesystem local para MVP, con interfaz abstracta (StorageService) para migrar a S3 después sin tocar el resto |
| IMP-05 | ddl-auto | `validate` — Hibernate verifica entities contra tablas pero no modifica el schema |

### Progreso por bloques de implementación

```
✅ BLOQUE 0 — Setup y conexión a BD              COMPLETADO
   · Proyecto Spring Boot creado (Spring Initializr)
   · Dependencias: Web, JPA, PostgreSQL, Security, Validation, Lombok
   · .gitignore configurado (build/, .idea/, secretos)
   · Conexión a PostgreSQL exitosa
   · App arranca: "Started BackendApplication" en puerto 8080
   · Commiteado y pusheado a GitHub

⬜ BLOQUE 1 — Estructura + primer endpoint        ← PRÓXIMO
   · @RestController: GET /v1/health
   · Envelope de respuesta estándar { success, data, message }
   · SecurityConfig: permitir /v1/health sin login (primer roce con Security)
   · Ver JSON en navegador

⬜ BLOQUE 2 — Entities JPA (27 tablas)            ← acá ENTRA Claude Code
   · Explicar @Entity, @Id, @ManyToOne con 1-2 entities en chat
   · Manejar FK circular equipo ↔ usuario
   · Una vez entendido el patrón → Claude Code genera las 25 restantes

⬜ BLOQUE 3 — Auth + Spring Security              ← lo más didáctico, NO delegar
   · JWT: generación, validación, cookies HttpOnly
   · Los 4 endpoints /auth/*
   · Middleware RBAC por rol

⬜ BLOQUE 4 — Módulo Ventas
   · POST /ventas: los 19 pasos, @Transactional (análisis detallado pendiente)
   · GET /ventas con filtros RBAC

⬜ BLOQUES 5-9 — Resto de módulos (varios con Claude Code para CRUD repetitivo)
⬜ BLOQUE 10 — Testing + documentación
```

### Estrategia de uso de Claude Code

Regla acordada: **Claude Code para lo repetitivo una vez que el usuario entiende el patrón. Claude chat para conceptos nuevos y lógica compleja.**
- Entra por primera vez en el **Bloque 2** (entities), después de hacer 1-2 entities juntos en el chat.
- Vuelve en los **Bloques 5-9** para el CRUD repetitivo del ABM.
- NO se usa para Spring Security (Bloque 3) ni para el POST /ventas (Bloque 4) — esos requieren entender primero.

### Riesgos técnicos identificados (a vigilar durante implementación)

1. **`@Transactional` del POST /ventas:** 19 pasos en una transacción. Cuidado con qué excepciones disparan rollback. Análisis detallado pendiente para el Bloque 4.
2. **FK circular equipo ↔ usuario:** usar DTOs para evitar serialización circular. NUNCA `@Data` ni `@ToString` en estas entities.
3. **N+1 queries en dashboard:** diseñar los `@Query` con `JOIN FETCH` desde el principio. Explicar el problema en detalle cuando se llegue al dashboard.

---

## PENDIENTES MENORES

| ID | Punto | Impacto |
|---|---|---|
| PD-001 | Datos exactos del Excel exportado a clínicas (confirmar con gerencia) | RF-027 — ajuste menor antes de implementar |
| PD-002 | Exportar diagramas ER de DBeaver y commitearlos al repo | Documentación técnica — ver instrucciones abajo |

### PD-002 — Dónde guardar los diagramas de DBeaver

**Desde DBeaver:**
Click derecho en el canvas del diagrama → **Save Diagram as Image** → PNG

**Carpeta destino en el repo:**
```
docs/
└── 02-modelo-dominio/
    ├── diagrama_01_circuito_venta.png
    ├── diagrama_02_estructura_comercial.png
    ├── diagrama_03_inventario_sistema.png
    └── diagrama_04_comisiones_pagos.png
```

**Los 4 grupos de tablas por diagrama:**
1. CircuitoVenta: `cliente`, `venta`, `jornada_vendedor`, `imagen_venta`, `jornada_diaria`, `usuario`, `semana_laboral`, `traspaso_venta`
2. EstructuraComercial: `punto_de_venta`, `ciudad`, `pais`, `asignacion_equipo_punto`, `equipo`, `clinica`, `cupon`, `usuario`
3. InventarioSistema: `juego`, `premio_juego`, `log_auditoria`, `notificacion_interna`, `registro_juego`, `usuario`, `cupon`, `movimiento_cupon`, `lote_ingreso_cupones`
4. ComisionesYPagos: `rendicion_efectivo`, `semana_laboral`, `premio_juego`, `usuario`, `pago_vendedor`, `umbral_lider`, `tabla_comision`, `registro_comision`

Commitear con:
```bash
git add docs/02-modelo-dominio/
git commit -m "docs(diagrams): diagramas ER por circuito exportados desde DBeaver"
```

---

## CÓMO USAR ESTE DOCUMENTO EN UNA NUEVA CONVERSACIÓN

1. Subir este archivo a las fuentes del proyecto en Claude
2. Iniciar la conversación con este prompt:

```
Leé el archivo ATENAS_Handoff_v3.md antes de responder.
Somos el proyecto ATENAS Software. Ya completamos el diseño
(especificación, dominio, BD schema v1.4, API REST) y arrancamos
la implementación del backend en Spring Boot.

Estado: Bloque 0 completado (proyecto creado, conectado a PostgreSQL,
corriendo en puerto 8080). Próximo: Bloque 1 (primer endpoint /v1/health).

Seguimos en MODO PROFESOR: explicame los conceptos nuevos de Spring
como si no supiera nada, con respuestas concisas. Recordá las reglas:
opinión breve ante mis sugerencias, consistencia entre documentos.
```

---

*Handoff v3.0 — Generado al cierre del Bloque 0 de implementación.*
*Próximo hito: Bloque 1 — primer endpoint REST (/v1/health) + envelope de respuesta + primer roce con SecurityConfig.*
