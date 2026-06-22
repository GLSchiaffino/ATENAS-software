# ATENAS Software — Sistema de Información

> Sistema de información para empresa de venta directa. Gestiona equipos de vendedores en campo, validación de ventas, comisiones complejas y pagos semanales. Operativo en Chile y Argentina.

**Estado:** En desarrollo activo — fase de implementación backend  
**Tipo:** Proyecto Final — Ingeniería de Software, UTN

---

## ¿Qué es ATENAS?

ATENAS es una empresa de marketing directo que vende planes de servicios (dental, veterinario, automotriz) mediante vendedores en puntos de venta físicos. El sistema reemplaza un flujo operativo basado en grupos de WhatsApp y planillas Excel.

El sistema gestiona el ciclo completo:

- **Vendedor en campo** registra una venta y sube foto del comprobante desde el celular
- **Secretario** valida la venta revisando la imagen e ingresa datos del cliente
- **Tesorero** calcula comisiones, registra pagos semanales y genera reportes
- **Gerencia** administra equipos, cupones, clínicas y configuraciones globales
- **Clínicas** acceden a un portal de solo lectura con sus pacientes validados

---

## Stack técnico

| Capa | Tecnología |
|---|---|
| Backend | Java 21 + Spring Boot 3.x |
| ORM | Spring Data JPA + Hibernate |
| Seguridad | Spring Security + JWT (cookies HttpOnly) |
| Base de datos | PostgreSQL 15 |
| Build | Gradle |
| Entorno local | Docker (contenedor PostgreSQL) |

---

## Características del dominio

El sistema tiene complejidad real de negocio, no es un CRUD básico:

**Comisiones con múltiples reglas:**
- Tabla de comisiones configurable por precio de venta
- Líder de equipo comisiona por sus ventas individuales **y** por cada venta del equipo
- Umbral retroactivo: al superar N ventas semanales, todas las comisiones del líder de esa semana se recalculan al nuevo nivel
- Bono de fin de semana: cada 5 ventas en sábado/domingo genera una comisión extra
- Bono récord: al superar el récord histórico personal del día

**Registro de ventas en 19 pasos atómicos:**
El endpoint `POST /v1/ventas` ejecuta en una sola transacción: derivación del punto de venta, búsqueda de comisión, generación de código de autorización, actualización del dashboard diario, cálculo de bonos, y más.

**Soporte multimoneda:** CLP (Chile) y ARS (Argentina). Cada transacción persiste su moneda de origen.

**7 roles con permisos diferenciados:** VENDEDOR, LIDER, SECRETARIO, TESORERO, ENCARGADO_JUEGOS, CLINICA, GERENCIA.

---

## Arquitectura

```
[App web / móvil]
       ↓  REST API
[Spring Boot — Java 21]
  ├── Controller  →  recibe HTTP, valida input
  ├── Service     →  lógica de negocio
  ├── Repository  →  Spring Data JPA
  └── Entity      →  mapeo objeto-relacional
       ↓  JDBC
[PostgreSQL 15]
```

**Diseño de API:** REST con envelope estándar `{ success, data, message, error_code }`, autenticación JWT con cookies HttpOnly, RBAC por rol en cada endpoint.

---

## Documentación técnica

El proyecto incluye documentación completa de las fases de diseño:

| Documento | Descripción |
|---|---|
| [`docs/01-especificacion-funcional/`](docs/01-especificacion-funcional/) | 74 requisitos funcionales, 12 no funcionales, 23 reglas de negocio |
| [`docs/03-base-de-datos/schema.sql`](docs/03-base-de-datos/schema.sql) | Schema PostgreSQL v1.4 — 27 tablas, 16 ENUMs |
| [`docs/03-base-de-datos/seeds.sql`](docs/03-base-de-datos/seeds.sql) | Datos semilla |

---

## Cómo ejecutar localmente

### Requisitos
- Java 21
- Docker
- Gradle (o usar el wrapper `./gradlew`)

### 1. Levantar PostgreSQL

```bash
docker run --name postgres-atenas \
  -e POSTGRES_USER=atenas \
  -e POSTGRES_PASSWORD=123456 \
  -e POSTGRES_DB=atenas \
  -p 5432:5432 -d postgres:15
```

### 2. Aplicar el schema

```bash
docker cp docs/03-base-de-datos/schema.sql postgres-atenas:/schema.sql
docker exec -it postgres-atenas psql -U atenas -d atenas -f /schema.sql

docker cp docs/03-base-de-datos/seeds.sql postgres-atenas:/seeds.sql
docker exec -it postgres-atenas psql -U atenas -d atenas -f /seeds.sql
```

### 3. Configurar variables de entorno

```bash
# application-dev.yml o variables de entorno
ATENAS_DB_URL=jdbc:postgresql://localhost:5432/atenas
ATENAS_DB_USER=atenas
ATENAS_DB_PASS=123456
ATENAS_JWT_SECRET=<clave-secreta-minimo-256-bits>
```

### 4. Levantar el backend

```bash
./gradlew bootRun
```

La API estará disponible en `http://localhost:8080/v1/`

---

## Módulos implementados

- [ ] Autenticación y RBAC
- [ ] Registro de ventas
- [ ] Validación de ventas
- [ ] Comisiones y pagos
- [ ] Campañas y cupones
- [ ] Inventario de cupones
- [ ] Reportes y exportación Excel
- [ ] ABM de entidades
- [ ] Portal de clínicas
- [ ] Dashboard operacional en tiempo real

---

## Contexto académico

Proyecto Final — Materia **Ingeniería de Software**  
Universidad Tecnológica Nacional (UTN)  

El sistema está diseñado como aplicación real: el autor trabaja como vendedor en ATENAS y conoce el dominio de primera mano. La especificación funcional, el modelo de dominio y el diseño de base de datos fueron completados antes de iniciar la implementación, siguiendo el proceso de desarrollo de software de la materia.
