# ATENAS — Estado del Proyecto y Contexto de Continuación
## Documento de Handoff v1.0
> Subir este archivo a las fuentes del proyecto en Claude para que esté disponible en nuevas conversaciones.

---

## ROL DEL CONSULTOR

Sos un consultor senior en Ingeniería de Software con experiencia en análisis de sistemas, arquitectura de software, diseño de bases de datos y gestión de proyectos. Estás acompañando el desarrollo del proyecto final de la materia Ingeniería de Software de la UTN.

**Regla vigente**: cuando el usuario haga sugerencias de diseño, dar opinión brevemente antes de proceder.

---

## CONTEXTO DEL NEGOCIO

**ATENAS** es una empresa de marketing y venta directa que actúa como intermediario entre proveedores de servicios (clínicas dentales, veterinarias, automotrices) y el público general. Opera actualmente en **Chile** y está iniciando en **Argentina**.

- Los vendedores abordan clientes en la vía pública y centros comerciales.
- El producto es un **cupón físico** con dos partes: una para el cliente, una para el vendedor.
- ATENAS vende planes anuales de servicios de las clínicas.
- El sistema gestiona ventas, comisiones, campañas, inventario de cupones y pagos semanales.

---

## ACTORES DEL SISTEMA

| Actor | Descripción clave |
|---|---|
| **Vendedor** | Registra ventas en campo, sube comprobante fotográfico |
| **Líder de Equipo** | También es vendedor. Supervisa equipo, comisiona doble (individual + equipo) |
| **Secretario de Ventas** | Valida ventas revisando imágenes, ingresa datos del cliente |
| **Tesorero** | Registra pagos semanales, accede a reportes financieros |
| **Encargado de Juegos** | Estadísticas (solo lectura) + gestión de juegos diarios (V2) |
| **Gerencia** | Control total del sistema |
| **Cliente** | NO es usuario del sistema. Datos ingresados por el Secretario al validar |

---

## ETAPAS COMPLETADAS

### ✅ Etapa 1 — Especificación Funcional
Archivo: `ATENAS_Especificacion_Funcional_v1_0.md`
Estado: Cerrado. Todos los pendientes resueltos.

### ✅ Etapa 2 — Modelo de Dominio
**24 entidades** organizadas en 8 clusters:
1. Geográfico: `Pais`, `Ciudad`, `PuntoDeVenta`
2. Organizacional: `Equipo`, `Usuario`
3. Comercial: `Clinica`, `Cupon`, `Cliente`
4. Transacción Central: `Venta`, `ImagenVenta`, `TraspasoVenta`
5. Comisiones y Pagos: `TablaComision`, `UmbralLider`, `SemanaLaboral`, `RegistroComision`, `PagoVendedor`, `RendicionEfectivo`
6. Inventario: `LoteIngresoCupones`, `MovimientoCupon`
7. Sistema: `NotificacionInterna`, `LogAuditoria`
8. Juegos V2: `Juego`, `RegistroJuego`, `PremioJuego`

Nueva entidad agregada post-modelo: **`AsignacionEquipoPunto`** (historial de qué equipo operó en qué PDV en qué semana).

### ✅ Etapa 3 — Diseño de Base de Datos
Archivos: `docs/03-base-de-datos/schema.sql` y `seeds.sql`
Motor: PostgreSQL 15+
- 25 tablas con todos los constraints
- 14 tipos ENUM
- ~50 índices (FK + performance)
- Partial unique index para cupón activo por clínica

---

## DECISIONES DE DISEÑO — TODAS CERRADAS

| ID | Decisión | Resolución |
|---|---|---|
| DD-01 | Deduplicación de Cliente | DNI UNIQUE en tabla cliente |
| DD-02 | Formato descuento en Cupón | `precio_con_descuento NUMERIC(12,2)` — precio explícito |
| DD-03 | PuntoDeVenta en Venta | `punto_de_venta_id` almacenado explícitamente |
| DD-04 | Creación de SemanaLaboral | Automática por cron job cada lunes |
| DD-05 | Versioning de TablaComision | Sin versioning. RegistroComision persiste el monto histórico |
| DD-06 | Estrategia Usuario | STI: tabla única `usuario` con campo `rol` ENUM |
| DD-07 | Efecto del traspaso | Al traspasar se actualiza `venta.cupon_id` al destino |

### Decisiones adicionales del modelo de dominio

**Equipo con `tipo`**: los equipos tienen `tipo ENUM('CAMPO','ADMINISTRACION','FINANZAS','GERENCIA')`. No hay nulls en `usuario.equipo_id` — todos los usuarios pertenecen a un equipo real (los de oficina a equipos admin semilla).

**`lider_id` en Equipo**: nullable. Solo obligatorio para tipo = 'CAMPO'. Enforced con CHECK constraint.

**`fuera_de_campana` en Venta**: es un flag BOOLEAN independiente del `estado`. Una venta con cupón inactivo sigue el flujo normal PENDIENTE→VALIDADA/INVALIDA; el flag es informativo.

**`prestaciones` en Cupón**: `VARCHAR(500)` texto libre, editable. No es enum ni multi-valuado.

**PuntoDeVenta**: NO tiene `equipo_id` directo. La relación equipo↔PDV es M:N histórica a través de `AsignacionEquipoPunto`.

---

## DECISIONES TÉCNICAS DE BASE DE DATOS

**UUID para PKs**: evita colisiones entre datos de Argentina y Chile, y enumeration attacks en la API.

**TIMESTAMPTZ para todos los datetimes**: ATENAS opera en Chile (UTC-3/-4 con horario de verano) y Argentina (UTC-3 fijo). TIMESTAMPTZ guarda en UTC internamente, evitando ambigüedades al cruzar cambios de horario.

**FK DEFERRABLE INITIALLY DEFERRED** en `equipo.lider_id`: resuelve la referencia circular equipo↔usuario. La FK se verifica al COMMIT de la transacción, no al ejecutar cada sentencia.

**Partial UNIQUE INDEX** `WHERE estado = 'ACTIVO'` en cupón: implementa la regla "solo un cupón activo por clínica" sin romper el historial. Un UNIQUE normal impediría tener múltiples cupones históricos.

**FK indexes manuales**: PostgreSQL no indexa automáticamente las FK. Se crearon índices explícitos en todas las FK + índices de negocio para las queries más frecuentes.

**NUMERIC(12,2)** para valores monetarios: precisión exacta, sin errores de punto flotante. Soporta CLP (sin decimales reales) y ARS con el mismo tipo.

---

## REGLAS DE NEGOCIO CRÍTICAS (recordatorio rápido)

- Una venta no puede cancelarse. Solo puede registrarse un traspaso (máximo uno).
- Cupón INACTIVO → estado terminal, no vuelve a ACTIVO.
- Pagos los martes. Cubren la semana laboral anterior (lunes a domingo).
- Comisiones del líder: retroactivas al cruzar umbral semanal. RegistroComision guarda los montos y se actualiza si la SemanaLaboral está ABIERTA.
- Bono fin de semana: cada 5 ventas en sábado/domingo = 1 comisión extra del tier mínimo.
- Efectivo → autorización INTERNA generada por el sistema. Electrónico → autorización EXTERNA del comprobante.
- Rendición de efectivo: el LÍDER la registra al recibir físicamente el dinero del vendedor.

---

## ARCHIVOS DEL PROYECTO

```
/
├── docs/
│   ├── 01-especificacion-funcional/
│   │   └── ATENAS_EF_v1.0.md
│   ├── 02-modelo-dominio/
│   │   └── (ERDs en la conversación — pendiente exportar imágenes)
│   └── 03-base-de-datos/
│       ├── schema.sql     ← 25 tablas, 14 ENUMs, ~50 índices
│       └── seeds.sql      ← países + equipos admin semilla
└── ATENAS_Handoff_v1.md   ← este archivo
```

---

## PRÓXIMA ETAPA: Diseño de API REST

Lo que falta definir antes de escribir código:
1. Estructura general de la API (prefijo base, versionado, formato de respuestas)
2. Estrategia de autenticación (JWT, refresh tokens, expiración de sesión — RNF-002)
3. Manejo de errores estándar
4. Endpoints por módulo (ventas, validación, comisiones, pagos, administración)
5. Contratos request/response para cada endpoint
6. Reglas de autorización por rol en cada endpoint (RBAC — RNF-003)

---

## STACK TECNOLÓGICO (pendiente de decisión)

No se ha definido el stack. Opciones comunes para este tipo de proyecto:

**Backend**: Node.js + Express/Fastify | Python + FastAPI/Django | Java + Spring Boot
**Frontend**: React | Vue | Angular
**ORM**: Prisma (Node) | SQLAlchemy (Python) | Hibernate (Java)
**Auth**: JWT + bcrypt
**Almacenamiento de imágenes**: S3 / Cloudinary / sistema de archivos local

---

*Documento generado al cierre de la Etapa 3 — Base de Datos. Próxima conversación: Etapa 4 — API REST.*
