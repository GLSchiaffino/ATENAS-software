-- ================================================================
-- ATENAS — Sistema de Información
-- Esquema de Base de Datos v1.1  |  PostgreSQL 15+
-- Proyecto Final UTN — Ingeniería de Software
-- ================================================================
--
-- Convenciones generales:
--   · PK     : UUID con gen_random_uuid() (independencia del motor, seguridad)
--   · Fechas : TIMESTAMPTZ — zona horaria incluida (Chile UTC-3/-4, AR UTC-3)
--   · Dinero : NUMERIC(12,2) — precisión exacta, sin punto flotante
--   · Texto  : VARCHAR(n) con límite semántico | TEXT sin límite
--   · Borrado: soft delete con campo `activo BOOLEAN` — no hay DELETE
--   · FK     : indexadas manualmente (PostgreSQL no las indexa solo)
--
-- Orden de creación respeta dependencias entre tablas.
-- La referencia circular equipo ↔ usuario se resuelve con FK DEFERRABLE.
--
-- Cambios v1.1 (Dashboard operacional):
--   · ENUM comision_tipo    → nuevo valor BONO_RECORD
--   · ENUM inscripcion_tipo → nuevo tipo (MANUAL, AUTO_VENTA)
--   · equipo                → campo emoji
--   · usuario               → campos emoji_personal, meta_ventas_default,
--                             record_ventas_dia
--   · NUEVO CLUSTER 4.5     → tabla jornada_diaria
--   · Índices               → nuevos índices para dashboard
-- ================================================================

-- ----------------------------------------------------------------
-- TIPOS ENUMERADOS
-- ----------------------------------------------------------------

CREATE TYPE moneda_tipo          AS ENUM ('CLP', 'ARS');

CREATE TYPE usuario_rol          AS ENUM (
    'VENDEDOR', 'LIDER', 'SECRETARIO',
    'TESORERO', 'ENCARGADO_JUEGOS', 'GERENCIA'
);

CREATE TYPE equipo_categoria     AS ENUM (
    'CAMPO',            -- equipos de vendedores en campo
    'ADMINISTRACION',   -- secretarios y encargado de juegos
    'FINANZAS',         -- tesoreros
    'GERENCIA'          -- gerencia
);

CREATE TYPE cupon_estado         AS ENUM ('BORRADOR', 'ACTIVO', 'INACTIVO');

CREATE TYPE forma_pago_tipo      AS ENUM (
    'EFECTIVO', 'TRANSFERENCIA',
    'POSNET_CREDITO', 'POSNET_DEBITO',
    'MERCADOPAGO', 'WEBPAY'
);

CREATE TYPE autorizacion_origen  AS ENUM ('EXTERNO', 'INTERNO');

CREATE TYPE venta_estado         AS ENUM ('PENDIENTE', 'VALIDADA', 'INVALIDA');

CREATE TYPE semana_estado        AS ENUM ('ABIERTA', 'CERRADA');

CREATE TYPE movimiento_tipo      AS ENUM (
    'ASIGNACION_EQUIPO', 'ASIGNACION_VENDEDOR',
    'PERDIDA', 'DANO', 'DEVOLUCION'
);

CREATE TYPE comision_tipo        AS ENUM (
    'VENDEDOR_INDIVIDUAL', 'LIDER_EQUIPO',
    'BONO_FIN_SEMANA',     -- cada 5 ventas en sábado/domingo (RN-035)
    'BONO_RECORD'          -- v1.1: bono por superar récord histórico personal del día
);

CREATE TYPE notificacion_tipo    AS ENUM ('VENTA_FUERA_CAMPANA');

CREATE TYPE auditoria_operacion  AS ENUM (
    'VALIDAR_VENTA',   'INVALIDAR_VENTA',
    'ACTIVAR_CUPON',   'DESACTIVAR_CUPON',
    'REGISTRAR_PAGO',  'MODIFICAR_COMISION',
    'TRASPASAR_VENTA', 'CREAR_USUARIO', 'MODIFICAR_USUARIO'
);

-- V2
CREATE TYPE juego_tipo           AS ENUM ('FOTOS_CLIENTES', 'ROBOS', 'POZO_DEL_DIA');
CREATE TYPE juego_estado         AS ENUM ('ABIERTO', 'CERRADO');

-- v1.1 — Dashboard operacional
CREATE TYPE inscripcion_tipo     AS ENUM (
    'MANUAL',       -- el vendedor se inscribió al dashboard antes de vender
    'AUTO_VENTA'    -- se inscribió automáticamente al registrar su primera venta del día
);


-- ================================================================
-- CLUSTER 1 — GEOGRÁFICO
-- ================================================================

CREATE TABLE pais (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre     VARCHAR(100) NOT NULL,
    codigo_iso CHAR(2)      NOT NULL UNIQUE
                            CHECK (codigo_iso = UPPER(codigo_iso)),
    moneda     moneda_tipo  NOT NULL,
    activo     BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE ciudad (
    id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre  VARCHAR(100) NOT NULL,
    pais_id UUID         NOT NULL REFERENCES pais(id),
    activo  BOOLEAN      NOT NULL DEFAULT TRUE
);

-- Sin equipo_id: la relación equipo ↔ PDV es histórica via asignacion_equipo_punto
CREATE TABLE punto_de_venta (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre      VARCHAR(150) NOT NULL,
    descripcion TEXT,
    direccion   VARCHAR(255),
    ciudad_id   UUID         NOT NULL REFERENCES ciudad(id),
    activo      BOOLEAN      NOT NULL DEFAULT TRUE
);


-- ================================================================
-- CLUSTER 2 — ORGANIZACIONAL
-- Referencia circular equipo ↔ usuario:
--   1. Se crea equipo SIN FK en lider_id
--   2. Se crea usuario CON FK a equipo
--   3. Se añade FK diferida equipo.lider_id → usuario.id
-- ================================================================

CREATE TABLE equipo (
    id       UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre   VARCHAR(150)      NOT NULL,
    -- v1.1: emoji identificador visible en el dashboard (ej: 🔥, 🦅)
    -- NULL válido para equipos administrativos que no aparecen en el dashboard
    emoji    VARCHAR(10),
    tipo     equipo_categoria  NOT NULL,
    -- lider_id: NULL para equipos administrativos; obligatorio para CAMPO
    lider_id UUID,
    activo   BOOLEAN           NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_equipo_lider_campo
        CHECK (tipo != 'CAMPO' OR lider_id IS NOT NULL)
);

-- Todo usuario pertenece a un equipo (equipos admin para usuarios de oficina)
CREATE TABLE usuario (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre         VARCHAR(100) NOT NULL,
    apellido       VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL UNIQUE,
    username       VARCHAR(50)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    rol            usuario_rol  NOT NULL,
    equipo_id      UUID         NOT NULL REFERENCES equipo(id),
    -- v1.1: campos de dashboard — solo relevantes para vendedores de campo.
    -- NULL válido para usuarios de oficina (secretario, tesorero, etc.)
    emoji_personal      VARCHAR(10)  UNIQUE,          -- elegido por el vendedor, único en todo ATENAS
    meta_ventas_default INTEGER      DEFAULT 10
                        CHECK (meta_ventas_default > 0),
    record_ventas_dia   INTEGER      NOT NULL DEFAULT 0
                        CHECK (record_ventas_dia >= 0), -- máximo de ventas en un día (editable para datos históricos previos al sistema)
    activo         BOOLEAN      NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    ultimo_acceso  TIMESTAMPTZ
);

-- FK diferida: permite insertar equipo + usuario en la misma transacción
ALTER TABLE equipo
    ADD CONSTRAINT fk_equipo_lider
    FOREIGN KEY (lider_id) REFERENCES usuario(id)
    DEFERRABLE INITIALLY DEFERRED;


-- ================================================================
-- CLUSTER 3 — COMERCIAL
-- ================================================================

CREATE TABLE clinica (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre            VARCHAR(150) NOT NULL,
    tipo              VARCHAR(100),
    contacto_nombre   VARCHAR(150),
    contacto_email    VARCHAR(150),
    contacto_telefono VARCHAR(30),
    activo            BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE cupon (
    id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    clinica_id           UUID          NOT NULL REFERENCES clinica(id),
    precio               NUMERIC(12,2) NOT NULL CHECK (precio > 0),
    permite_descuento    BOOLEAN       NOT NULL DEFAULT FALSE,
    precio_con_descuento NUMERIC(12,2) CHECK (
        precio_con_descuento > 0 AND precio_con_descuento < precio
    ),
    -- Texto libre: "Consulta general, limpieza dental, 2 radiografías"
    prestaciones         VARCHAR(500)  NOT NULL,
    estado               cupon_estado  NOT NULL DEFAULT 'BORRADOR',
    fecha_creacion       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    fecha_activacion     TIMESTAMPTZ,
    fecha_desactivacion  TIMESTAMPTZ,
    creado_por_id        UUID          NOT NULL REFERENCES usuario(id),

    -- Si permite_descuento = TRUE, precio_con_descuento es obligatorio
    CONSTRAINT ck_cupon_descuento
        CHECK (NOT permite_descuento OR precio_con_descuento IS NOT NULL),
    -- Coherencia estado ↔ fechas
    CONSTRAINT ck_cupon_fecha_activacion
        CHECK (estado != 'ACTIVO'   OR fecha_activacion IS NOT NULL),
    CONSTRAINT ck_cupon_fecha_desactivacion
        CHECK (estado != 'INACTIVO' OR fecha_desactivacion IS NOT NULL)
);

-- Garantiza exactamente un cupón ACTIVO por clínica (RN-051)
-- Índice parcial: solo aplica sobre filas con estado = 'ACTIVO'
CREATE UNIQUE INDEX idx_cupon_activo_por_clinica
    ON cupon(clinica_id)
    WHERE estado = 'ACTIVO';

-- DD-01: deduplicación por DNI
CREATE TABLE cliente (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre         VARCHAR(100) NOT NULL,
    apellido       VARCHAR(100) NOT NULL,
    dni            VARCHAR(20)  NOT NULL UNIQUE,
    telefono       VARCHAR(30),
    email          VARCHAR(150),
    fecha_registro TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);


-- ================================================================
-- SEMANA LABORAL
-- (Entidad de soporte usada por múltiples clusters)
-- ================================================================

CREATE TABLE semana_laboral (
    id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    -- UNIQUE en fecha_inicio garantiza semanas no solapadas (RN-036)
    fecha_inicio DATE          NOT NULL UNIQUE,
    fecha_fin    DATE          NOT NULL,
    estado       semana_estado NOT NULL DEFAULT 'ABIERTA',
    -- Semana = exactamente 7 días (lunes a domingo)
    CONSTRAINT ck_semana_duracion
        CHECK (fecha_fin = fecha_inicio + 6),
    -- Debe comenzar en lunes (DOW: 0=domingo … 1=lunes … 6=sábado)
    CONSTRAINT ck_semana_lunes
        CHECK (EXTRACT(DOW FROM fecha_inicio) = 1)
);


-- ================================================================
-- CLUSTER 4 — TRANSACCIÓN CENTRAL
-- ================================================================

CREATE TABLE venta (
    id                       UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedor_id              UUID                  NOT NULL REFERENCES usuario(id),
    cupon_id                 UUID                  NOT NULL REFERENCES cupon(id),
    -- Nullable hasta que el secretario valide e ingrese los datos del cliente
    cliente_id               UUID                  REFERENCES cliente(id),
    semana_laboral_id        UUID                  NOT NULL REFERENCES semana_laboral(id),
    -- DD-03: almacenado explícitamente para filtros de reportes y determinación de moneda
    punto_de_venta_id        UUID                  NOT NULL REFERENCES punto_de_venta(id),
    forma_pago               forma_pago_tipo       NOT NULL,
    numero_autorizacion      VARCHAR(100)          NOT NULL,
    origen_autorizacion      autorizacion_origen   NOT NULL,
    aplico_descuento         BOOLEAN               NOT NULL DEFAULT FALSE,
    precio_final             NUMERIC(12,2)         NOT NULL CHECK (precio_final > 0),
    -- Moneda almacenada explícitamente (RNF-012): protege integridad histórica
    moneda                   moneda_tipo           NOT NULL,
    estado                   venta_estado          NOT NULL DEFAULT 'PENDIENTE',
    -- Flag ortogonal al estado de validación (RN-013)
    fuera_de_campana         BOOLEAN               NOT NULL DEFAULT FALSE,
    fecha_hora_registro      TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    secretario_validador_id  UUID                  REFERENCES usuario(id),
    fecha_hora_validacion    TIMESTAMPTZ,
    observaciones_validacion TEXT,

    -- Efectivo → autorización interna; electrónico → autorización externa
    CONSTRAINT ck_venta_autorizacion CHECK (
        (forma_pago = 'EFECTIVO'  AND origen_autorizacion = 'INTERNO') OR
        (forma_pago != 'EFECTIVO' AND origen_autorizacion = 'EXTERNO')
    ),
    -- Observaciones obligatorias al invalidar (RN-017)
    CONSTRAINT ck_venta_observaciones CHECK (
        estado != 'INVALIDA' OR observaciones_validacion IS NOT NULL
    ),
    -- Consistencia entre estado y campos de validación
    CONSTRAINT ck_venta_coherencia_validacion CHECK (
        (estado = 'PENDIENTE'
            AND secretario_validador_id IS NULL
            AND fecha_hora_validacion IS NULL)
        OR
        (estado IN ('VALIDADA', 'INVALIDA')
            AND secretario_validador_id IS NOT NULL
            AND fecha_hora_validacion IS NOT NULL)
    )
);

CREATE TABLE imagen_venta (
    id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    venta_id           UUID         NOT NULL REFERENCES venta(id),
    url_almacenamiento VARCHAR(500) NOT NULL,
    -- Tamaño post-compresión (RNF-009)
    tamanio_bytes      INTEGER      NOT NULL CHECK (tamanio_bytes > 0),
    fecha_subida       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE traspaso_venta (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    -- UNIQUE: máximo un traspaso por venta (RN-014)
    venta_id          UUID         NOT NULL UNIQUE REFERENCES venta(id),
    cupon_origen_id   UUID         NOT NULL REFERENCES cupon(id),
    cupon_destino_id  UUID         NOT NULL REFERENCES cupon(id),
    -- Solo Gerencia en MVP (RN-057)
    registrado_por_id UUID         NOT NULL REFERENCES usuario(id),
    motivo            TEXT         NOT NULL,
    fecha_traspaso    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_traspaso_cupones_distintos
        CHECK (cupon_origen_id != cupon_destino_id)
);

-- Historial de qué equipo operó en qué PDV y en qué semana
CREATE TABLE asignacion_equipo_punto (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    punto_de_venta_id UUID         NOT NULL REFERENCES punto_de_venta(id),
    equipo_id         UUID         NOT NULL REFERENCES equipo(id),
    semana_laboral_id UUID         NOT NULL REFERENCES semana_laboral(id),
    fecha_inicio      TIMESTAMPTZ  NOT NULL,
    -- NULL = asignación vigente actualmente
    fecha_fin         TIMESTAMPTZ,
    activo            BOOLEAN      NOT NULL DEFAULT TRUE,
    registrado_por_id UUID         NOT NULL REFERENCES usuario(id),
    CONSTRAINT ck_asignacion_fechas
        CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio),
    -- Un equipo no puede estar asignado dos veces al mismo PDV en la misma semana
    CONSTRAINT uq_asignacion_por_semana
        UNIQUE (equipo_id, punto_de_venta_id, semana_laboral_id)
);


-- ================================================================
-- CLUSTER 4.5 — DASHBOARD OPERACIONAL  (v1.1)
-- Registra la actividad diaria de cada vendedor en el dashboard.
-- Es el eje del display en tiempo real (polling V1, WebSockets V2).
--
-- Relación con otros clusters:
--   · venta            → cada venta del día incrementa el contador
--   · registro_comision→ los bonos BONO_FIN_SEMANA y BONO_RECORD
--                        generan el emoji 🎁 en el dashboard
--   · usuario          → emoji_personal, meta_ventas_default,
--                        record_ventas_dia (campos agregados en v1.1)
-- ================================================================

CREATE TABLE jornada_diaria (
    id                   UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedor_id          UUID               NOT NULL REFERENCES usuario(id),
    fecha                DATE               NOT NULL,
    -- Meta del día: arranca con el valor de usuario.meta_ventas_default
    -- pero puede editarse para esta jornada específica
    meta_ventas          INTEGER            NOT NULL CHECK (meta_ventas > 0),
    tipo_inscripcion     inscripcion_tipo   NOT NULL DEFAULT 'AUTO_VENTA',
    -- Flag anti-duplicado para BONO_RECORD:
    -- TRUE = ya se generó el bono por superar el récord hoy.
    -- Impide dar un segundo BONO_RECORD si el vendedor sigue sumando ventas
    -- por encima del récord en la misma jornada.
    record_superado_hoy  BOOLEAN            NOT NULL DEFAULT FALSE,
    fecha_inscripcion    TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    -- Un único registro por vendedor por día
    CONSTRAINT uq_jornada_vendedor_fecha
        UNIQUE (vendedor_id, fecha)
);


-- ================================================================
-- CLUSTER 5 — COMISIONES Y PAGOS
-- ================================================================

CREATE TABLE tabla_comision (
    id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Un precio de venta → un monto de comisión (DD-05: sin versioning)
    precio_venta   NUMERIC(12,2) NOT NULL UNIQUE CHECK (precio_venta > 0),
    monto_comision NUMERIC(12,2) NOT NULL CHECK (monto_comision > 0),
    activo         BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE TABLE umbral_lider (
    id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    ventas_desde         INTEGER       NOT NULL CHECK (ventas_desde >= 0),
    -- NULL en ventas_hasta = tramo más alto (abierto hacia arriba)
    ventas_hasta         INTEGER       CHECK (ventas_hasta > ventas_desde),
    monto_comision_lider NUMERIC(12,2) NOT NULL CHECK (monto_comision_lider > 0),
    activo               BOOLEAN       NOT NULL DEFAULT TRUE
);

-- Comisiones persistidas por venta y beneficiario
-- Permite recálculo retroactivo del líder sin perder historial (RN-034)
CREATE TABLE registro_comision (
    id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    -- NULL solo para BONO_FIN_SEMANA (no está atado a una venta específica)
    venta_id          UUID          REFERENCES venta(id),
    beneficiario_id   UUID          NOT NULL REFERENCES usuario(id),
    semana_laboral_id UUID          NOT NULL REFERENCES semana_laboral(id),
    tipo              comision_tipo NOT NULL,
    monto             NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    moneda            moneda_tipo   NOT NULL,
    -- TRUE si fue recalculado por cruce de umbral del líder (RN-034)
    recalculado       BOOLEAN       NOT NULL DEFAULT FALSE,
    fecha_calculo     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    -- BONO_FIN_SEMANA no tiene venta; los otros tipos sí
    CONSTRAINT ck_comision_venta_coherente CHECK (
        (tipo = 'BONO_FIN_SEMANA' AND venta_id IS NULL) OR
        (tipo != 'BONO_FIN_SEMANA' AND venta_id IS NOT NULL)
    )
);

CREATE TABLE pago_vendedor (
    id                        UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedor_id               UUID          NOT NULL REFERENCES usuario(id),
    semana_laboral_id         UUID          NOT NULL REFERENCES semana_laboral(id),
    tesorero_id               UUID          NOT NULL REFERENCES usuario(id),
    monto_comisiones_vendedor NUMERIC(12,2) NOT NULL DEFAULT 0
                              CHECK (monto_comisiones_vendedor >= 0),
    monto_comisiones_equipo   NUMERIC(12,2) NOT NULL DEFAULT 0
                              CHECK (monto_comisiones_equipo >= 0),
    monto_bonos_finde         NUMERIC(12,2) NOT NULL DEFAULT 0
                              CHECK (monto_bonos_finde >= 0),
    monto_premios_juegos      NUMERIC(12,2) NOT NULL DEFAULT 0
                              CHECK (monto_premios_juegos >= 0),
    total                     NUMERIC(12,2) NOT NULL CHECK (total >= 0),
    moneda                    moneda_tipo   NOT NULL,
    fecha_pago                DATE          NOT NULL,
    fecha_registro            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    -- Un único pago por vendedor por semana (RN-041)
    CONSTRAINT uq_pago_vendedor_semana
        UNIQUE (vendedor_id, semana_laboral_id),
    -- Total = suma de sus componentes
    CONSTRAINT ck_pago_total CHECK (
        total = monto_comisiones_vendedor
              + monto_comisiones_equipo
              + monto_bonos_finde
              + monto_premios_juegos
    )
);

-- Registra la rendición física del efectivo cobrado en campo (PD-004, RN-056)
CREATE TABLE rendicion_efectivo (
    id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedor_id       UUID          NOT NULL REFERENCES usuario(id),
    lider_id          UUID          NOT NULL REFERENCES usuario(id),
    semana_laboral_id UUID          NOT NULL REFERENCES semana_laboral(id),
    monto             NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    moneda            moneda_tipo   NOT NULL,
    fecha_rendicion   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    observaciones     TEXT,
    -- El que rinde y el que recibe deben ser personas distintas
    CONSTRAINT ck_rendicion_actores_distintos
        CHECK (vendedor_id != lider_id)
);


-- ================================================================
-- CLUSTER 6 — INVENTARIO DE CUPONES FÍSICOS
-- ================================================================

CREATE TABLE lote_ingreso_cupones (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    cupon_id          UUID         NOT NULL REFERENCES cupon(id),
    cantidad          INTEGER      NOT NULL CHECK (cantidad > 0),
    registrado_por_id UUID         NOT NULL REFERENCES usuario(id),
    fecha_ingreso     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    observaciones     TEXT
);

-- Cada fila es un movimiento de stock. El stock neto se calcula sumando movimientos.
CREATE TABLE movimiento_cupon (
    id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    lote_id           UUID            NOT NULL REFERENCES lote_ingreso_cupones(id),
    tipo              movimiento_tipo NOT NULL,
    cantidad          INTEGER         NOT NULL CHECK (cantidad > 0),
    -- Destino: equipo (asignación de empresa→equipo) o vendedor (equipo→vendedor)
    equipo_id         UUID            REFERENCES equipo(id),
    vendedor_id       UUID            REFERENCES usuario(id),
    registrado_por_id UUID            NOT NULL REFERENCES usuario(id),
    fecha             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    motivo            TEXT,
    -- Coherencia tipo ↔ destino
    CONSTRAINT ck_movimiento_coherencia CHECK (
        (tipo = 'ASIGNACION_EQUIPO'
            AND equipo_id IS NOT NULL AND vendedor_id IS NULL) OR
        (tipo = 'ASIGNACION_VENDEDOR'
            AND vendedor_id IS NOT NULL AND equipo_id IS NULL) OR
        (tipo IN ('PERDIDA', 'DANO')
            AND vendedor_id IS NOT NULL AND motivo IS NOT NULL) OR
        (tipo = 'DEVOLUCION')
    )
);


-- ================================================================
-- CLUSTER 7 — SISTEMA E INFRAESTRUCTURA
-- ================================================================

CREATE TABLE notificacion_interna (
    id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    destinatario_id UUID              NOT NULL REFERENCES usuario(id),
    tipo            notificacion_tipo NOT NULL,
    titulo          VARCHAR(200)      NOT NULL,
    mensaje         TEXT              NOT NULL,
    -- Contexto opcional (ej: la venta que disparó la notificación)
    venta_id        UUID              REFERENCES venta(id),
    leida           BOOLEAN           NOT NULL DEFAULT FALSE,
    fecha_creacion  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    fecha_lectura   TIMESTAMPTZ,
    -- Si leída, debe tener fecha; si no leída, no debe tenerla
    CONSTRAINT ck_notificacion_lectura CHECK (
        (leida = FALSE AND fecha_lectura IS NULL) OR
        (leida = TRUE  AND fecha_lectura IS NOT NULL)
    )
);

-- Registro inmutable, append-only (RNF-010)
-- No tiene ON DELETE CASCADE: los logs nunca se borran
CREATE TABLE log_auditoria (
    id               UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id       UUID                  NOT NULL REFERENCES usuario(id),
    operacion        auditoria_operacion   NOT NULL,
    entidad_tipo     VARCHAR(50)           NOT NULL,
    entidad_id       UUID                  NOT NULL,
    datos_anteriores JSONB,
    datos_nuevos     JSONB                 NOT NULL,
    fecha_hora       TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    ip_origen        VARCHAR(45)
);


-- ================================================================
-- CLUSTER 8 — JUEGOS (V2)
-- ================================================================

CREATE TABLE juego (
    id           UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo         juego_tipo      NOT NULL,
    fecha        DATE            NOT NULL,
    estado       juego_estado    NOT NULL DEFAULT 'ABIERTO',
    encargado_id UUID            NOT NULL REFERENCES usuario(id),
    ganador_id   UUID            REFERENCES usuario(id),
    monto_premio NUMERIC(12,2)   CHECK (monto_premio > 0),
    moneda       moneda_tipo,
    fecha_cierre TIMESTAMPTZ,
    CONSTRAINT ck_juego_cierre CHECK (
        (estado = 'ABIERTO' AND ganador_id IS NULL AND fecha_cierre IS NULL) OR
        (estado = 'CERRADO' AND fecha_cierre IS NOT NULL)
    )
);

CREATE TABLE registro_juego (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    juego_id    UUID         NOT NULL REFERENCES juego(id),
    vendedor_id UUID         NOT NULL REFERENCES usuario(id),
    -- Solo para juego de ROBOS: a quién se le robó
    robo_de_id  UUID         REFERENCES usuario(id),
    puntos      INTEGER      NOT NULL DEFAULT 0 CHECK (puntos >= 0),
    -- Solo para juego FOTOS_CLIENTES
    url_foto    VARCHAR(500),
    fecha       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_registro_no_autorobo
        CHECK (robo_de_id IS NULL OR vendedor_id != robo_de_id)
);

-- Premio al ganador. Independiente de comisiones semanales (RN-042)
CREATE TABLE premio_juego (
    id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    juego_id    UUID          NOT NULL REFERENCES juego(id),
    vendedor_id UUID          NOT NULL REFERENCES usuario(id),
    monto       NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    moneda      moneda_tipo   NOT NULL,
    fecha       DATE          NOT NULL
);


-- ================================================================
-- ÍNDICES
-- PostgreSQL no indexa automáticamente las FK — se crean manualmente
-- ================================================================

-- ---- Cluster Geográfico ----------------------------------------
CREATE INDEX idx_ciudad_pais              ON ciudad(pais_id);
CREATE INDEX idx_pdv_ciudad               ON punto_de_venta(ciudad_id);

-- ---- Cluster Organizacional ------------------------------------
CREATE INDEX idx_usuario_equipo           ON usuario(equipo_id);
CREATE INDEX idx_usuario_rol              ON usuario(rol);

-- ---- Cluster Comercial -----------------------------------------
CREATE INDEX idx_cupon_clinica            ON cupon(clinica_id);
CREATE INDEX idx_cupon_estado             ON cupon(estado);

-- ---- Transacción Central ---------------------------------------
CREATE INDEX idx_venta_vendedor           ON venta(vendedor_id);
CREATE INDEX idx_venta_cupon              ON venta(cupon_id);
CREATE INDEX idx_venta_cliente            ON venta(cliente_id);
CREATE INDEX idx_venta_semana             ON venta(semana_laboral_id);
CREATE INDEX idx_venta_pdv                ON venta(punto_de_venta_id);
CREATE INDEX idx_venta_fecha              ON venta(fecha_hora_registro DESC);
-- Query frecuente: ventas pendientes en cola del secretario
CREATE INDEX idx_venta_pendientes         ON venta(estado)
    WHERE estado = 'PENDIENTE';
-- Query frecuente: ventas de un vendedor en una semana
CREATE INDEX idx_venta_vendedor_semana    ON venta(vendedor_id, semana_laboral_id);
CREATE INDEX idx_imagen_venta             ON imagen_venta(venta_id);
CREATE INDEX idx_asignacion_equipo        ON asignacion_equipo_punto(equipo_id);
CREATE INDEX idx_asignacion_pdv           ON asignacion_equipo_punto(punto_de_venta_id);
CREATE INDEX idx_asignacion_semana        ON asignacion_equipo_punto(semana_laboral_id);

-- ---- Comisiones y Pagos ----------------------------------------
CREATE INDEX idx_regcom_venta             ON registro_comision(venta_id);
CREATE INDEX idx_regcom_beneficiario      ON registro_comision(beneficiario_id);
CREATE INDEX idx_regcom_semana            ON registro_comision(semana_laboral_id);
-- Query frecuente: total de comisiones de un vendedor en la semana
CREATE INDEX idx_regcom_beneficiario_semana
    ON registro_comision(beneficiario_id, semana_laboral_id);
CREATE INDEX idx_pago_vendedor_id         ON pago_vendedor(vendedor_id);
CREATE INDEX idx_pago_semana              ON pago_vendedor(semana_laboral_id);
CREATE INDEX idx_rendicion_vendedor       ON rendicion_efectivo(vendedor_id);
CREATE INDEX idx_rendicion_semana         ON rendicion_efectivo(semana_laboral_id);

-- ---- Inventario ------------------------------------------------
CREATE INDEX idx_lote_cupon               ON lote_ingreso_cupones(cupon_id);
CREATE INDEX idx_movimiento_lote          ON movimiento_cupon(lote_id);
CREATE INDEX idx_movimiento_equipo        ON movimiento_cupon(equipo_id);
CREATE INDEX idx_movimiento_vendedor      ON movimiento_cupon(vendedor_id);

-- ---- Sistema ---------------------------------------------------
CREATE INDEX idx_notif_destinatario       ON notificacion_interna(destinatario_id);
CREATE INDEX idx_notif_no_leidas          ON notificacion_interna(destinatario_id)
    WHERE leida = FALSE;
CREATE INDEX idx_log_usuario              ON log_auditoria(usuario_id);
CREATE INDEX idx_log_entidad              ON log_auditoria(entidad_tipo, entidad_id);
CREATE INDEX idx_log_fecha                ON log_auditoria(fecha_hora DESC);

-- ---- Juegos (V2) -----------------------------------------------
CREATE INDEX idx_juego_encargado          ON juego(encargado_id);
CREATE INDEX idx_registro_juego_juego     ON registro_juego(juego_id);
CREATE INDEX idx_registro_juego_vendedor  ON registro_juego(vendedor_id);
CREATE INDEX idx_premio_juego             ON premio_juego(juego_id);

-- ---- Dashboard operacional (v1.1) ------------------------------
CREATE INDEX idx_jornada_vendedor         ON jornada_diaria(vendedor_id);
CREATE INDEX idx_jornada_fecha            ON jornada_diaria(fecha DESC);
-- Query central del dashboard: vendedor + fecha (UNIQUE ya actúa como índice,
-- pero este compuesto cubre la dirección de búsqueda más frecuente)
CREATE INDEX idx_jornada_vendedor_fecha   ON jornada_diaria(vendedor_id, fecha DESC);
-- Query frecuente: contar 🎁 del día por vendedor
-- beneficiario_id + tipo + fecha_calculo cubre el filtro del dashboard
CREATE INDEX idx_regcom_bonos_beneficiario
    ON registro_comision(beneficiario_id, tipo, fecha_calculo DESC)
    WHERE tipo IN ('BONO_FIN_SEMANA', 'BONO_RECORD');
