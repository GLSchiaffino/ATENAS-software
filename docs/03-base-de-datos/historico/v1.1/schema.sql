-- ================================================================
-- ATENAS Software — Sistema de Información
-- Esquema de Base de Datos v2.0  |  PostgreSQL 15+
-- Proyecto Final UTN — Ingeniería de Software
-- ================================================================
--
-- Convenciones generales:
--   · PK       : UUID con gen_random_uuid()
--   · Fechas   : TIMESTAMPTZ — zona horaria incluida (Chile UTC-3/-4, AR UTC-3)
--   · Dinero   : NUMERIC(12,2) — precisión exacta, sin punto flotante
--   · Texto    : VARCHAR(n) con límite semántico | TEXT sin límite
--   · Borrado  : soft delete con campo `fecha_baja TIMESTAMPTZ`
--                NULL = registro activo | NOT NULL = fecha en que se dio de baja
--   · FK       : indexadas manualmente (PostgreSQL no las indexa solo)
--
-- Orden de creación respeta dependencias entre tablas.
-- La referencia circular equipo ↔ usuario se resuelve con FK DEFERRABLE.
-- La referencia venta → rendicion_efectivo se añade con ALTER TABLE
-- después de crear rendicion_efectivo (Cluster 5).
--
-- ── Historial de versiones ─────────────────────────────────────
-- v1.0  Esquema inicial (25 tablas, 14 ENUMs)
-- v1.1  Dashboard operacional: BONO_RECORD, inscripcion_tipo,
--        equipo.emoji, usuario.emoji/meta/record, jornada_diaria
-- v1.2  Portal Clínicas: rol CLINICA, equipo CLINICAS,
--        usuario.clinica_id
-- v2.0  Revisión estructural (limpieza post-diagrama DBeaver):
--   · activo BOOLEAN → fecha_baja TIMESTAMPTZ en todas las tablas
--   · Eliminado usuario.ultimo_acceso (dinámico, sin valor de negocio)
--   · Eliminado registro_comision.recalculado (no necesario para ATENAS)
--   · pago_vendedor.tesorero_id → registrado_por_id (gerencia también paga)
--   · Corregido ck_comision_venta_coherente: BONO_RECORD también sin venta
--   · venta.rendicion_efectivo_id: trazabilidad efectivo → rendición
--   · registro_comision: +pago_vendedor_id, +tabla_comision_id,
--     +umbral_lider_id, +jornada_vendedor_id
--   · Cluster 4.5 reestructurado:
--       jornada_diaria  = jornada GLOBAL por día (7 por semana, semana→día)
--       jornada_vendedor = participación individual del vendedor en un día
--   · asignacion_equipo_punto: eliminado activo (fecha_fin ya lo cubre)
-- ================================================================


-- ================================================================
-- TIPOS ENUMERADOS
-- ================================================================

CREATE TYPE moneda_tipo         AS ENUM ('CLP', 'ARS');

CREATE TYPE usuario_rol         AS ENUM (
    'VENDEDOR', 'LIDER', 'SECRETARIO',
    'TESORERO', 'ENCARGADO_JUEGOS', 'GERENCIA',
    'CLINICA'       -- v1.2: solo lectura al portal de su clínica
);

CREATE TYPE equipo_categoria    AS ENUM (
    'CAMPO',            -- equipos de vendedores en campo
    'ADMINISTRACION',   -- secretarios y encargado de juegos
    'FINANZAS',         -- tesoreros
    'GERENCIA',         -- gerencia
    'CLINICAS'          -- v1.2: usuarios del portal de clínicas
);

CREATE TYPE cupon_estado        AS ENUM ('BORRADOR', 'ACTIVO', 'INACTIVO');

CREATE TYPE forma_pago_tipo     AS ENUM (
    'EFECTIVO', 'TRANSFERENCIA',
    'POSNET_CREDITO', 'POSNET_DEBITO',
    'MERCADOPAGO', 'WEBPAY'
);

CREATE TYPE autorizacion_origen AS ENUM ('EXTERNO', 'INTERNO');

CREATE TYPE venta_estado        AS ENUM ('PENDIENTE', 'VALIDADA', 'INVALIDA');

CREATE TYPE semana_estado       AS ENUM ('ABIERTA', 'CERRADA');

CREATE TYPE movimiento_tipo     AS ENUM (
    'ASIGNACION_EQUIPO', 'ASIGNACION_VENDEDOR',
    'PERDIDA', 'DANO', 'DEVOLUCION'
);

CREATE TYPE comision_tipo       AS ENUM (
    'VENDEDOR_INDIVIDUAL',
    'LIDER_EQUIPO',
    'BONO_FIN_SEMANA',  -- cada 5 ventas en sábado/domingo (RN-035)
    'BONO_RECORD'       -- bono por superar récord histórico personal del día
);

CREATE TYPE notificacion_tipo   AS ENUM ('VENTA_FUERA_CAMPANA');

CREATE TYPE auditoria_operacion AS ENUM (
    'VALIDAR_VENTA',   'INVALIDAR_VENTA',
    'ACTIVAR_CUPON',   'DESACTIVAR_CUPON',
    'REGISTRAR_PAGO',  'MODIFICAR_COMISION',
    'TRASPASAR_VENTA', 'CREAR_USUARIO', 'MODIFICAR_USUARIO'
);

CREATE TYPE inscripcion_tipo    AS ENUM (
    'MANUAL',       -- el vendedor se inscribió al dashboard antes de vender
    'AUTO_VENTA'    -- inscripción automática al registrar la primera venta del día
);

-- V2
CREATE TYPE juego_tipo          AS ENUM ('FOTOS_CLIENTES', 'ROBOS', 'POZO_DEL_DIA');
CREATE TYPE juego_estado        AS ENUM ('ABIERTO', 'CERRADO');


-- ================================================================
-- CLUSTER 1 — GEOGRÁFICO
-- ================================================================

CREATE TABLE pais (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre     VARCHAR(100) NOT NULL,
    codigo_iso CHAR(2)      NOT NULL UNIQUE
                            CHECK (codigo_iso = UPPER(codigo_iso)),
    moneda     moneda_tipo  NOT NULL,
    -- v2.0: NULL = activo | NOT NULL = fecha en que se dio de baja
    fecha_baja TIMESTAMPTZ
);

CREATE TABLE ciudad (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre     VARCHAR(100) NOT NULL,
    pais_id    UUID         NOT NULL REFERENCES pais(id),
    fecha_baja TIMESTAMPTZ
);

-- Sin equipo_id: la relación equipo ↔ PDV es histórica via asignacion_equipo_punto
CREATE TABLE punto_de_venta (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre      VARCHAR(150) NOT NULL,
    descripcion TEXT,
    direccion   VARCHAR(255),
    ciudad_id   UUID         NOT NULL REFERENCES ciudad(id),
    fecha_baja  TIMESTAMPTZ
);


-- ================================================================
-- CLUSTER 2 — ORGANIZACIONAL
-- Referencia circular equipo ↔ usuario:
--   1. Se crea equipo SIN FK en lider_id
--   2. Se crea usuario CON FK a equipo
--   3. Se añade FK diferida equipo.lider_id → usuario.id
-- ================================================================

CREATE TABLE equipo (
    id         UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre     VARCHAR(150)     NOT NULL,
    emoji      VARCHAR(10),     -- identificador visual en el dashboard
    tipo       equipo_categoria NOT NULL,
    lider_id   UUID,            -- NULL para equipos administrativos
    fecha_baja TIMESTAMPTZ,
    CONSTRAINT ck_equipo_lider_campo
        CHECK (tipo != 'CAMPO' OR lider_id IS NOT NULL)
);

CREATE TABLE usuario (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre              VARCHAR(100) NOT NULL,
    apellido            VARCHAR(100) NOT NULL,
    email               VARCHAR(150) NOT NULL UNIQUE,
    username            VARCHAR(50)  NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    rol                 usuario_rol  NOT NULL,
    equipo_id           UUID         NOT NULL REFERENCES equipo(id),
    -- v1.2: solo para rol CLINICA — qué clínica puede ver este usuario
    -- FK a clinica declarada con ALTER TABLE después del Cluster 3
    clinica_id          UUID,
    -- Dashboard: solo relevante para vendedores de campo
    emoji_personal      VARCHAR(10)  UNIQUE,
    meta_ventas_default INTEGER      DEFAULT 10
                        CHECK (meta_ventas_default > 0),
    record_ventas_dia   INTEGER      NOT NULL DEFAULT 0
                        CHECK (record_ventas_dia >= 0),
    fecha_creacion      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    fecha_baja          TIMESTAMPTZ,
    CONSTRAINT ck_usuario_clinica_rol
        CHECK ((rol != 'CLINICA') OR (clinica_id IS NOT NULL))
);

-- FK diferida: resuelve la referencia circular equipo ↔ usuario
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
    fecha_baja        TIMESTAMPTZ
);

-- FK de usuario.clinica_id declarada aquí porque clinica se crea después de usuario
ALTER TABLE usuario
    ADD CONSTRAINT fk_usuario_clinica
    FOREIGN KEY (clinica_id) REFERENCES clinica(id);

CREATE TABLE cupon (
    id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    clinica_id           UUID          NOT NULL REFERENCES clinica(id),
    precio               NUMERIC(12,2) NOT NULL CHECK (precio > 0),
    permite_descuento    BOOLEAN       NOT NULL DEFAULT FALSE,
    precio_con_descuento NUMERIC(12,2) CHECK (
        precio_con_descuento > 0 AND precio_con_descuento < precio
    ),
    prestaciones         VARCHAR(500)  NOT NULL,
    estado               cupon_estado  NOT NULL DEFAULT 'BORRADOR',
    fecha_creacion       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    fecha_activacion     TIMESTAMPTZ,
    -- v2.0: renombrado de fecha_desactivacion → fecha_baja (consistencia)
    fecha_baja           TIMESTAMPTZ,
    creado_por_id        UUID          NOT NULL REFERENCES usuario(id),
    CONSTRAINT ck_cupon_descuento
        CHECK (NOT permite_descuento OR precio_con_descuento IS NOT NULL),
    CONSTRAINT ck_cupon_fecha_activacion
        CHECK (estado != 'ACTIVO'   OR fecha_activacion IS NOT NULL),
    CONSTRAINT ck_cupon_fecha_baja
        CHECK (estado != 'INACTIVO' OR fecha_baja IS NOT NULL)
);

-- Garantiza exactamente un cupón ACTIVO por clínica (RN-051)
CREATE UNIQUE INDEX idx_cupon_activo_por_clinica
    ON cupon(clinica_id)
    WHERE estado = 'ACTIVO';

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
-- ================================================================

CREATE TABLE semana_laboral (
    id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha_inicio DATE          NOT NULL UNIQUE,
    fecha_fin    DATE          NOT NULL,
    -- ABIERTA: ventas y comisiones pueden modificarse
    -- CERRADA: el tesorero procesó los pagos, período congelado
    estado       semana_estado NOT NULL DEFAULT 'ABIERTA',
    CONSTRAINT ck_semana_duracion
        CHECK (fecha_fin = fecha_inicio + 6),
    CONSTRAINT ck_semana_lunes
        CHECK (EXTRACT(DOW FROM fecha_inicio) = 1)
);


-- ================================================================
-- CLUSTER 4 — TRANSACCIÓN CENTRAL
-- ================================================================

CREATE TABLE venta (
    id                       UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedor_id              UUID                NOT NULL REFERENCES usuario(id),
    cupon_id                 UUID                NOT NULL REFERENCES cupon(id),
    cliente_id               UUID                REFERENCES cliente(id),
    semana_laboral_id        UUID                NOT NULL REFERENCES semana_laboral(id),
    punto_de_venta_id        UUID                NOT NULL REFERENCES punto_de_venta(id),
    forma_pago               forma_pago_tipo     NOT NULL,
    numero_autorizacion      VARCHAR(100)        NOT NULL,
    origen_autorizacion      autorizacion_origen NOT NULL,
    aplico_descuento         BOOLEAN             NOT NULL DEFAULT FALSE,
    precio_final             NUMERIC(12,2)       NOT NULL CHECK (precio_final > 0),
    moneda                   moneda_tipo         NOT NULL,
    estado                   venta_estado        NOT NULL DEFAULT 'PENDIENTE',
    fuera_de_campana         BOOLEAN             NOT NULL DEFAULT FALSE,
    fecha_hora_registro      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    secretario_validador_id  UUID                REFERENCES usuario(id),
    fecha_hora_validacion    TIMESTAMPTZ,
    observaciones_validacion TEXT,
    -- v2.0: trazabilidad efectivo → rendición (solo ventas EFECTIVO)
    -- FK a rendicion_efectivo añadida con ALTER TABLE después del Cluster 5
    rendicion_efectivo_id    UUID,

    CONSTRAINT ck_venta_autorizacion CHECK (
        (forma_pago = 'EFECTIVO'  AND origen_autorizacion = 'INTERNO') OR
        (forma_pago != 'EFECTIVO' AND origen_autorizacion = 'EXTERNO')
    ),
    CONSTRAINT ck_venta_rendicion CHECK (
        rendicion_efectivo_id IS NULL OR forma_pago = 'EFECTIVO'
    ),
    CONSTRAINT ck_venta_observaciones CHECK (
        estado != 'INVALIDA' OR observaciones_validacion IS NOT NULL
    ),
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
    tamanio_bytes      INTEGER      NOT NULL CHECK (tamanio_bytes > 0),
    fecha_subida       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE traspaso_venta (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    venta_id          UUID        NOT NULL UNIQUE REFERENCES venta(id),
    cupon_origen_id   UUID        NOT NULL REFERENCES cupon(id),
    cupon_destino_id  UUID        NOT NULL REFERENCES cupon(id),
    registrado_por_id UUID        NOT NULL REFERENCES usuario(id),
    motivo            TEXT        NOT NULL,
    fecha_traspaso    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_traspaso_cupones_distintos
        CHECK (cupon_origen_id != cupon_destino_id)
);

CREATE TABLE asignacion_equipo_punto (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    punto_de_venta_id UUID        NOT NULL REFERENCES punto_de_venta(id),
    equipo_id         UUID        NOT NULL REFERENCES equipo(id),
    semana_laboral_id UUID        NOT NULL REFERENCES semana_laboral(id),
    fecha_inicio      TIMESTAMPTZ NOT NULL,
    -- v2.0: fecha_fin = NULL → asignación vigente (reemplaza activo BOOLEAN)
    fecha_fin         TIMESTAMPTZ,
    registrado_por_id UUID        NOT NULL REFERENCES usuario(id),
    CONSTRAINT ck_asignacion_fechas
        CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio),
    CONSTRAINT uq_asignacion_por_semana
        UNIQUE (equipo_id, punto_de_venta_id, semana_laboral_id)
);


-- ================================================================
-- CLUSTER 4.5 — DASHBOARD OPERACIONAL
--
-- Jerarquía de jornadas (v2.0):
--
--   semana_laboral (1)
--     └── jornada_diaria (hasta 7 — creadas al crear la semana)
--           └── jornada_vendedor (1 por vendedor por día)
--
--   · jornada_diaria   = el DÍA como entidad global. Existe aunque nadie venda.
--   · jornada_vendedor = la participación individual del vendedor en ese día.
--                        Se crea al primera venta o al check-in manual.
-- ================================================================

CREATE TABLE jornada_diaria (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha             DATE        NOT NULL,
    semana_laboral_id UUID        NOT NULL REFERENCES semana_laboral(id),
    -- Un solo día por semana (no puede haber dos martes en la misma semana)
    CONSTRAINT uq_jornada_fecha_semana UNIQUE (fecha, semana_laboral_id)
    -- Nota: la validación de que fecha esté dentro del rango de la semana
    -- se realiza en la capa de aplicación (subqueries no permitidas en CHECK)
);

CREATE TABLE jornada_vendedor (
    id                  UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
    jornada_diaria_id   UUID             NOT NULL REFERENCES jornada_diaria(id),
    vendedor_id         UUID             NOT NULL REFERENCES usuario(id),
    -- Meta del día: arranca de usuario.meta_ventas_default, editable
    meta_ventas         INTEGER          NOT NULL CHECK (meta_ventas > 0),
    tipo_inscripcion    inscripcion_tipo NOT NULL DEFAULT 'AUTO_VENTA',
    -- Impide dar un segundo BONO_RECORD si el vendedor sigue sumando ventas
    record_superado_hoy BOOLEAN          NOT NULL DEFAULT FALSE,
    fecha_inscripcion   TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    -- Un vendedor solo puede estar una vez por día
    CONSTRAINT uq_jornada_vendedor UNIQUE (jornada_diaria_id, vendedor_id)
);


-- ================================================================
-- CLUSTER 5 — COMISIONES Y PAGOS
-- Orden de creación: tabla_comision → umbral_lider → pago_vendedor
-- → registro_comision (referencia a los tres anteriores)
-- → rendicion_efectivo
-- ================================================================

CREATE TABLE tabla_comision (
    id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    precio_venta   NUMERIC(12,2) NOT NULL UNIQUE CHECK (precio_venta > 0),
    monto_comision NUMERIC(12,2) NOT NULL CHECK (monto_comision > 0),
    fecha_baja     TIMESTAMPTZ
);

CREATE TABLE umbral_lider (
    id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    ventas_desde         INTEGER       NOT NULL CHECK (ventas_desde >= 0),
    -- NULL = tramo más alto (abierto hacia arriba)
    ventas_hasta         INTEGER       CHECK (ventas_hasta > ventas_desde),
    monto_comision_lider NUMERIC(12,2) NOT NULL CHECK (monto_comision_lider > 0),
    fecha_baja           TIMESTAMPTZ
);

CREATE TABLE pago_vendedor (
    id                        UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedor_id               UUID          NOT NULL REFERENCES usuario(id),
    semana_laboral_id         UUID          NOT NULL REFERENCES semana_laboral(id),
    -- v2.0: renombrado de tesorero_id (gerencia también puede registrar pagos)
    registrado_por_id         UUID          NOT NULL REFERENCES usuario(id),
    monto_comisiones_vendedor NUMERIC(12,2) NOT NULL DEFAULT 0
                              CHECK (monto_comisiones_vendedor >= 0),
    -- NULL para vendedores que no son líderes de equipo
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
    CONSTRAINT uq_pago_vendedor_semana
        UNIQUE (vendedor_id, semana_laboral_id),
    CONSTRAINT ck_pago_total CHECK (
        total = monto_comisiones_vendedor + monto_comisiones_equipo
              + monto_bonos_finde + monto_premios_juegos
    )
);

CREATE TABLE registro_comision (
    id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    -- NULL para BONO_FIN_SEMANA y BONO_RECORD (no atados a una venta específica)
    venta_id            UUID          REFERENCES venta(id),
    beneficiario_id     UUID          NOT NULL REFERENCES usuario(id),
    semana_laboral_id   UUID          NOT NULL REFERENCES semana_laboral(id),
    tipo                comision_tipo NOT NULL,
    monto               NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    moneda              moneda_tipo   NOT NULL,
    fecha_calculo       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    -- v2.0: trazabilidad al pago (NULL mientras la semana está abierta)
    pago_vendedor_id    UUID          REFERENCES pago_vendedor(id),
    -- v2.0: qué fila de tabla_comision generó este monto (auditoría histórica)
    tabla_comision_id   UUID          REFERENCES tabla_comision(id),
    -- v2.0: qué umbral del líder se aplicó (solo LIDER_EQUIPO)
    umbral_lider_id     UUID          REFERENCES umbral_lider(id),
    -- v2.0: enlace al día del dashboard (obligatorio para bonos sin venta)
    jornada_vendedor_id UUID          REFERENCES jornada_vendedor(id),

    -- v2.0 fix: BONO_RECORD también va sin venta (igual que BONO_FIN_SEMANA)
    CONSTRAINT ck_comision_venta_coherente CHECK (
        (tipo IN ('BONO_FIN_SEMANA', 'BONO_RECORD') AND venta_id IS NULL) OR
        (tipo NOT IN ('BONO_FIN_SEMANA', 'BONO_RECORD') AND venta_id IS NOT NULL)
    ),
    -- Los bonos sin venta requieren jornada_vendedor para el dashboard
    CONSTRAINT ck_comision_jornada CHECK (
        tipo NOT IN ('BONO_FIN_SEMANA', 'BONO_RECORD')
        OR jornada_vendedor_id IS NOT NULL
    ),
    -- umbral_lider solo aplica a comisiones de tipo LIDER_EQUIPO
    CONSTRAINT ck_comision_umbral CHECK (
        umbral_lider_id IS NULL OR tipo = 'LIDER_EQUIPO'
    )
);

CREATE TABLE rendicion_efectivo (
    id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    vendedor_id       UUID          NOT NULL REFERENCES usuario(id),
    lider_id          UUID          NOT NULL REFERENCES usuario(id),
    semana_laboral_id UUID          NOT NULL REFERENCES semana_laboral(id),
    monto             NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    moneda            moneda_tipo   NOT NULL,
    fecha_rendicion   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    observaciones     TEXT,
    CONSTRAINT ck_rendicion_actores_distintos
        CHECK (vendedor_id != lider_id)
);

-- v2.0: FK de venta.rendicion_efectivo_id declarada aquí porque
-- rendicion_efectivo se crea después de venta
ALTER TABLE venta
    ADD CONSTRAINT fk_venta_rendicion
    FOREIGN KEY (rendicion_efectivo_id) REFERENCES rendicion_efectivo(id);


-- ================================================================
-- CLUSTER 6 — INVENTARIO DE CUPONES FÍSICOS
-- ================================================================

CREATE TABLE lote_ingreso_cupones (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    cupon_id          UUID        NOT NULL REFERENCES cupon(id),
    cantidad          INTEGER     NOT NULL CHECK (cantidad > 0),
    registrado_por_id UUID        NOT NULL REFERENCES usuario(id),
    fecha_ingreso     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    observaciones     TEXT
);

CREATE TABLE movimiento_cupon (
    id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    lote_id           UUID            NOT NULL REFERENCES lote_ingreso_cupones(id),
    tipo              movimiento_tipo NOT NULL,
    cantidad          INTEGER         NOT NULL CHECK (cantidad > 0),
    equipo_id         UUID            REFERENCES equipo(id),
    vendedor_id       UUID            REFERENCES usuario(id),
    registrado_por_id UUID            NOT NULL REFERENCES usuario(id),
    fecha             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    motivo            TEXT,
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
    venta_id        UUID              REFERENCES venta(id),
    leida           BOOLEAN           NOT NULL DEFAULT FALSE,
    fecha_creacion  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    fecha_lectura   TIMESTAMPTZ,
    CONSTRAINT ck_notificacion_lectura CHECK (
        (leida = FALSE AND fecha_lectura IS NULL) OR
        (leida = TRUE  AND fecha_lectura IS NOT NULL)
    )
);

-- Registro inmutable, append-only (RNF-010). Sin ON DELETE CASCADE.
CREATE TABLE log_auditoria (
    id               UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id       UUID                NOT NULL REFERENCES usuario(id),
    operacion        auditoria_operacion NOT NULL,
    entidad_tipo     VARCHAR(50)         NOT NULL,
    entidad_id       UUID                NOT NULL,
    datos_anteriores JSONB,
    datos_nuevos     JSONB               NOT NULL,
    fecha_hora       TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    ip_origen        VARCHAR(45)
);


-- ================================================================
-- CLUSTER 8 — JUEGOS (V2)
-- ================================================================

CREATE TABLE juego (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo         juego_tipo   NOT NULL,
    fecha        DATE         NOT NULL,
    estado       juego_estado NOT NULL DEFAULT 'ABIERTO',
    encargado_id UUID         NOT NULL REFERENCES usuario(id),
    ganador_id   UUID         REFERENCES usuario(id),
    monto_premio NUMERIC(12,2) CHECK (monto_premio > 0),
    moneda       moneda_tipo,
    fecha_cierre TIMESTAMPTZ,
    CONSTRAINT ck_juego_cierre CHECK (
        (estado = 'ABIERTO' AND ganador_id IS NULL AND fecha_cierre IS NULL) OR
        (estado = 'CERRADO' AND fecha_cierre IS NOT NULL)
    )
);

CREATE TABLE registro_juego (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    juego_id    UUID        NOT NULL REFERENCES juego(id),
    vendedor_id UUID        NOT NULL REFERENCES usuario(id),
    robo_de_id  UUID        REFERENCES usuario(id),
    puntos      INTEGER     NOT NULL DEFAULT 0 CHECK (puntos >= 0),
    url_foto    VARCHAR(500),
    fecha       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_registro_no_autorobo
        CHECK (robo_de_id IS NULL OR vendedor_id != robo_de_id)
);

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
-- ================================================================

-- ---- Cluster 1 — Geográfico ------------------------------------
CREATE INDEX idx_ciudad_pais           ON ciudad(pais_id);
CREATE INDEX idx_pdv_ciudad            ON punto_de_venta(ciudad_id);

-- ---- Cluster 2 — Organizacional --------------------------------
CREATE INDEX idx_usuario_equipo        ON usuario(equipo_id);
CREATE INDEX idx_usuario_rol           ON usuario(rol);
CREATE INDEX idx_usuario_clinica       ON usuario(clinica_id);

-- ---- Cluster 3 — Comercial -------------------------------------
CREATE INDEX idx_cupon_clinica         ON cupon(clinica_id);
CREATE INDEX idx_cupon_estado          ON cupon(estado);

-- ---- Cluster 4 — Transacción Central ---------------------------
CREATE INDEX idx_venta_vendedor        ON venta(vendedor_id);
CREATE INDEX idx_venta_cupon           ON venta(cupon_id);
CREATE INDEX idx_venta_cliente         ON venta(cliente_id);
CREATE INDEX idx_venta_semana          ON venta(semana_laboral_id);
CREATE INDEX idx_venta_pdv             ON venta(punto_de_venta_id);
CREATE INDEX idx_venta_fecha           ON venta(fecha_hora_registro DESC);
CREATE INDEX idx_venta_rendicion       ON venta(rendicion_efectivo_id);
CREATE INDEX idx_venta_pendientes      ON venta(estado) WHERE estado = 'PENDIENTE';
CREATE INDEX idx_venta_vendedor_semana ON venta(vendedor_id, semana_laboral_id);
CREATE INDEX idx_imagen_venta          ON imagen_venta(venta_id);
CREATE INDEX idx_asignacion_equipo     ON asignacion_equipo_punto(equipo_id);
CREATE INDEX idx_asignacion_pdv        ON asignacion_equipo_punto(punto_de_venta_id);
CREATE INDEX idx_asignacion_semana     ON asignacion_equipo_punto(semana_laboral_id);

-- ---- Cluster 4.5 — Dashboard -----------------------------------
CREATE INDEX idx_jornada_semana        ON jornada_diaria(semana_laboral_id);
CREATE INDEX idx_jornada_fecha         ON jornada_diaria(fecha DESC);
CREATE INDEX idx_jorv_jornada          ON jornada_vendedor(jornada_diaria_id);
CREATE INDEX idx_jorv_vendedor         ON jornada_vendedor(vendedor_id);
-- Dashboard central: vendedor + jornada
CREATE INDEX idx_jorv_vendedor_jornada ON jornada_vendedor(vendedor_id, jornada_diaria_id);

-- ---- Cluster 5 — Comisiones y Pagos ----------------------------
CREATE INDEX idx_regcom_venta          ON registro_comision(venta_id);
CREATE INDEX idx_regcom_beneficiario   ON registro_comision(beneficiario_id);
CREATE INDEX idx_regcom_semana         ON registro_comision(semana_laboral_id);
CREATE INDEX idx_regcom_ben_semana     ON registro_comision(beneficiario_id, semana_laboral_id);
CREATE INDEX idx_regcom_pago           ON registro_comision(pago_vendedor_id);
CREATE INDEX idx_regcom_tabla_com      ON registro_comision(tabla_comision_id);
CREATE INDEX idx_regcom_umbral         ON registro_comision(umbral_lider_id);
CREATE INDEX idx_regcom_jornada_v      ON registro_comision(jornada_vendedor_id);
-- Conteo de 🎁 por vendedor/día para el dashboard
CREATE INDEX idx_regcom_bonos
    ON registro_comision(beneficiario_id, tipo, fecha_calculo DESC)
    WHERE tipo IN ('BONO_FIN_SEMANA', 'BONO_RECORD');
CREATE INDEX idx_pago_vendedor_id      ON pago_vendedor(vendedor_id);
CREATE INDEX idx_pago_semana           ON pago_vendedor(semana_laboral_id);
CREATE INDEX idx_rendicion_vendedor    ON rendicion_efectivo(vendedor_id);
CREATE INDEX idx_rendicion_semana      ON rendicion_efectivo(semana_laboral_id);

-- ---- Cluster 6 — Inventario ------------------------------------
CREATE INDEX idx_lote_cupon            ON lote_ingreso_cupones(cupon_id);
CREATE INDEX idx_movimiento_lote       ON movimiento_cupon(lote_id);
CREATE INDEX idx_movimiento_equipo     ON movimiento_cupon(equipo_id);
CREATE INDEX idx_movimiento_vendedor   ON movimiento_cupon(vendedor_id);

-- ---- Cluster 7 — Sistema ---------------------------------------
CREATE INDEX idx_notif_destinatario    ON notificacion_interna(destinatario_id);
CREATE INDEX idx_notif_no_leidas       ON notificacion_interna(destinatario_id)
    WHERE leida = FALSE;
CREATE INDEX idx_log_usuario           ON log_auditoria(usuario_id);
CREATE INDEX idx_log_entidad           ON log_auditoria(entidad_tipo, entidad_id);
CREATE INDEX idx_log_fecha             ON log_auditoria(fecha_hora DESC);

-- ---- Cluster 8 — Juegos (V2) -----------------------------------
CREATE INDEX idx_juego_encargado       ON juego(encargado_id);
CREATE INDEX idx_regjuego_juego        ON registro_juego(juego_id);
CREATE INDEX idx_regjuego_vendedor     ON registro_juego(vendedor_id);
CREATE INDEX idx_premio_juego          ON premio_juego(juego_id);
