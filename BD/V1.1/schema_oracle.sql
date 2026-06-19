-- ================================================================
-- ATENAS Software — Sistema de Información
-- Esquema de Base de Datos v1.2  |  Oracle 12c R2+
-- Adaptado para Oracle SQL Developer Data Modeler
-- ================================================================
--
-- CONVERSIONES APLICADAS vs. PostgreSQL original:
--   · UUID          → VARCHAR2(36)   [generado por la aplicación]
--   · BOOLEAN       → NUMBER(1,0)    [0=FALSE, 1=TRUE]
--   · ENUM          → VARCHAR2(n) + CHECK constraint inline
--   · TEXT          → VARCHAR2(4000)
--   · JSONB         → CLOB
--   · TIMESTAMPTZ   → TIMESTAMP WITH TIME ZONE
--   · NUMERIC(n,m)  → NUMBER(n,m)
--   · INTEGER       → NUMBER(10,0)
--   · NOW()         → CURRENT_TIMESTAMP
--   · gen_random_uuid() → omitido (generado por la aplicación)
--   · Índice parcial WHERE → índice basado en función CASE WHEN
--     (Oracle no indexa NULLs: CASE devuelve NULL fuera del filtro)
--   · EXTRACT(DOW)  → validar en aplicación (NLS-dependiente en Oracle)
--   · BEGIN/COMMIT  → DDL en Oracle hace auto-commit implícito
--
-- CORRECCIÓN v1.2:
--   · ck_comision_venta_coherente: BONO_RECORD también permite venta_id NULL
--     (igual que BONO_FIN_SEMANA — no está atado a una venta específica)
-- ================================================================


-- ================================================================
-- CLUSTER 1 — GEOGRÁFICO
-- ================================================================

CREATE TABLE pais (
    id          VARCHAR2(36)   NOT NULL,
    nombre      VARCHAR2(100)  NOT NULL,
    codigo_iso  CHAR(2)        NOT NULL,
    moneda      VARCHAR2(3)    NOT NULL,
    activo      NUMBER(1,0)    DEFAULT 1 NOT NULL,
    CONSTRAINT pk_pais              PRIMARY KEY (id),
    CONSTRAINT uq_pais_codigo_iso   UNIQUE (codigo_iso),
    CONSTRAINT ck_pais_moneda       CHECK (moneda     IN ('CLP', 'ARS')),
    CONSTRAINT ck_pais_iso_upper    CHECK (codigo_iso =  UPPER(codigo_iso)),
    CONSTRAINT ck_pais_activo       CHECK (activo     IN (0, 1))
);

CREATE TABLE ciudad (
    id      VARCHAR2(36)   NOT NULL,
    nombre  VARCHAR2(100)  NOT NULL,
    pais_id VARCHAR2(36)   NOT NULL,
    activo  NUMBER(1,0)    DEFAULT 1 NOT NULL,
    CONSTRAINT pk_ciudad        PRIMARY KEY (id),
    CONSTRAINT fk_ciudad_pais   FOREIGN KEY (pais_id) REFERENCES pais(id),
    CONSTRAINT ck_ciudad_activo CHECK (activo IN (0, 1))
);

CREATE TABLE punto_de_venta (
    id          VARCHAR2(36)   NOT NULL,
    nombre      VARCHAR2(150)  NOT NULL,
    descripcion VARCHAR2(4000),
    direccion   VARCHAR2(255),
    ciudad_id   VARCHAR2(36)   NOT NULL,
    activo      NUMBER(1,0)    DEFAULT 1 NOT NULL,
    CONSTRAINT pk_punto_de_venta    PRIMARY KEY (id),
    CONSTRAINT fk_pdv_ciudad        FOREIGN KEY (ciudad_id) REFERENCES ciudad(id),
    CONSTRAINT ck_pdv_activo        CHECK (activo IN (0, 1))
);


-- ================================================================
-- CLUSTER 2 — ORGANIZACIONAL
-- FK circular equipo ↔ usuario → DEFERRABLE INITIALLY DEFERRED
-- (Oracle soporta esta sintaxis nativamente)
-- ================================================================

CREATE TABLE equipo (
    id       VARCHAR2(36)   NOT NULL,
    nombre   VARCHAR2(150)  NOT NULL,
    emoji    VARCHAR2(10),
    tipo     VARCHAR2(20)   NOT NULL,
    lider_id VARCHAR2(36),
    activo   NUMBER(1,0)    DEFAULT 1 NOT NULL,
    CONSTRAINT pk_equipo             PRIMARY KEY (id),
    CONSTRAINT ck_equipo_tipo        CHECK (tipo IN ('CAMPO','ADMINISTRACION','FINANZAS','GERENCIA','CLINICAS')),
    CONSTRAINT ck_equipo_lider_campo CHECK (tipo != 'CAMPO' OR lider_id IS NOT NULL),
    CONSTRAINT ck_equipo_activo      CHECK (activo IN (0, 1))
);

CREATE TABLE usuario (
    id                  VARCHAR2(36)   NOT NULL,
    nombre              VARCHAR2(100)  NOT NULL,
    apellido            VARCHAR2(100)  NOT NULL,
    email               VARCHAR2(150)  NOT NULL,
    username            VARCHAR2(50)   NOT NULL,
    password_hash       VARCHAR2(255)  NOT NULL,
    rol                 VARCHAR2(20)   NOT NULL,
    equipo_id           VARCHAR2(36)   NOT NULL,
    -- v1.2: portal clínicas — enlaza al usuario con su clínica
    -- FK declarada con ALTER TABLE después de CREATE TABLE clinica
    clinica_id          VARCHAR2(36),
    -- v1.1: dashboard operacional
    emoji_personal      VARCHAR2(10),
    meta_ventas_default NUMBER(5,0)    DEFAULT 10,
    record_ventas_dia   NUMBER(5,0)    DEFAULT 0 NOT NULL,
    activo              NUMBER(1,0)    DEFAULT 1 NOT NULL,
    fecha_creacion      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ultimo_acceso       TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_usuario           PRIMARY KEY (id),
    CONSTRAINT uq_usuario_email     UNIQUE (email),
    CONSTRAINT uq_usuario_username  UNIQUE (username),
    CONSTRAINT uq_usuario_emoji     UNIQUE (emoji_personal),
    CONSTRAINT fk_usuario_equipo    FOREIGN KEY (equipo_id) REFERENCES equipo(id),
    CONSTRAINT ck_usuario_rol       CHECK (rol IN (
        'VENDEDOR','LIDER','SECRETARIO','TESORERO',
        'ENCARGADO_JUEGOS','GERENCIA','CLINICA'
    )),
    CONSTRAINT ck_usuario_clinica_rol CHECK ((rol != 'CLINICA') OR (clinica_id IS NOT NULL)),
    CONSTRAINT ck_usuario_meta        CHECK (meta_ventas_default IS NULL OR meta_ventas_default > 0),
    CONSTRAINT ck_usuario_record      CHECK (record_ventas_dia >= 0),
    CONSTRAINT ck_usuario_activo      CHECK (activo IN (0, 1))
);

-- FK diferida para el círculo equipo ↔ usuario
ALTER TABLE equipo
    ADD CONSTRAINT fk_equipo_lider
    FOREIGN KEY (lider_id) REFERENCES usuario(id)
    DEFERRABLE INITIALLY DEFERRED;


-- ================================================================
-- CLUSTER 3 — COMERCIAL
-- ================================================================

CREATE TABLE clinica (
    id                VARCHAR2(36)   NOT NULL,
    nombre            VARCHAR2(150)  NOT NULL,
    tipo              VARCHAR2(100),
    contacto_nombre   VARCHAR2(150),
    contacto_email    VARCHAR2(150),
    contacto_telefono VARCHAR2(30),
    activo            NUMBER(1,0)    DEFAULT 1 NOT NULL,
    CONSTRAINT pk_clinica       PRIMARY KEY (id),
    CONSTRAINT ck_clinica_activo CHECK (activo IN (0, 1))
);

-- v1.2: FK de usuario.clinica_id declarada aquí porque
-- clinica se crea después de usuario
ALTER TABLE usuario
    ADD CONSTRAINT fk_usuario_clinica
    FOREIGN KEY (clinica_id) REFERENCES clinica(id);

CREATE TABLE cupon (
    id                   VARCHAR2(36)   NOT NULL,
    clinica_id           VARCHAR2(36)   NOT NULL,
    precio               NUMBER(12,2)   NOT NULL,
    permite_descuento    NUMBER(1,0)    DEFAULT 0 NOT NULL,
    precio_con_descuento NUMBER(12,2),
    prestaciones         VARCHAR2(500)  NOT NULL,
    estado               VARCHAR2(10)   DEFAULT 'BORRADOR' NOT NULL,
    fecha_creacion       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_activacion     TIMESTAMP WITH TIME ZONE,
    fecha_desactivacion  TIMESTAMP WITH TIME ZONE,
    creado_por_id        VARCHAR2(36)   NOT NULL,
    CONSTRAINT pk_cupon                   PRIMARY KEY (id),
    CONSTRAINT fk_cupon_clinica           FOREIGN KEY (clinica_id)     REFERENCES clinica(id),
    CONSTRAINT fk_cupon_creado_por        FOREIGN KEY (creado_por_id)  REFERENCES usuario(id),
    CONSTRAINT ck_cupon_precio            CHECK (precio > 0),
    CONSTRAINT ck_cupon_estado            CHECK (estado IN ('BORRADOR','ACTIVO','INACTIVO')),
    CONSTRAINT ck_cupon_permite_desc      CHECK (permite_descuento IN (0, 1)),
    CONSTRAINT ck_cupon_precio_desc       CHECK (
        precio_con_descuento IS NULL OR
        (precio_con_descuento > 0 AND precio_con_descuento < precio)
    ),
    CONSTRAINT ck_cupon_req_desc          CHECK (permite_descuento = 0 OR precio_con_descuento IS NOT NULL),
    CONSTRAINT ck_cupon_fecha_act         CHECK (estado != 'ACTIVO'   OR fecha_activacion   IS NOT NULL),
    CONSTRAINT ck_cupon_fecha_desact      CHECK (estado != 'INACTIVO' OR fecha_desactivacion IS NOT NULL)
);

-- Equivalente Oracle del índice parcial PostgreSQL (WHERE estado = 'ACTIVO').
-- CASE devuelve NULL cuando estado != 'ACTIVO'; Oracle no indexa NULLs.
-- Garantiza exactamente un cupón ACTIVO por clínica sin romper el historial.
CREATE UNIQUE INDEX idx_cupon_activo_por_clinica
    ON cupon(CASE WHEN estado = 'ACTIVO' THEN clinica_id ELSE NULL END);

CREATE TABLE cliente (
    id             VARCHAR2(36)   NOT NULL,
    nombre         VARCHAR2(100)  NOT NULL,
    apellido       VARCHAR2(100)  NOT NULL,
    dni            VARCHAR2(20)   NOT NULL,
    telefono       VARCHAR2(30),
    email          VARCHAR2(150),
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_cliente     PRIMARY KEY (id),
    CONSTRAINT uq_cliente_dni UNIQUE (dni)
);


-- ================================================================
-- SEMANA LABORAL
-- ================================================================

CREATE TABLE semana_laboral (
    id           VARCHAR2(36)   NOT NULL,
    fecha_inicio DATE           NOT NULL,
    fecha_fin    DATE           NOT NULL,
    estado       VARCHAR2(10)   DEFAULT 'ABIERTA' NOT NULL,
    CONSTRAINT pk_semana_laboral        PRIMARY KEY (id),
    CONSTRAINT uq_semana_fecha_inicio   UNIQUE (fecha_inicio),
    CONSTRAINT ck_semana_estado         CHECK (estado IN ('ABIERTA','CERRADA')),
    CONSTRAINT ck_semana_duracion       CHECK (fecha_fin = fecha_inicio + 6)
    -- Nota: la validación de que fecha_inicio sea lunes (EXTRACT DOW en PG)
    -- es NLS-dependiente en Oracle. Implementar en la aplicación o con trigger.
);


-- ================================================================
-- CLUSTER 4 — TRANSACCIÓN CENTRAL
-- ================================================================

CREATE TABLE venta (
    id                       VARCHAR2(36)   NOT NULL,
    vendedor_id              VARCHAR2(36)   NOT NULL,
    cupon_id                 VARCHAR2(36)   NOT NULL,
    cliente_id               VARCHAR2(36),
    semana_laboral_id        VARCHAR2(36)   NOT NULL,
    punto_de_venta_id        VARCHAR2(36)   NOT NULL,
    forma_pago               VARCHAR2(20)   NOT NULL,
    numero_autorizacion      VARCHAR2(100)  NOT NULL,
    origen_autorizacion      VARCHAR2(10)   NOT NULL,
    aplico_descuento         NUMBER(1,0)    DEFAULT 0 NOT NULL,
    precio_final             NUMBER(12,2)   NOT NULL,
    moneda                   VARCHAR2(3)    NOT NULL,
    estado                   VARCHAR2(15)   DEFAULT 'PENDIENTE' NOT NULL,
    fuera_de_campana         NUMBER(1,0)    DEFAULT 0 NOT NULL,
    fecha_hora_registro      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    secretario_validador_id  VARCHAR2(36),
    fecha_hora_validacion    TIMESTAMP WITH TIME ZONE,
    observaciones_validacion VARCHAR2(4000),
    CONSTRAINT pk_venta                     PRIMARY KEY (id),
    CONSTRAINT fk_venta_vendedor            FOREIGN KEY (vendedor_id)             REFERENCES usuario(id),
    CONSTRAINT fk_venta_cupon               FOREIGN KEY (cupon_id)                REFERENCES cupon(id),
    CONSTRAINT fk_venta_cliente             FOREIGN KEY (cliente_id)              REFERENCES cliente(id),
    CONSTRAINT fk_venta_semana              FOREIGN KEY (semana_laboral_id)       REFERENCES semana_laboral(id),
    CONSTRAINT fk_venta_pdv                 FOREIGN KEY (punto_de_venta_id)       REFERENCES punto_de_venta(id),
    CONSTRAINT fk_venta_secretario          FOREIGN KEY (secretario_validador_id) REFERENCES usuario(id),
    CONSTRAINT ck_venta_forma_pago          CHECK (forma_pago IN (
        'EFECTIVO','TRANSFERENCIA','POSNET_CREDITO',
        'POSNET_DEBITO','MERCADOPAGO','WEBPAY'
    )),
    CONSTRAINT ck_venta_origen              CHECK (origen_autorizacion IN ('EXTERNO','INTERNO')),
    CONSTRAINT ck_venta_estado              CHECK (estado IN ('PENDIENTE','VALIDADA','INVALIDA')),
    CONSTRAINT ck_venta_moneda              CHECK (moneda IN ('CLP','ARS')),
    CONSTRAINT ck_venta_precio              CHECK (precio_final > 0),
    CONSTRAINT ck_venta_descuento           CHECK (aplico_descuento   IN (0, 1)),
    CONSTRAINT ck_venta_fuera_campana       CHECK (fuera_de_campana   IN (0, 1)),
    CONSTRAINT ck_venta_autorizacion        CHECK (
        (forma_pago =  'EFECTIVO' AND origen_autorizacion = 'INTERNO') OR
        (forma_pago != 'EFECTIVO' AND origen_autorizacion = 'EXTERNO')
    ),
    CONSTRAINT ck_venta_observaciones       CHECK (
        estado != 'INVALIDA' OR observaciones_validacion IS NOT NULL
    ),
    CONSTRAINT ck_venta_coherencia_validacion CHECK (
        (estado = 'PENDIENTE'
            AND secretario_validador_id IS NULL
            AND fecha_hora_validacion   IS NULL)
        OR
        (estado IN ('VALIDADA','INVALIDA')
            AND secretario_validador_id IS NOT NULL
            AND fecha_hora_validacion   IS NOT NULL)
    )
);

CREATE TABLE imagen_venta (
    id                 VARCHAR2(36)   NOT NULL,
    venta_id           VARCHAR2(36)   NOT NULL,
    url_almacenamiento VARCHAR2(500)  NOT NULL,
    tamanio_bytes      NUMBER(10,0)   NOT NULL,
    fecha_subida       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_imagen_venta      PRIMARY KEY (id),
    CONSTRAINT fk_imagen_venta      FOREIGN KEY (venta_id) REFERENCES venta(id),
    CONSTRAINT ck_imagen_tamanio    CHECK (tamanio_bytes > 0)
);

CREATE TABLE traspaso_venta (
    id                VARCHAR2(36)   NOT NULL,
    venta_id          VARCHAR2(36)   NOT NULL,
    cupon_origen_id   VARCHAR2(36)   NOT NULL,
    cupon_destino_id  VARCHAR2(36)   NOT NULL,
    registrado_por_id VARCHAR2(36)   NOT NULL,
    motivo            VARCHAR2(4000) NOT NULL,
    fecha_traspaso    TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_traspaso_venta        PRIMARY KEY (id),
    CONSTRAINT uq_traspaso_venta        UNIQUE (venta_id),
    CONSTRAINT fk_traspaso_venta        FOREIGN KEY (venta_id)          REFERENCES venta(id),
    CONSTRAINT fk_traspaso_origen       FOREIGN KEY (cupon_origen_id)   REFERENCES cupon(id),
    CONSTRAINT fk_traspaso_destino      FOREIGN KEY (cupon_destino_id)  REFERENCES cupon(id),
    CONSTRAINT fk_traspaso_registrado   FOREIGN KEY (registrado_por_id) REFERENCES usuario(id),
    CONSTRAINT ck_traspaso_cupones      CHECK (cupon_origen_id != cupon_destino_id)
);

CREATE TABLE asignacion_equipo_punto (
    id                VARCHAR2(36)   NOT NULL,
    punto_de_venta_id VARCHAR2(36)   NOT NULL,
    equipo_id         VARCHAR2(36)   NOT NULL,
    semana_laboral_id VARCHAR2(36)   NOT NULL,
    fecha_inicio      TIMESTAMP WITH TIME ZONE NOT NULL,
    fecha_fin         TIMESTAMP WITH TIME ZONE,
    activo            NUMBER(1,0)    DEFAULT 1 NOT NULL,
    registrado_por_id VARCHAR2(36)   NOT NULL,
    CONSTRAINT pk_asignacion_equipo_punto   PRIMARY KEY (id),
    CONSTRAINT uq_asignacion_por_semana     UNIQUE (equipo_id, punto_de_venta_id, semana_laboral_id),
    CONSTRAINT fk_asignacion_pdv            FOREIGN KEY (punto_de_venta_id)   REFERENCES punto_de_venta(id),
    CONSTRAINT fk_asignacion_equipo         FOREIGN KEY (equipo_id)           REFERENCES equipo(id),
    CONSTRAINT fk_asignacion_semana         FOREIGN KEY (semana_laboral_id)   REFERENCES semana_laboral(id),
    CONSTRAINT fk_asignacion_registrado     FOREIGN KEY (registrado_por_id)   REFERENCES usuario(id),
    CONSTRAINT ck_asignacion_fechas         CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio),
    CONSTRAINT ck_asignacion_activo         CHECK (activo IN (0, 1))
);


-- ================================================================
-- CLUSTER 4.5 — DASHBOARD OPERACIONAL
-- ================================================================

CREATE TABLE jornada_diaria (
    id                  VARCHAR2(36)   NOT NULL,
    vendedor_id         VARCHAR2(36)   NOT NULL,
    fecha               DATE           NOT NULL,
    meta_ventas         NUMBER(5,0)    NOT NULL,
    tipo_inscripcion    VARCHAR2(15)   DEFAULT 'AUTO_VENTA' NOT NULL,
    record_superado_hoy NUMBER(1,0)    DEFAULT 0 NOT NULL,
    fecha_inscripcion   TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_jornada_diaria            PRIMARY KEY (id),
    CONSTRAINT uq_jornada_vendedor_fecha    UNIQUE (vendedor_id, fecha),
    CONSTRAINT fk_jornada_vendedor          FOREIGN KEY (vendedor_id) REFERENCES usuario(id),
    CONSTRAINT ck_jornada_tipo              CHECK (tipo_inscripcion IN ('MANUAL','AUTO_VENTA')),
    CONSTRAINT ck_jornada_meta              CHECK (meta_ventas > 0),
    CONSTRAINT ck_jornada_record            CHECK (record_superado_hoy IN (0, 1))
);


-- ================================================================
-- CLUSTER 5 — COMISIONES Y PAGOS
-- ================================================================

CREATE TABLE tabla_comision (
    id             VARCHAR2(36)   NOT NULL,
    precio_venta   NUMBER(12,2)   NOT NULL,
    monto_comision NUMBER(12,2)   NOT NULL,
    activo         NUMBER(1,0)    DEFAULT 1 NOT NULL,
    CONSTRAINT pk_tabla_comision        PRIMARY KEY (id),
    CONSTRAINT uq_tabla_comision_precio UNIQUE (precio_venta),
    CONSTRAINT ck_tblcom_precio         CHECK (precio_venta   > 0),
    CONSTRAINT ck_tblcom_monto          CHECK (monto_comision > 0),
    CONSTRAINT ck_tblcom_activo         CHECK (activo IN (0, 1))
);

CREATE TABLE umbral_lider (
    id                   VARCHAR2(36)   NOT NULL,
    ventas_desde         NUMBER(5,0)    NOT NULL,
    ventas_hasta         NUMBER(5,0),
    monto_comision_lider NUMBER(12,2)   NOT NULL,
    activo               NUMBER(1,0)    DEFAULT 1 NOT NULL,
    CONSTRAINT pk_umbral_lider      PRIMARY KEY (id),
    CONSTRAINT ck_umbral_desde      CHECK (ventas_desde >= 0),
    CONSTRAINT ck_umbral_hasta      CHECK (ventas_hasta IS NULL OR ventas_hasta > ventas_desde),
    CONSTRAINT ck_umbral_monto      CHECK (monto_comision_lider > 0),
    CONSTRAINT ck_umbral_activo     CHECK (activo IN (0, 1))
);

CREATE TABLE registro_comision (
    id                VARCHAR2(36)   NOT NULL,
    -- NULL para BONO_FIN_SEMANA y BONO_RECORD (no atados a una venta específica)
    venta_id          VARCHAR2(36),
    beneficiario_id   VARCHAR2(36)   NOT NULL,
    semana_laboral_id VARCHAR2(36)   NOT NULL,
    tipo              VARCHAR2(25)   NOT NULL,
    monto             NUMBER(12,2)   NOT NULL,
    moneda            VARCHAR2(3)    NOT NULL,
    recalculado       NUMBER(1,0)    DEFAULT 0 NOT NULL,
    fecha_calculo     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_registro_comision         PRIMARY KEY (id),
    CONSTRAINT fk_regcom_venta              FOREIGN KEY (venta_id)          REFERENCES venta(id),
    CONSTRAINT fk_regcom_beneficiario       FOREIGN KEY (beneficiario_id)   REFERENCES usuario(id),
    CONSTRAINT fk_regcom_semana             FOREIGN KEY (semana_laboral_id) REFERENCES semana_laboral(id),
    CONSTRAINT ck_regcom_tipo               CHECK (tipo IN (
        'VENDEDOR_INDIVIDUAL','LIDER_EQUIPO','BONO_FIN_SEMANA','BONO_RECORD'
    )),
    CONSTRAINT ck_regcom_moneda             CHECK (moneda IN ('CLP','ARS')),
    CONSTRAINT ck_regcom_monto              CHECK (monto > 0),
    CONSTRAINT ck_regcom_recalculado        CHECK (recalculado IN (0, 1)),
    -- BONO_FIN_SEMANA y BONO_RECORD no tienen venta asociada; los otros tipos sí
    CONSTRAINT ck_comision_venta_coherente  CHECK (
        (tipo IN ('BONO_FIN_SEMANA','BONO_RECORD') AND venta_id IS NULL) OR
        (tipo NOT IN ('BONO_FIN_SEMANA','BONO_RECORD') AND venta_id IS NOT NULL)
    )
);

CREATE TABLE pago_vendedor (
    id                        VARCHAR2(36)   NOT NULL,
    vendedor_id               VARCHAR2(36)   NOT NULL,
    semana_laboral_id         VARCHAR2(36)   NOT NULL,
    tesorero_id               VARCHAR2(36)   NOT NULL,
    monto_comisiones_vendedor NUMBER(12,2)   DEFAULT 0 NOT NULL,
    monto_comisiones_equipo   NUMBER(12,2)   DEFAULT 0 NOT NULL,
    monto_bonos_finde         NUMBER(12,2)   DEFAULT 0 NOT NULL,
    monto_premios_juegos      NUMBER(12,2)   DEFAULT 0 NOT NULL,
    total                     NUMBER(12,2)   NOT NULL,
    moneda                    VARCHAR2(3)    NOT NULL,
    fecha_pago                DATE           NOT NULL,
    fecha_registro            TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_pago_vendedor         PRIMARY KEY (id),
    CONSTRAINT uq_pago_vendedor_semana  UNIQUE (vendedor_id, semana_laboral_id),
    CONSTRAINT fk_pago_vendedor         FOREIGN KEY (vendedor_id)       REFERENCES usuario(id),
    CONSTRAINT fk_pago_semana           FOREIGN KEY (semana_laboral_id) REFERENCES semana_laboral(id),
    CONSTRAINT fk_pago_tesorero         FOREIGN KEY (tesorero_id)       REFERENCES usuario(id),
    CONSTRAINT ck_pago_moneda           CHECK (moneda IN ('CLP','ARS')),
    CONSTRAINT ck_pago_com_vendedor     CHECK (monto_comisiones_vendedor >= 0),
    CONSTRAINT ck_pago_com_equipo       CHECK (monto_comisiones_equipo   >= 0),
    CONSTRAINT ck_pago_bonos            CHECK (monto_bonos_finde         >= 0),
    CONSTRAINT ck_pago_premios          CHECK (monto_premios_juegos      >= 0),
    CONSTRAINT ck_pago_total            CHECK (total >= 0),
    CONSTRAINT ck_pago_total_suma       CHECK (
        total = monto_comisiones_vendedor + monto_comisiones_equipo
              + monto_bonos_finde        + monto_premios_juegos
    )
);

CREATE TABLE rendicion_efectivo (
    id                VARCHAR2(36)   NOT NULL,
    vendedor_id       VARCHAR2(36)   NOT NULL,
    lider_id          VARCHAR2(36)   NOT NULL,
    semana_laboral_id VARCHAR2(36)   NOT NULL,
    monto             NUMBER(12,2)   NOT NULL,
    moneda            VARCHAR2(3)    NOT NULL,
    fecha_rendicion   TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones     VARCHAR2(4000),
    CONSTRAINT pk_rendicion_efectivo    PRIMARY KEY (id),
    CONSTRAINT fk_rendicion_vendedor    FOREIGN KEY (vendedor_id)       REFERENCES usuario(id),
    CONSTRAINT fk_rendicion_lider       FOREIGN KEY (lider_id)          REFERENCES usuario(id),
    CONSTRAINT fk_rendicion_semana      FOREIGN KEY (semana_laboral_id) REFERENCES semana_laboral(id),
    CONSTRAINT ck_rendicion_moneda      CHECK (moneda IN ('CLP','ARS')),
    CONSTRAINT ck_rendicion_monto       CHECK (monto > 0),
    CONSTRAINT ck_rendicion_actores     CHECK (vendedor_id != lider_id)
);


-- ================================================================
-- CLUSTER 6 — INVENTARIO DE CUPONES FÍSICOS
-- ================================================================

CREATE TABLE lote_ingreso_cupones (
    id                VARCHAR2(36)   NOT NULL,
    cupon_id          VARCHAR2(36)   NOT NULL,
    cantidad          NUMBER(6,0)    NOT NULL,
    registrado_por_id VARCHAR2(36)   NOT NULL,
    fecha_ingreso     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones     VARCHAR2(4000),
    CONSTRAINT pk_lote_ingreso_cupones  PRIMARY KEY (id),
    CONSTRAINT fk_lote_cupon            FOREIGN KEY (cupon_id)          REFERENCES cupon(id),
    CONSTRAINT fk_lote_registrado       FOREIGN KEY (registrado_por_id) REFERENCES usuario(id),
    CONSTRAINT ck_lote_cantidad         CHECK (cantidad > 0)
);

CREATE TABLE movimiento_cupon (
    id                VARCHAR2(36)   NOT NULL,
    lote_id           VARCHAR2(36)   NOT NULL,
    tipo              VARCHAR2(25)   NOT NULL,
    cantidad          NUMBER(6,0)    NOT NULL,
    equipo_id         VARCHAR2(36),
    vendedor_id       VARCHAR2(36),
    registrado_por_id VARCHAR2(36)   NOT NULL,
    fecha             TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    motivo            VARCHAR2(4000),
    CONSTRAINT pk_movimiento_cupon      PRIMARY KEY (id),
    CONSTRAINT fk_movimiento_lote       FOREIGN KEY (lote_id)           REFERENCES lote_ingreso_cupones(id),
    CONSTRAINT fk_movimiento_equipo     FOREIGN KEY (equipo_id)         REFERENCES equipo(id),
    CONSTRAINT fk_movimiento_vendedor   FOREIGN KEY (vendedor_id)       REFERENCES usuario(id),
    CONSTRAINT fk_movimiento_registrado FOREIGN KEY (registrado_por_id) REFERENCES usuario(id),
    CONSTRAINT ck_movimiento_tipo       CHECK (tipo IN (
        'ASIGNACION_EQUIPO','ASIGNACION_VENDEDOR','PERDIDA','DANO','DEVOLUCION'
    )),
    CONSTRAINT ck_movimiento_cantidad   CHECK (cantidad > 0),
    CONSTRAINT ck_movimiento_coherencia CHECK (
        (tipo = 'ASIGNACION_EQUIPO'    AND equipo_id IS NOT NULL AND vendedor_id IS NULL) OR
        (tipo = 'ASIGNACION_VENDEDOR'  AND vendedor_id IS NOT NULL AND equipo_id IS NULL) OR
        (tipo IN ('PERDIDA','DANO')    AND vendedor_id IS NOT NULL AND motivo IS NOT NULL) OR
        (tipo = 'DEVOLUCION')
    )
);


-- ================================================================
-- CLUSTER 7 — SISTEMA E INFRAESTRUCTURA
-- ================================================================

CREATE TABLE notificacion_interna (
    id              VARCHAR2(36)   NOT NULL,
    destinatario_id VARCHAR2(36)   NOT NULL,
    tipo            VARCHAR2(25)   NOT NULL,
    titulo          VARCHAR2(200)  NOT NULL,
    mensaje         VARCHAR2(4000) NOT NULL,
    venta_id        VARCHAR2(36),
    leida           NUMBER(1,0)    DEFAULT 0 NOT NULL,
    fecha_creacion  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_lectura   TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_notificacion_interna  PRIMARY KEY (id),
    CONSTRAINT fk_notif_destinatario    FOREIGN KEY (destinatario_id) REFERENCES usuario(id),
    CONSTRAINT fk_notif_venta           FOREIGN KEY (venta_id)        REFERENCES venta(id),
    CONSTRAINT ck_notif_tipo            CHECK (tipo IN ('VENTA_FUERA_CAMPANA')),
    CONSTRAINT ck_notif_leida           CHECK (leida IN (0, 1)),
    CONSTRAINT ck_notif_lectura         CHECK (
        (leida = 0 AND fecha_lectura IS NULL) OR
        (leida = 1 AND fecha_lectura IS NOT NULL)
    )
);

CREATE TABLE log_auditoria (
    id               VARCHAR2(36)   NOT NULL,
    usuario_id       VARCHAR2(36)   NOT NULL,
    operacion        VARCHAR2(25)   NOT NULL,
    entidad_tipo     VARCHAR2(50)   NOT NULL,
    entidad_id       VARCHAR2(36)   NOT NULL,
    datos_anteriores CLOB,
    datos_nuevos     CLOB           NOT NULL,
    fecha_hora       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ip_origen        VARCHAR2(45),
    CONSTRAINT pk_log_auditoria     PRIMARY KEY (id),
    CONSTRAINT fk_log_usuario       FOREIGN KEY (usuario_id) REFERENCES usuario(id),
    CONSTRAINT ck_log_operacion     CHECK (operacion IN (
        'VALIDAR_VENTA','INVALIDAR_VENTA','ACTIVAR_CUPON','DESACTIVAR_CUPON',
        'REGISTRAR_PAGO','MODIFICAR_COMISION','TRASPASAR_VENTA',
        'CREAR_USUARIO','MODIFICAR_USUARIO'
    ))
);


-- ================================================================
-- CLUSTER 8 — JUEGOS (V2)
-- ================================================================

CREATE TABLE juego (
    id           VARCHAR2(36)   NOT NULL,
    tipo         VARCHAR2(20)   NOT NULL,
    fecha        DATE           NOT NULL,
    estado       VARCHAR2(10)   DEFAULT 'ABIERTO' NOT NULL,
    encargado_id VARCHAR2(36)   NOT NULL,
    ganador_id   VARCHAR2(36),
    monto_premio NUMBER(12,2),
    moneda       VARCHAR2(3),
    fecha_cierre TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_juego             PRIMARY KEY (id),
    CONSTRAINT fk_juego_encargado   FOREIGN KEY (encargado_id) REFERENCES usuario(id),
    CONSTRAINT fk_juego_ganador     FOREIGN KEY (ganador_id)   REFERENCES usuario(id),
    CONSTRAINT ck_juego_tipo        CHECK (tipo   IN ('FOTOS_CLIENTES','ROBOS','POZO_DEL_DIA')),
    CONSTRAINT ck_juego_estado      CHECK (estado IN ('ABIERTO','CERRADO')),
    CONSTRAINT ck_juego_moneda      CHECK (moneda IS NULL OR moneda IN ('CLP','ARS')),
    CONSTRAINT ck_juego_cierre      CHECK (
        (estado = 'ABIERTO'  AND ganador_id IS NULL  AND fecha_cierre IS NULL) OR
        (estado = 'CERRADO'  AND fecha_cierre IS NOT NULL)
    )
);

CREATE TABLE registro_juego (
    id          VARCHAR2(36)   NOT NULL,
    juego_id    VARCHAR2(36)   NOT NULL,
    vendedor_id VARCHAR2(36)   NOT NULL,
    robo_de_id  VARCHAR2(36),
    puntos      NUMBER(5,0)    DEFAULT 0 NOT NULL,
    url_foto    VARCHAR2(500),
    fecha       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_registro_juego        PRIMARY KEY (id),
    CONSTRAINT fk_regjuego_juego        FOREIGN KEY (juego_id)    REFERENCES juego(id),
    CONSTRAINT fk_regjuego_vendedor     FOREIGN KEY (vendedor_id) REFERENCES usuario(id),
    CONSTRAINT fk_regjuego_robo_de      FOREIGN KEY (robo_de_id)  REFERENCES usuario(id),
    CONSTRAINT ck_regjuego_puntos       CHECK (puntos >= 0),
    CONSTRAINT ck_regjuego_no_autorobo  CHECK (robo_de_id IS NULL OR vendedor_id != robo_de_id)
);

CREATE TABLE premio_juego (
    id          VARCHAR2(36)   NOT NULL,
    juego_id    VARCHAR2(36)   NOT NULL,
    vendedor_id VARCHAR2(36)   NOT NULL,
    monto       NUMBER(12,2)   NOT NULL,
    moneda      VARCHAR2(3)    NOT NULL,
    fecha       DATE           NOT NULL,
    CONSTRAINT pk_premio_juego      PRIMARY KEY (id),
    CONSTRAINT fk_premio_juego      FOREIGN KEY (juego_id)    REFERENCES juego(id),
    CONSTRAINT fk_premio_vendedor   FOREIGN KEY (vendedor_id) REFERENCES usuario(id),
    CONSTRAINT ck_premio_monto      CHECK (monto > 0),
    CONSTRAINT ck_premio_moneda     CHECK (moneda IN ('CLP','ARS'))
);


-- ================================================================
-- ÍNDICES
-- ================================================================

-- Cluster Geográfico
CREATE INDEX idx_ciudad_pais              ON ciudad(pais_id);
CREATE INDEX idx_pdv_ciudad               ON punto_de_venta(ciudad_id);

-- Cluster Organizacional
CREATE INDEX idx_usuario_equipo           ON usuario(equipo_id);
CREATE INDEX idx_usuario_rol              ON usuario(rol);
CREATE INDEX idx_usuario_clinica          ON usuario(clinica_id);

-- Cluster Comercial
CREATE INDEX idx_cupon_clinica            ON cupon(clinica_id);
CREATE INDEX idx_cupon_estado             ON cupon(estado);

-- Transacción Central
CREATE INDEX idx_venta_vendedor           ON venta(vendedor_id);
CREATE INDEX idx_venta_cupon              ON venta(cupon_id);
CREATE INDEX idx_venta_cliente            ON venta(cliente_id);
CREATE INDEX idx_venta_semana             ON venta(semana_laboral_id);
CREATE INDEX idx_venta_pdv                ON venta(punto_de_venta_id);
CREATE INDEX idx_venta_fecha              ON venta(fecha_hora_registro DESC);
CREATE INDEX idx_venta_pendientes         ON venta(estado);
CREATE INDEX idx_venta_vendedor_semana    ON venta(vendedor_id, semana_laboral_id);
CREATE INDEX idx_imagen_venta             ON imagen_venta(venta_id);
CREATE INDEX idx_asignacion_equipo        ON asignacion_equipo_punto(equipo_id);
CREATE INDEX idx_asignacion_pdv           ON asignacion_equipo_punto(punto_de_venta_id);
CREATE INDEX idx_asignacion_semana        ON asignacion_equipo_punto(semana_laboral_id);

-- Dashboard Operacional
CREATE INDEX idx_jornada_vendedor         ON jornada_diaria(vendedor_id);
CREATE INDEX idx_jornada_fecha            ON jornada_diaria(fecha DESC);
CREATE INDEX idx_jornada_vendedor_fecha   ON jornada_diaria(vendedor_id, fecha DESC);

-- Comisiones y Pagos
CREATE INDEX idx_regcom_venta             ON registro_comision(venta_id);
CREATE INDEX idx_regcom_beneficiario      ON registro_comision(beneficiario_id);
CREATE INDEX idx_regcom_semana            ON registro_comision(semana_laboral_id);
CREATE INDEX idx_regcom_ben_semana        ON registro_comision(beneficiario_id, semana_laboral_id);
CREATE INDEX idx_regcom_bonos             ON registro_comision(beneficiario_id, tipo, fecha_calculo DESC);
CREATE INDEX idx_pago_vendedor_id         ON pago_vendedor(vendedor_id);
CREATE INDEX idx_pago_semana              ON pago_vendedor(semana_laboral_id);
CREATE INDEX idx_rendicion_vendedor       ON rendicion_efectivo(vendedor_id);
CREATE INDEX idx_rendicion_semana         ON rendicion_efectivo(semana_laboral_id);

-- Inventario
CREATE INDEX idx_lote_cupon               ON lote_ingreso_cupones(cupon_id);
CREATE INDEX idx_movimiento_lote          ON movimiento_cupon(lote_id);
CREATE INDEX idx_movimiento_equipo        ON movimiento_cupon(equipo_id);
CREATE INDEX idx_movimiento_vendedor      ON movimiento_cupon(vendedor_id);

-- Sistema
CREATE INDEX idx_notif_destinatario       ON notificacion_interna(destinatario_id);
CREATE INDEX idx_log_usuario              ON log_auditoria(usuario_id);
CREATE INDEX idx_log_entidad              ON log_auditoria(entidad_tipo, entidad_id);
CREATE INDEX idx_log_fecha                ON log_auditoria(fecha_hora DESC);

-- Juegos (V2)
CREATE INDEX idx_juego_encargado          ON juego(encargado_id);
CREATE INDEX idx_registro_juego_juego     ON registro_juego(juego_id);
CREATE INDEX idx_registro_juego_vendedor  ON registro_juego(vendedor_id);
CREATE INDEX idx_premio_juego_idx         ON premio_juego(juego_id);

-- Fin del esquema
