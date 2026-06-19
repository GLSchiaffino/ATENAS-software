-- ================================================================
-- ATENAS Software — Sistema de Información
-- Datos semilla (seeds) v1.3
-- ================================================================
-- Ejecutar DESPUÉS de schema.sql
--
-- Contiene los datos mínimos para que el sistema funcione:
--   · Países operacionales
--   · Equipos administrativos (uno por tipo de rol de oficina)
--
-- Los UUIDs son fijos para facilitar referencias en tests y scripts.
-- Convención: 00000000-0000-0000-XXXX-YYYYYYYYYYYY
--   XXXX = cluster (0001 = pais, 0002 = equipo)
--   YYYY = número secuencial
-- ================================================================

BEGIN;

-- ----------------------------------------------------------------
-- PAÍSES
-- ----------------------------------------------------------------

INSERT INTO pais (id, nombre, codigo_iso, moneda) VALUES
    ('00000000-0000-0000-0001-000000000001', 'Chile',     'CL', 'CLP'),
    ('00000000-0000-0000-0001-000000000002', 'Argentina', 'AR', 'ARS');


-- ----------------------------------------------------------------
-- EQUIPOS ADMINISTRATIVOS
-- Creados sin lider_id (válido para tipo != 'CAMPO').
-- ----------------------------------------------------------------

INSERT INTO equipo (id, nombre, tipo, lider_id) VALUES
    (
        '00000000-0000-0000-0002-000000000001',
        'Administración',
        'ADMINISTRACION',
        NULL    -- Secretarios y Encargados de Juegos
    ),
    (
        '00000000-0000-0000-0002-000000000002',
        'Finanzas',
        'FINANZAS',
        NULL    -- Tesoreros
    ),
    (
        '00000000-0000-0000-0002-000000000003',
        'Gerencia',
        'GERENCIA',
        NULL    -- Gerentes
    ),
    (
        -- v1.2: equipo contenedor de todos los usuarios con rol CLINICA
        '00000000-0000-0000-0002-000000000004',
        'Portal Clínicas',
        'CLINICAS',
        NULL
    );

COMMIT;

-- ----------------------------------------------------------------
-- NOTAS DE BOOTSTRAP PARA EL EQUIPO DE DESARROLLO
-- ----------------------------------------------------------------
--
-- 1. PRIMER USUARIO GERENTE
--    Usar FK diferida porque equipo y usuario se referencian mutuamente:
--
--    BEGIN;
--    SET CONSTRAINTS fk_equipo_lider DEFERRED;
--    INSERT INTO usuario (id, nombre, apellido, email, username,
--                         password_hash, rol, equipo_id)
--    VALUES (
--        '00000000-0000-0000-0003-000000000001',
--        'Admin', 'Sistema', 'admin@atenas.com', 'admin',
--        '<bcrypt_hash>', 'GERENCIA',
--        '00000000-0000-0000-0002-000000000003'
--    );
--    COMMIT;
--
-- 2. USUARIO DE CLÍNICA (v1.2+)
--    Requiere que la clínica ya exista en la tabla clinica:
--
--    INSERT INTO usuario (nombre, apellido, email, username, password_hash,
--                         rol, equipo_id, clinica_id)
--    VALUES (
--        'Recepción', 'Dental Smile',
--        'recepcion@dentalsmile.com', 'dental_smile',
--        '<bcrypt_hash>', 'CLINICA',
--        '00000000-0000-0000-0002-000000000004',  -- equipo Portal Clínicas
--        '<uuid de la clínica>'
--    );
--
-- 3. PRIMER EQUIPO DE CAMPO + LÍDER
--    a. Insertar equipo CAMPO sin lider_id
--    b. Insertar usuario LIDER referenciando ese equipo
--    c. UPDATE equipo SET lider_id = <uuid_lider> WHERE id = <uuid_equipo>
-- ----------------------------------------------------------------
