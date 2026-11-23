-- =============================================================================
-- Proyecto integrador · Equipo 5 · Sistema de ventas e inventarios
-- 02_dml.sql — Datos de prueba ficticios y coherentes.
--
-- Requisito: ejecutar inmediatamente después de 01_ddl.sql (base vacía).
-- Ejecución:  mysql -u root --default-character-set=utf8mb4 < sql/02_dml.sql
--
-- Contenido
--   8 categorías · 30 productos · 6 proveedores · 41 ofertas producto–proveedor
--   21 clientes (20 + PÚBLICO EN GENERAL) · 5 empleados · 4 métodos de pago
--   5 tipos de movimiento · 60 ventas (jun–nov 2026) · pagos · ajustes
--
-- Datos sembrados a propósito para las consultas (docs/01_plan_corregido.md, Fase 6)
--   · Sin ventas (consulta 8):        HE-003, PI-002, JA-002 (descontinuado), SI-004
--   · Bajo umbral (consulta 4):       HE-001, PL-001, ME-004, SI-002
--   · Mayor gasto (consulta 7):       Constructora Robles, Inst. Eléctricas Mendoza,
--                                     Pinturas y Acabados del Norte
--   · Pagos parciales (PENDIENTE):    V22, V31, V35, V49
--   · Pendientes sin pago:            V55, V57
--   · Canceladas (DEVOLUCION):        V29, V47, V58
--   · Cambio de precio (RN-09):       HM-001 sube de $150 a $165 el 2026-08-01
--
-- Las ventas se registran con CALL registrar_venta, por lo que los triggers
-- generan las salidas de inventario con la fecha de cada venta. Los pagos usan
-- fn_total_venta para que los importes salgan del detalle, sin capturarlos a mano.
-- Los correos usan el dominio reservado example.com.
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
USE ventas_equipo5;

-- =============================================================================
-- 1. CATÁLOGOS
-- =============================================================================

INSERT INTO tipo_movimiento (tipo_movimiento_id, clave, descripcion, signo) VALUES
(1, 'ENTRADA',        'Entrada de mercancía (inventario inicial o compra)', 1),
(2, 'SALIDA_VENTA',   'Salida por venta',                                  -1),
(3, 'AJUSTE_ENTRADA', 'Ajuste a favor (sobrante en conteo físico)',         1),
(4, 'AJUSTE_SALIDA',  'Ajuste en contra (merma o faltante)',               -1),
(5, 'DEVOLUCION',     'Devolución al inventario por cancelación de venta',  1);

INSERT INTO metodo_pago (metodo_pago_id, nombre) VALUES
(1, 'EFECTIVO'),
(2, 'TARJETA DE DÉBITO'),
(3, 'TARJETA DE CRÉDITO'),
(4, 'TRANSFERENCIA');

INSERT INTO empleado (empleado_id, nombre, apellido, puesto) VALUES
(1, 'Laura',  'Martínez Solís', 'ADMIN'),
(2, 'Ana',    'Pérez Luna',     'VENDEDOR'),
(3, 'Luis',   'Gómez Arriaga',  'VENDEDOR'),
(4, 'Raúl',   'Soto Medina',    'ALMACENISTA'),
(5, 'Carmen', 'Ortiz Valdez',   'ALMACENISTA');

INSERT INTO categoria (categoria_id, nombre, descripcion) VALUES
(1, 'Herramienta manual',     'Martillos, desarmadores, pinzas y llaves'),
(2, 'Herramienta eléctrica',  'Taladros, esmeriladoras y sierras'),
(3, 'Plomería',               'Tubería, conexiones y llaves'),
(4, 'Material eléctrico',     'Cable, contactos, apagadores e iluminación'),
(5, 'Pinturas',               'Pinturas, esmaltes y accesorios para pintar'),
(6, 'Tornillería y fijación', 'Tornillos, taquetes y anclas'),
(7, 'Jardinería',             'Mangueras y herramienta de jardín'),
(8, 'Seguridad industrial',   'Equipo de protección personal');

-- Productos. existencia inicia en 0 (RN-19): se carga con movimientos ENTRADA.
-- JA-002 está descontinuado (activo = 0): conserva existencias pero no se vende (RN-05).
INSERT INTO producto (producto_id, sku, nombre, categoria_id, precio_venta, costo, stock_minimo, activo) VALUES
( 1, 'HM-001', 'Martillo de uña 16 oz',                   1,  150.00,   95.00,  5, 1),
( 2, 'HM-002', 'Desarmador plano 1/4"',                   1,   60.00,   32.00,  8, 1),
( 3, 'HM-003', 'Juego de llaves combinadas 12 piezas',    1,  549.00,  340.00,  3, 1),
( 4, 'HM-004', 'Pinza de electricista 8"',                1,  189.00,  110.00,  4, 1),
( 5, 'HE-001', 'Taladro percutor 1/2" 650 W',             2, 1299.00,  860.00,  2, 1),
( 6, 'HE-002', 'Esmeriladora angular 4 1/2"',             2,  999.00,  640.00,  2, 1),
( 7, 'HE-003', 'Rotomartillo SDS 800 W',                  2, 2899.00, 1950.00,  1, 1),
( 8, 'HE-004', 'Sierra caladora 500 W',                   2, 1149.00,  760.00,  2, 1),
( 9, 'PL-001', 'Llave de paso 1/2"',                      3,   95.00,   55.00, 10, 1),
(10, 'PL-002', 'Tubo PVC hidráulico 1/2" x 6 m',          3,   89.00,   52.00, 15, 1),
(11, 'PL-003', 'Cinta teflón 3/4"',                       3,   18.00,    7.00, 30, 1),
(12, 'PL-004', 'Llave mezcladora para lavabo',            3,  649.00,  410.00,  3, 1),
(13, 'ME-001', 'Cable THW calibre 12 (rollo 100 m)',      4, 1450.00, 1020.00,  3, 1),
(14, 'ME-002', 'Contacto dúplex polarizado',              4,   45.00,   22.00, 20, 1),
(15, 'ME-003', 'Apagador sencillo',                       4,   38.00,   18.00, 20, 1),
(16, 'ME-004', 'Foco LED 9 W luz blanca',                 4,   39.00,   19.00, 25, 1),
(17, 'PI-001', 'Pintura vinílica blanca 19 L',            5, 1250.00,  820.00,  4, 1),
(18, 'PI-002', 'Esmalte alquidálico negro 4 L',           5,  489.00,  300.00,  4, 1),
(19, 'PI-003', 'Brocha de cerda 4"',                      5,   69.00,   35.00, 10, 1),
(20, 'PI-004', 'Rodillo de felpa 9"',                     5,   95.00,   48.00,  8, 1),
(21, 'TF-001', 'Tornillo para tablaroca 1" (caja 100)',   6,   75.00,   38.00, 10, 1),
(22, 'TF-002', 'Taquete plástico 1/4" (bolsa 100)',       6,   49.00,   22.00, 10, 1),
(23, 'TF-003', 'Ancla expansiva 3/8"',                    6,   12.00,    5.00, 50, 1),
(24, 'JA-001', 'Manguera reforzada 1/2" x 15 m',          7,  299.00,  180.00,  3, 1),
(25, 'JA-002', 'Tijera para podar (descontinuada)',       7,  229.00,  130.00,  3, 0),
(26, 'JA-003', 'Pala cuadrada con mango de madera',       7,  259.00,  155.00,  3, 1),
(27, 'SI-001', 'Casco de seguridad',                      8,  149.00,   80.00,  6, 1),
(28, 'SI-002', 'Guantes de carnaza (par)',                8,   59.00,   28.00, 15, 1),
(29, 'SI-003', 'Lentes de seguridad',                     8,   45.00,   20.00, 12, 1),
(30, 'SI-004', 'Botas de seguridad con casquillo',        8,  899.00,  560.00,  2, 1);

INSERT INTO proveedor (proveedor_id, rfc, razon_social, telefono, email) VALUES
(1, 'DFC990312KJ4', 'Distribuidora Ferretera del Centro, S.A. de C.V.',        '442 210 4500', 'ventas@dfc.example.com'),
(2, 'HBA050620LM8', 'Hidrosistemas del Bajío, S.A. de C.V.',                   '477 318 2200', 'pedidos@hidrobajio.example.com'),
(3, 'EIN030915PQ2', 'Eléctrica Industrial del Norte, S.A. de C.V.',            '818 344 9010', 'contacto@ein.example.com'),
(4, 'RPA110405ST6', 'Recubrimientos y Pinturas Altavista, S.A. de C.V.',       '833 215 7788', 'ventas@altavista.example.com'),
(5, 'HPT070118UV1', 'Herramientas Profesionales Tolteca, S.A. de C.V.',        '551 204 3300', 'mayoreo@tolteca.example.com'),
(6, 'ESF140222WX9', 'Equipos de Seguridad Fénix, S.A. de C.V.',                '222 409 6161', 'ventas@fenix.example.com');

-- Ofertas producto–proveedor (N:M). Proveedor principal = costo vigente;
-- proveedor alterno = costo 4 % mayor. JA-002 (descontinuado) queda sin proveedor (0..N).
-- INSERT ... SELECT es seguro aquí: ningún trigger de esta tabla modifica producto.
INSERT INTO producto_proveedor (producto_id, proveedor_id, costo_compra, clave_proveedor, es_principal)
SELECT p.producto_id,
       CASE c.categoria_id
            WHEN 1 THEN 1  WHEN 2 THEN 5  WHEN 3 THEN 2  WHEN 4 THEN 3
            WHEN 5 THEN 4  WHEN 6 THEN 1  WHEN 7 THEN 1  WHEN 8 THEN 6
       END,
       p.costo,
       CONCAT('PR-', p.sku),
       1
  FROM producto p
  JOIN categoria c ON c.categoria_id = p.categoria_id
 WHERE p.producto_id <> 25;

INSERT INTO producto_proveedor (producto_id, proveedor_id, costo_compra, clave_proveedor, es_principal)
SELECT producto_id, 5, ROUND(costo * 1.04, 2), CONCAT('TOL-', sku), 0
  FROM producto WHERE producto_id IN (1, 3, 4)
UNION ALL
SELECT producto_id, 1, ROUND(costo * 1.04, 2), CONCAT('DFC-', sku), 0
  FROM producto WHERE producto_id IN (5, 6, 9, 11, 14, 16, 19, 20, 28);

INSERT INTO cliente (cliente_id, rfc, nombre, apellido, email, telefono, fecha_registro) VALUES
( 1, NULL,           'PÚBLICO EN GENERAL',                     NULL,               NULL,                                   NULL,           '2026-05-01 08:00:00'),
( 2, 'CRO010101AB2', 'Constructora Robles, S.A. de C.V.',      NULL,               'compras@robles.example.com',           '442 118 2030', '2026-05-10 10:00:00'),
( 3, 'IEM080315QW7', 'Instalaciones Eléctricas Mendoza, S.C.', NULL,               'contacto@iemendoza.example.com',       '442 305 6611', '2026-05-12 11:30:00'),
( 4, 'PAN120720RT5', 'Pinturas y Acabados del Norte, S.A.',    NULL,               'ventas@acabadosnorte.example.com',     '442 227 4580', '2026-05-15 09:15:00'),
( 5, 'LOGM900214HX3','María Fernanda',                         'López García',     'mf.lopez@example.com',                 '442 501 1122', '2026-05-20 12:00:00'),
( 6, NULL,           'José Antonio',                           'Ramírez Torres',   'ja.ramirez@example.com',               '442 502 3344', '2026-05-22 16:40:00'),
( 7, NULL,           'Guadalupe',                              'Hernández Ruiz',   'g.hernandez@example.com',              NULL,           '2026-05-25 10:10:00'),
( 8, 'SAVC850630JK1','Carlos Alberto',                         'Sánchez Vega',     'c.sanchez@example.com',                '442 503 5566', '2026-05-26 13:20:00'),
( 9, NULL,           'Patricia',                               'Morales Díaz',     'p.morales@example.com',                NULL,           '2026-05-27 17:05:00'),
(10, NULL,           'Jorge Luis',                             'Castillo Núñez',   NULL,                                   '442 504 7788', '2026-05-28 09:45:00'),
(11, NULL,           'Verónica',                               'Jiménez Ortega',   'v.jimenez@example.com',                NULL,           '2026-06-10 11:00:00'),
(12, NULL,           'Ricardo',                                'Flores Medina',    'r.flores@example.com',                 '442 505 9900', '2026-06-20 15:30:00'),
(13, NULL,           'Alejandra',                              'Cruz Romero',      'a.cruz@example.com',                   NULL,           '2026-07-01 10:00:00'),
(14, 'RESF780911LP4','Francisco Javier',                       'Reyes Silva',      'fj.reyes@example.com',                 '442 506 1212', '2026-07-15 12:40:00'),
(15, NULL,           'Sofía',                                  'Gutiérrez Mendoza','s.gutierrez@example.com',              NULL,           '2026-08-01 09:00:00'),
(16, NULL,           'Miguel Ángel',                           'Vargas Rojas',     'ma.vargas@example.com',                '442 507 3434', '2026-08-20 14:15:00'),
(17, NULL,           'Daniela',                                'Aguilar Herrera',  'd.aguilar@example.com',                NULL,           '2026-09-01 16:00:00'),
(18, NULL,           'Héctor',                                 'Domínguez Ríos',   'h.dominguez@example.com',              '442 508 5656', '2026-09-10 10:30:00'),
(19, NULL,           'Lucía',                                  'Navarro Campos',   'l.navarro@example.com',                NULL,           '2026-10-01 13:00:00'),
(20, NULL,           'Arturo',                                 'Peña Salazar',     'a.pena@example.com',                   '442 509 7878', '2026-10-20 11:45:00'),
(21, NULL,           'Elena',                                  'Ríos Fuentes',     'e.rios@example.com',                   NULL,           '2026-11-05 17:20:00');

-- =============================================================================
-- 2. INVENTARIO INICIAL (2026-05-25) — capturado por el almacenista Raúl Soto
--    Se usa INSERT ... VALUES (no INSERT ... SELECT FROM producto) para evitar
--    el error 1442: trg_movimiento_ai actualiza producto.
-- =============================================================================
INSERT INTO movimiento_inventario (producto_id, tipo_movimiento_id, cantidad, fecha, empleado_id, observacion) VALUES
( 1, 1,  40, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
( 2, 1,  60, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
( 3, 1,  12, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
( 4, 1,  25, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
( 5, 1,   6, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
( 6, 1,   8, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
( 7, 1,   3, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
( 8, 1,   6, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
( 9, 1,  30, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(10, 1,  80, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(11, 1, 200, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(12, 1,  10, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(13, 1,  20, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(14, 1, 120, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(15, 1, 120, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(16, 1,  80, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(17, 1,  25, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(18, 1,  15, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(19, 1,  60, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(20, 1,  40, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(21, 1,  80, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(22, 1,  80, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(23, 1, 400, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(24, 1,  15, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(25, 1,   8, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(26, 1,  12, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(27, 1,  30, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(28, 1,  40, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(29, 1,  50, '2026-05-25 08:00:00', 4, 'Inventario inicial'),
(30, 1,   6, '2026-05-25 08:00:00', 4, 'Inventario inicial');

-- =============================================================================
-- 3. VENTAS, PAGOS Y MOVIMIENTOS (2026-06-01 a 2026-11-20)
--    Leyenda de productos: ver sección 1. Vendedores: 2 = Ana Pérez, 3 = Luis Gómez.
--    Métodos de pago: 1 efectivo · 2 débito · 3 crédito · 4 transferencia.
-- =============================================================================

-- ----------------------------------- JUNIO -----------------------------------
-- V01 · Constructora Robles · transferencia total
CALL registrar_venta(2, 2, '2026-06-02 09:40:00', '[{"producto_id":1,"cantidad":3},{"producto_id":9,"cantidad":4},{"producto_id":10,"cantidad":10},{"producto_id":11,"cantidad":10}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-06-02 09:45:00', fn_total_venta(@v), 'TRF-260602-01');

-- V02 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-06-03 11:15:00', '[{"producto_id":2,"cantidad":2},{"producto_id":11,"cantidad":3}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-06-03 11:17:00', fn_total_venta(@v));

-- V03 · Inst. Eléctricas Mendoza · transferencia total
CALL registrar_venta(3, 2, '2026-06-05 16:20:00', '[{"producto_id":13,"cantidad":2},{"producto_id":14,"cantidad":20},{"producto_id":15,"cantidad":15},{"producto_id":16,"cantidad":10}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-06-05 16:30:00', fn_total_venta(@v), 'TRF-260605-01');

-- V04 · María Fernanda López · débito
CALL registrar_venta(5, 3, '2026-06-08 10:05:00', '[{"producto_id":17,"cantidad":2},{"producto_id":19,"cantidad":2},{"producto_id":20,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 2, '2026-06-08 10:08:00', fn_total_venta(@v));

-- V05 · Constructora Robles · transferencia total
CALL registrar_venta(2, 2, '2026-06-11 12:30:00', '[{"producto_id":5,"cantidad":1},{"producto_id":23,"cantidad":50},{"producto_id":21,"cantidad":5}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-06-11 12:40:00', fn_total_venta(@v), 'TRF-260611-01');

-- V06 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-06-15 17:45:00', '[{"producto_id":28,"cantidad":3},{"producto_id":29,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-06-15 17:47:00', fn_total_venta(@v));

-- V07 · Pinturas y Acabados del Norte · dos transferencias (50 % + 50 %)
CALL registrar_venta(4, 2, '2026-06-18 09:10:00', '[{"producto_id":17,"cantidad":4},{"producto_id":19,"cantidad":6},{"producto_id":20,"cantidad":4}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-06-18 09:20:00', ROUND(fn_total_venta(@v) * 0.5, 2), 'TRF-260618-01');
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-06-25 10:00:00', fn_total_venta(@v) - fn_pagado_venta(@v), 'TRF-260625-01');

-- V08 · José Antonio Ramírez · crédito
CALL registrar_venta(6, 3, '2026-06-22 13:00:00', '[{"producto_id":24,"cantidad":1},{"producto_id":26,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 3, '2026-06-22 13:04:00', fn_total_venta(@v));

-- V09 · Público en general · efectivo
CALL registrar_venta(1, 2, '2026-06-25 15:30:00', '[{"producto_id":16,"cantidad":6},{"producto_id":15,"cantidad":4}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-06-25 15:32:00', fn_total_venta(@v));

-- V10 · Guadalupe Hernández · efectivo
CALL registrar_venta(7, 3, '2026-06-29 10:50:00', '[{"producto_id":4,"cantidad":1},{"producto_id":2,"cantidad":3}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-06-29 10:52:00', fn_total_venta(@v));

-- ----------------------------------- JULIO -----------------------------------
-- V11 · Inst. Eléctricas Mendoza · transferencia total
CALL registrar_venta(3, 2, '2026-07-02 09:30:00', '[{"producto_id":13,"cantidad":2},{"producto_id":14,"cantidad":15},{"producto_id":16,"cantidad":8}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-07-02 09:40:00', fn_total_venta(@v), 'TRF-260702-01');

-- V12 · Carlos Alberto Sánchez · crédito
CALL registrar_venta(8, 3, '2026-07-04 12:10:00', '[{"producto_id":6,"cantidad":1},{"producto_id":28,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 3, '2026-07-04 12:14:00', fn_total_venta(@v));

-- V13 · Constructora Robles · anticipo 60 % y liquidación el 20 de julio
CALL registrar_venta(2, 2, '2026-07-07 16:00:00', '[{"producto_id":9,"cantidad":6},{"producto_id":10,"cantidad":20},{"producto_id":11,"cantidad":20},{"producto_id":12,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-07-07 16:10:00', ROUND(fn_total_venta(@v) * 0.6, 2), 'TRF-260707-01');
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-07-20 11:00:00', fn_total_venta(@v) - fn_pagado_venta(@v), 'TRF-260720-01');

-- V14 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-07-09 11:20:00', '[{"producto_id":22,"cantidad":3},{"producto_id":21,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-07-09 11:22:00', fn_total_venta(@v));

-- V15 · Patricia Morales · débito
CALL registrar_venta(9, 2, '2026-07-13 10:00:00', '[{"producto_id":17,"cantidad":1},{"producto_id":20,"cantidad":2},{"producto_id":19,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 2, '2026-07-13 10:03:00', fn_total_venta(@v));

-- V16 · Pinturas y Acabados del Norte · transferencia total
CALL registrar_venta(4, 3, '2026-07-16 17:30:00', '[{"producto_id":17,"cantidad":5},{"producto_id":20,"cantidad":5}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-07-16 17:40:00', fn_total_venta(@v), 'TRF-260716-01');

-- V17 · Jorge Luis Castillo · efectivo
CALL registrar_venta(10, 2, '2026-07-20 13:45:00', '[{"producto_id":1,"cantidad":1},{"producto_id":2,"cantidad":1},{"producto_id":4,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-07-20 13:47:00', fn_total_venta(@v));

-- V18 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-07-23 09:15:00', '[{"producto_id":16,"cantidad":4},{"producto_id":14,"cantidad":6}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-07-23 09:17:00', fn_total_venta(@v));

-- V19 · Verónica Jiménez · crédito
CALL registrar_venta(11, 2, '2026-07-27 15:00:00', '[{"producto_id":5,"cantidad":1},{"producto_id":23,"cantidad":20}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 3, '2026-07-27 15:05:00', fn_total_venta(@v));

-- V20 · Constructora Robles · transferencia total
CALL registrar_venta(2, 2, '2026-07-30 12:00:00', '[{"producto_id":3,"cantidad":2},{"producto_id":27,"cantidad":6},{"producto_id":28,"cantidad":6}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-07-30 12:10:00', fn_total_venta(@v), 'TRF-260730-01');

-- Ajuste 2026-07-31: merma de desarmadores dañados en anaquel
INSERT INTO movimiento_inventario (producto_id, tipo_movimiento_id, cantidad, fecha, empleado_id, observacion)
VALUES (2, 4, 2, '2026-07-31 18:00:00', 4, 'Merma: piezas dañadas en anaquel');

-- Cambio de precio 2026-08-01: HM-001 pasa de $150 a $165. Las ventas anteriores
-- conservan $150 en su detalle (RN-09); las siguientes se registran a $165.
UPDATE producto SET precio_venta = 165.00 WHERE sku = 'HM-001';

-- ----------------------------------- AGOSTO ----------------------------------
-- V21 · Ricardo Flores · efectivo (primer martillo a $165)
CALL registrar_venta(12, 3, '2026-08-03 10:30:00', '[{"producto_id":1,"cantidad":2},{"producto_id":19,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-08-03 10:32:00', fn_total_venta(@v));

-- V22 · Inst. Eléctricas Mendoza · pagos parciales 50 % + 30 % → queda PENDIENTE con saldo
CALL registrar_venta(3, 2, '2026-08-05 11:40:00', '[{"producto_id":13,"cantidad":3},{"producto_id":15,"cantidad":20},{"producto_id":16,"cantidad":10}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-08-05 11:50:00', ROUND(fn_total_venta(@v) * 0.5, 2), 'TRF-260805-01');
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-08-20 10:00:00', ROUND(fn_total_venta(@v) * 0.3, 2), 'TRF-260820-01');

-- V23 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-08-08 16:10:00', '[{"producto_id":9,"cantidad":2},{"producto_id":11,"cantidad":5}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-08-08 16:12:00', fn_total_venta(@v));

-- V24 · Alejandra Cruz · débito
CALL registrar_venta(13, 2, '2026-08-11 09:50:00', '[{"producto_id":24,"cantidad":1},{"producto_id":26,"cantidad":1},{"producto_id":28,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 2, '2026-08-11 09:53:00', fn_total_venta(@v));

-- Reabastecimiento 2026-08-14 (compra a proveedores) — almacenista Carmen Ortiz
INSERT INTO movimiento_inventario (producto_id, tipo_movimiento_id, cantidad, fecha, empleado_id, observacion) VALUES
(10, 1, 40, '2026-08-14 08:00:00', 5, 'Compra a Hidrosistemas del Bajío'),
(14, 1, 60, '2026-08-14 08:00:00', 5, 'Compra a Eléctrica Industrial del Norte'),
(17, 1, 15, '2026-08-14 08:00:00', 5, 'Compra a Recubrimientos y Pinturas Altavista');

-- V25 · Pinturas y Acabados del Norte · transferencia total
CALL registrar_venta(4, 3, '2026-08-14 14:20:00', '[{"producto_id":17,"cantidad":6},{"producto_id":19,"cantidad":8},{"producto_id":20,"cantidad":6}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-08-14 14:30:00', fn_total_venta(@v), 'TRF-260814-01');

-- V26 · Constructora Robles · transferencia total
CALL registrar_venta(2, 2, '2026-08-18 12:35:00', '[{"producto_id":5,"cantidad":1},{"producto_id":8,"cantidad":1},{"producto_id":23,"cantidad":60}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-08-18 12:45:00', fn_total_venta(@v), 'TRF-260818-01');

-- V27 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-08-21 17:05:00', '[{"producto_id":29,"cantidad":3},{"producto_id":27,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-08-21 17:07:00', fn_total_venta(@v));

-- V28 · Francisco Javier Reyes · crédito
CALL registrar_venta(14, 2, '2026-08-24 10:15:00', '[{"producto_id":12,"cantidad":1},{"producto_id":9,"cantidad":2},{"producto_id":11,"cantidad":3}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 3, '2026-08-24 10:18:00', fn_total_venta(@v));

-- V29 · Público en general · CANCELADA (el cliente desistió antes de pagar)
CALL registrar_venta(1, 3, '2026-08-27 13:30:00', '[{"producto_id":16,"cantidad":3}]', @v);
CALL cancelar_venta(@v, 3, '2026-08-27 13:50:00');

-- V30 · Sofía Gutiérrez · efectivo
CALL registrar_venta(15, 2, '2026-08-29 11:00:00', '[{"producto_id":2,"cantidad":2},{"producto_id":21,"cantidad":3},{"producto_id":22,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-08-29 11:02:00', fn_total_venta(@v));

-- -------------------------------- SEPTIEMBRE ---------------------------------
-- V31 · Constructora Robles · anticipo 50 % → queda PENDIENTE con saldo
CALL registrar_venta(2, 2, '2026-09-01 09:20:00', '[{"producto_id":10,"cantidad":25},{"producto_id":9,"cantidad":5},{"producto_id":11,"cantidad":30},{"producto_id":12,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-09-01 09:30:00', ROUND(fn_total_venta(@v) * 0.5, 2), 'TRF-260901-01');

-- V32 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-09-03 15:40:00', '[{"producto_id":28,"cantidad":4},{"producto_id":29,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-09-03 15:42:00', fn_total_venta(@v));

-- V33 · Inst. Eléctricas Mendoza · transferencia total
CALL registrar_venta(3, 2, '2026-09-06 10:10:00', '[{"producto_id":13,"cantidad":2},{"producto_id":14,"cantidad":20},{"producto_id":15,"cantidad":15},{"producto_id":16,"cantidad":8}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-09-06 10:20:00', fn_total_venta(@v), 'TRF-260906-01');

-- V34 · Miguel Ángel Vargas · crédito
CALL registrar_venta(16, 3, '2026-09-09 12:45:00', '[{"producto_id":6,"cantidad":1},{"producto_id":4,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 3, '2026-09-09 12:49:00', fn_total_venta(@v));

-- V35 · Pinturas y Acabados del Norte · anticipo 40 % → queda PENDIENTE con saldo
CALL registrar_venta(4, 2, '2026-09-12 17:20:00', '[{"producto_id":17,"cantidad":4},{"producto_id":20,"cantidad":3},{"producto_id":19,"cantidad":4}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-09-12 17:30:00', ROUND(fn_total_venta(@v) * 0.4, 2), 'TRF-260912-01');

-- V36 · Público en general · débito
CALL registrar_venta(1, 3, '2026-09-15 11:30:00', '[{"producto_id":1,"cantidad":1},{"producto_id":3,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 2, '2026-09-15 11:33:00', fn_total_venta(@v));

-- V37 · Daniela Aguilar · efectivo
CALL registrar_venta(17, 2, '2026-09-18 09:55:00', '[{"producto_id":24,"cantidad":2},{"producto_id":26,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-09-18 09:57:00', fn_total_venta(@v));

-- V38 · Constructora Robles · transferencia total
CALL registrar_venta(2, 2, '2026-09-22 14:10:00', '[{"producto_id":27,"cantidad":8},{"producto_id":28,"cantidad":8},{"producto_id":29,"cantidad":6}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-09-22 14:20:00', fn_total_venta(@v), 'TRF-260922-01');

-- V39 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-09-25 16:35:00', '[{"producto_id":16,"cantidad":3},{"producto_id":15,"cantidad":3}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-09-25 16:37:00', fn_total_venta(@v));

-- V40 · Héctor Domínguez · crédito
CALL registrar_venta(18, 2, '2026-09-29 10:40:00', '[{"producto_id":8,"cantidad":1},{"producto_id":23,"cantidad":30}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 3, '2026-09-29 10:44:00', fn_total_venta(@v));

-- Ajuste 2026-09-30: sobrante de cinta teflón detectado en conteo físico
INSERT INTO movimiento_inventario (producto_id, tipo_movimiento_id, cantidad, fecha, empleado_id, observacion)
VALUES (11, 3, 5, '2026-09-30 18:00:00', 5, 'Conteo físico: sobrante');

-- --------------------------------- OCTUBRE -----------------------------------
-- V41 · Inst. Eléctricas Mendoza · transferencia total
CALL registrar_venta(3, 2, '2026-10-02 09:35:00', '[{"producto_id":5,"cantidad":1},{"producto_id":13,"cantidad":2},{"producto_id":14,"cantidad":10}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-10-02 09:45:00', fn_total_venta(@v), 'TRF-261002-01');

-- V42 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-10-06 12:20:00', '[{"producto_id":9,"cantidad":2},{"producto_id":11,"cantidad":4},{"producto_id":10,"cantidad":4}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-10-06 12:22:00', fn_total_venta(@v));

-- V43 · Pinturas y Acabados del Norte · transferencia total
CALL registrar_venta(4, 2, '2026-10-09 15:15:00', '[{"producto_id":17,"cantidad":5},{"producto_id":19,"cantidad":5},{"producto_id":20,"cantidad":4}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-10-09 15:25:00', fn_total_venta(@v), 'TRF-261009-01');

-- V44 · Lucía Navarro · débito
CALL registrar_venta(19, 3, '2026-10-13 10:25:00', '[{"producto_id":1,"cantidad":2},{"producto_id":2,"cantidad":2},{"producto_id":4,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 2, '2026-10-13 10:28:00', fn_total_venta(@v));

-- V45 · Constructora Robles · dos transferencias (50 % + 50 %)
CALL registrar_venta(2, 2, '2026-10-16 16:50:00', '[{"producto_id":3,"cantidad":2},{"producto_id":21,"cantidad":10},{"producto_id":22,"cantidad":10},{"producto_id":23,"cantidad":40}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-10-16 17:00:00', ROUND(fn_total_venta(@v) * 0.5, 2), 'TRF-261016-01');
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-10-30 10:00:00', fn_total_venta(@v) - fn_pagado_venta(@v), 'TRF-261030-01');

-- V46 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-10-20 11:05:00', '[{"producto_id":28,"cantidad":3},{"producto_id":16,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-10-20 11:07:00', fn_total_venta(@v));

-- V47 · María Fernanda López · CANCELADA al día siguiente (pedido duplicado)
CALL registrar_venta(5, 2, '2026-10-23 13:40:00', '[{"producto_id":17,"cantidad":1},{"producto_id":19,"cantidad":2}]', @v);
CALL cancelar_venta(@v, 2, '2026-10-24 09:00:00');

-- V48 · José Antonio Ramírez · crédito
CALL registrar_venta(6, 3, '2026-10-27 09:45:00', '[{"producto_id":24,"cantidad":1},{"producto_id":28,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 3, '2026-10-27 09:49:00', fn_total_venta(@v));

-- V49 · Inst. Eléctricas Mendoza · anticipo 50 % → queda PENDIENTE con saldo
CALL registrar_venta(3, 2, '2026-10-29 14:55:00', '[{"producto_id":15,"cantidad":15},{"producto_id":14,"cantidad":15},{"producto_id":16,"cantidad":5}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-10-29 15:05:00', ROUND(fn_total_venta(@v) * 0.5, 2), 'TRF-261029-01');

-- V50 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-10-31 17:15:00', '[{"producto_id":2,"cantidad":1},{"producto_id":11,"cantidad":2}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-10-31 17:17:00', fn_total_venta(@v));

-- Ajuste 2026-10-31: faltante de lentes en conteo físico
INSERT INTO movimiento_inventario (producto_id, tipo_movimiento_id, cantidad, fecha, empleado_id, observacion)
VALUES (29, 4, 1, '2026-10-31 18:30:00', 4, 'Conteo físico: faltante');

-- -------------------------------- NOVIEMBRE ----------------------------------
-- V51 · Constructora Robles · transferencia total
CALL registrar_venta(2, 2, '2026-11-03 10:20:00', '[{"producto_id":1,"cantidad":3},{"producto_id":9,"cantidad":3},{"producto_id":12,"cantidad":1},{"producto_id":10,"cantidad":10}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-11-03 10:30:00', fn_total_venta(@v), 'TRF-261103-01');

-- V52 · Guadalupe Hernández · efectivo
CALL registrar_venta(7, 3, '2026-11-05 12:50:00', '[{"producto_id":26,"cantidad":1},{"producto_id":24,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-11-05 12:52:00', fn_total_venta(@v));

-- V53 · Pinturas y Acabados del Norte · transferencia total
CALL registrar_venta(4, 2, '2026-11-07 15:25:00', '[{"producto_id":17,"cantidad":4},{"producto_id":20,"cantidad":3}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto, referencia) VALUES (@v, 4, '2026-11-07 15:35:00', fn_total_venta(@v), 'TRF-261107-01');

-- V54 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-11-10 09:40:00', '[{"producto_id":28,"cantidad":3},{"producto_id":29,"cantidad":2},{"producto_id":27,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-11-10 09:42:00', fn_total_venta(@v));

-- V55 · Inst. Eléctricas Mendoza · PENDIENTE sin pagos (crédito a 30 días)
CALL registrar_venta(3, 2, '2026-11-12 11:55:00', '[{"producto_id":5,"cantidad":1},{"producto_id":13,"cantidad":1},{"producto_id":16,"cantidad":4}]', @v);

-- V56 · Carlos Alberto Sánchez · crédito
CALL registrar_venta(8, 3, '2026-11-14 16:05:00', '[{"producto_id":3,"cantidad":1},{"producto_id":4,"cantidad":1}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 3, '2026-11-14 16:09:00', fn_total_venta(@v));

-- V57 · Constructora Robles · PENDIENTE sin pagos (crédito a 30 días)
CALL registrar_venta(2, 2, '2026-11-17 10:35:00', '[{"producto_id":9,"cantidad":2},{"producto_id":28,"cantidad":4},{"producto_id":23,"cantidad":30}]', @v);

-- V58 · Público en general · CANCELADA (error de captura)
CALL registrar_venta(1, 3, '2026-11-18 13:20:00', '[{"producto_id":16,"cantidad":2},{"producto_id":15,"cantidad":2}]', @v);
CALL cancelar_venta(@v, 3, '2026-11-18 13:30:00');

-- V59 · Patricia Morales · efectivo
CALL registrar_venta(9, 2, '2026-11-19 17:40:00', '[{"producto_id":21,"cantidad":4},{"producto_id":22,"cantidad":4}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-11-19 17:42:00', fn_total_venta(@v));

-- V60 · Público en general · efectivo
CALL registrar_venta(1, 3, '2026-11-20 12:15:00', '[{"producto_id":2,"cantidad":2},{"producto_id":11,"cantidad":3}]', @v);
INSERT INTO pago (venta_id, metodo_pago_id, fecha, monto) VALUES (@v, 1, '2026-11-20 12:17:00', fn_total_venta(@v));

-- =============================================================================
-- 4. VERIFICACIÓN DE LA CARGA
-- =============================================================================
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'producto',              COUNT(*) FROM producto
UNION ALL SELECT 'proveedor',             COUNT(*) FROM proveedor
UNION ALL SELECT 'producto_proveedor',    COUNT(*) FROM producto_proveedor
UNION ALL SELECT 'cliente',               COUNT(*) FROM cliente
UNION ALL SELECT 'empleado',              COUNT(*) FROM empleado
UNION ALL SELECT 'venta',                 COUNT(*) FROM venta
UNION ALL SELECT 'detalle_venta',         COUNT(*) FROM detalle_venta
UNION ALL SELECT 'pago',                  COUNT(*) FROM pago
UNION ALL SELECT 'movimiento_inventario', COUNT(*) FROM movimiento_inventario;

SELECT estado, COUNT(*) AS ventas FROM venta GROUP BY estado ORDER BY estado;

-- Debe devolver 0 filas: existencia almacenada = Σ movimientos (RN-19)
SELECT * FROM v_conciliacion_inventario WHERE diferencia <> 0;

-- Fin de 02_dml.sql
