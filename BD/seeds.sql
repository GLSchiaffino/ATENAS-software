-- ================================================================
-- ATENAS — Sistema de Información
-- Datos semilla (seeds) v1.0
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
-- lider_id puede actualizarse luego si se desea designar un responsable.
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
    );

-- ----------------------------------------------------------------
-- NOTA PARA EL EQUIPO DE DESARROLLO:
--
-- Para crear el primer usuario Gerente (bootstrap del sistema):
--
--   BEGIN;
--   SET CONSTRAINTS fk_equipo_lider DEFERRED;
--
--   INSERT INTO usuario (id, nombre, apellido, email, username,
--                        password_hash, rol, equipo_id)
--   VALUES (
--       '00000000-0000-0000-0003-000000000001',
--       'Admin', 'Sistema', 'admin@atenas.com', 'admin',
--       '<bcrypt_hash>', 'GERENCIA',
--       '00000000-0000-0000-0002-000000000003'
--   );
--
--   COMMIT;
--
-- Para crear el primer Vendedor / Líder de campo:
--   1. Primero crear el EQUIPO de tipo CAMPO sin lider_id
--   2. Crear el usuario LIDER referenciando ese equipo
--   3. UPDATE equipo SET lider_id = <id_usuario> WHERE id = <id_equipo>
-- ----------------------------------------------------------------

COMMIT;
