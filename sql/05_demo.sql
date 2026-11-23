-- =============================================================================
-- Proyecto integrador · Equipo 5 · Sistema de ventas e inventarios
-- 05_demo.sql — Guion de demostración funcional.
--
-- Requisito: base recién cargada con 01_ddl.sql y 02_dml.sql (03 y 04 opcionales;
--            NO usar 04b: el volumen sintético distorsiona los reportes).
--            Volver a ejecutar requiere recargar 01 y 02 (los SKU de la demo son únicos).
-- Ejecución completa:
--     mysql -u root --default-character-set=utf8mb4 -t < sql/05_demo.sql
-- En vivo (Workbench / phpMyAdmin / consola): ejecutar paso por paso.
--
-- Pasos (criterios de demostración del escenario)
--   1. Registrar catálogo y proveedor
--   2. Insertar inventario inicial
--   3. Realizar una venta con varios productos
--   4. Registrar sus pagos (parcial y liquidación)
--   5. Verificar detalle, movimientos generados, conciliación y reporte
--   6. Cancelar una venta y ver la devolución al inventario
--   7. Intentar violar reglas y mostrar que fallan
--   8. Ejecutar una consulta de cada nivel de dificultad
--
-- Las fechas de esta demo son NOW(): la venta queda con la fecha del día en que se presenta.
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ventas_equipo5;

-- Auxiliar de la demo: ejecuta una sentencia y muestra si el motor la rechazó.
-- Permite correr el guion completo sin que el primer error lo detenga.
-- En vivo se puede ejecutar directamente la sentencia entre comillas para ver el error "crudo".
DROP PROCEDURE IF EXISTS demo_intentar;
DELIMITER $$
CREATE PROCEDURE demo_intentar(IN p_regla VARCHAR(80), IN p_sql TEXT)
BEGIN
    DECLARE v_code INT  DEFAULT NULL;
    DECLARE v_msg  TEXT DEFAULT NULL;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
            GET DIAGNOSTICS CONDITION 1 v_code = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
        SET @demo_sql = p_sql;
        PREPARE s FROM @demo_sql;
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END;
    SELECT p_regla                                               AS intento,
           IF(v_code IS NULL, 'ACEPTADO (revisar)', 'RECHAZADO') AS resultado,
           v_code                                                AS error,
           v_msg                                                 AS mensaje;
END$$
DELIMITER ;

-- =============================================================================
-- PASO 1 · Registrar catálogo y proveedor
-- =============================================================================
SELECT '1. Catálogo y proveedor nuevos' AS paso;

INSERT INTO categoria (nombre, descripcion)
VALUES ('Adhesivos y selladores', 'Pegamentos, silicones y espumas');
SET @cat = LAST_INSERT_ID();

INSERT INTO producto (sku, nombre, categoria_id, precio_venta, costo, stock_minimo) VALUES
('AS-001', 'Silicón transparente 280 ml',   @cat,  89.00, 48.00, 10),
('AS-002', 'Pegamento de contacto 1 L',     @cat, 199.00, 115.00, 5),
('AS-003', 'Espuma de poliuretano 750 ml',  @cat, 169.00, 98.00, 5);

SET @p1 = (SELECT producto_id FROM producto WHERE sku = 'AS-001');
SET @p2 = (SELECT producto_id FROM producto WHERE sku = 'AS-002');
SET @p3 = (SELECT producto_id FROM producto WHERE sku = 'AS-003');

INSERT INTO proveedor (rfc, razon_social, telefono, email)
VALUES ('ADH160910YZ3', 'Adhesivos Industriales del Golfo, S.A. de C.V.', '229 310 4545', 'ventas@adhgolfo.example.com');
SET @prov = LAST_INSERT_ID();

INSERT INTO producto_proveedor (producto_id, proveedor_id, costo_compra, clave_proveedor, es_principal) VALUES
(@p1, @prov,  48.00, 'AIG-SIL280', 1),
(@p2, @prov, 115.00, 'AIG-PC1L',   1),
(@p3, @prov,  98.00, 'AIG-ESP750', 1);

-- Los productos nacen con existencia 0 (RN-19)
SELECT p.sku, p.nombre, c.nombre AS categoria, p.precio_venta, p.costo, p.existencia,
       pr.razon_social AS proveedor_principal
  FROM producto p
  JOIN categoria c           ON c.categoria_id = p.categoria_id
  JOIN producto_proveedor pp ON pp.producto_id = p.producto_id AND pp.es_principal = 1
  JOIN proveedor pr          ON pr.proveedor_id = pp.proveedor_id
 WHERE p.categoria_id = @cat;

-- =============================================================================
-- PASO 2 · Inventario inicial (movimientos ENTRADA, capturados por el almacenista)
-- =============================================================================
SELECT '2. Inventario inicial' AS paso;

INSERT INTO movimiento_inventario (producto_id, tipo_movimiento_id, cantidad, empleado_id, observacion) VALUES
(@p1, 1, 40, 4, 'Demo: inventario inicial'),
(@p2, 1, 12, 4, 'Demo: inventario inicial'),
(@p3, 1, 15, 4, 'Demo: inventario inicial');

-- El trigger actualizó la existencia a partir del movimiento
SELECT sku, nombre, existencia, stock_minimo, bajo_umbral
  FROM v_existencias WHERE producto_id IN (@p1, @p2, @p3);

-- =============================================================================
-- PASO 3 · Venta con varios productos (transacción en registrar_venta)
-- =============================================================================
SELECT '3. Venta con varios productos' AS paso;

-- Cliente: Constructora Robles (2) · Vendedora: Ana Pérez (2) · Fecha: ahora
CALL registrar_venta(2, 2, NULL,
     CONCAT('[{"producto_id":', @p1, ',"cantidad":12},',
             '{"producto_id":', @p2, ',"cantidad":8},',
             '{"producto_id":', @p3, ',"cantidad":4},',
             '{"producto_id":1,"cantidad":2}]'),
     @venta);

SELECT @venta AS venta_registrada;

-- Detalle: precio y costo copiados del catálogo en este momento (RN-09)
SELECT d.venta_id, p.sku, p.nombre, d.cantidad, d.precio_unitario, d.costo_unitario,
       d.cantidad * d.precio_unitario AS subtotal
  FROM detalle_venta d
  JOIN producto p ON p.producto_id = d.producto_id
 WHERE d.venta_id = @venta;

-- =============================================================================
-- PASO 4 · Pagos: anticipo del 50 % y liquidación
-- =============================================================================
SELECT '4. Pagos' AS paso;

INSERT INTO pago (venta_id, metodo_pago_id, monto, referencia)
VALUES (@venta, 4, ROUND(fn_total_venta(@venta) * 0.5, 2), 'DEMO-ANTICIPO');

SELECT venta_id, estado, total, pagado, saldo FROM v_venta_saldos WHERE venta_id = @venta;  -- PENDIENTE

INSERT INTO pago (venta_id, metodo_pago_id, monto, referencia)
VALUES (@venta, 1, fn_total_venta(@venta) - fn_pagado_venta(@venta), NULL);

SELECT venta_id, estado, total, pagado, saldo FROM v_venta_saldos WHERE venta_id = @venta;  -- PAGADA (automático)

-- =============================================================================
-- PASO 5 · Verificar detalle, movimientos generados, conciliación y reporte
-- =============================================================================
SELECT '5. Verificaciones' AS paso;

-- 5a · Movimientos SALIDA_VENTA creados por el trigger, con la fecha de la venta y su venta_id
SELECT m.movimiento_id, m.fecha, t.clave AS tipo, p.sku, m.cantidad, m.venta_id, m.observacion
  FROM movimiento_inventario m
  JOIN tipo_movimiento t ON t.tipo_movimiento_id = m.tipo_movimiento_id
  JOIN producto        p ON p.producto_id        = m.producto_id
 WHERE m.venta_id = @venta;

-- 5b · Existencias después de la venta: AS-001 40→28, AS-002 12→4 (queda bajo su mínimo de 5), AS-003 15→11
SELECT sku, nombre, existencia, stock_minimo, bajo_umbral
  FROM v_existencias WHERE producto_id IN (@p1, @p2, @p3);

-- 5c · Precio histórico: subir el precio del catálogo NO altera la venta registrada (RN-09)
UPDATE producto SET precio_venta = 99.00 WHERE producto_id = @p1;
SELECT p.sku, p.precio_venta AS precio_catalogo_hoy, d.precio_unitario AS precio_en_la_venta
  FROM detalle_venta d JOIN producto p ON p.producto_id = d.producto_id
 WHERE d.venta_id = @venta AND d.producto_id = @p1;

-- 5d · Conciliación: existencia almacenada = Σ movimientos para TODOS los productos (RN-19)
SELECT COUNT(*) AS productos, SUM(diferencia <> 0) AS con_diferencia
  FROM v_conciliacion_inventario;

-- 5e · Reporte: la nueva categoría ya aparece en ventas y margen (consulta 10)
SELECT c.nombre AS categoria,
       SUM(d.cantidad * d.precio_unitario)                       AS ingreso,
       SUM(d.cantidad * (d.precio_unitario - d.costo_unitario))  AS margen
  FROM categoria c
  JOIN producto      p ON p.categoria_id = c.categoria_id
  JOIN detalle_venta d ON d.producto_id  = p.producto_id
  JOIN venta         v ON v.venta_id     = d.venta_id
 WHERE v.estado <> 'CANCELADA' AND c.categoria_id = @cat
 GROUP BY c.categoria_id, c.nombre;

-- =============================================================================
-- PASO 6 · Cancelación: el inventario regresa con movimientos DEVOLUCION
-- =============================================================================
SELECT '6. Cancelación' AS paso;

CALL registrar_venta(1, 3, NULL, CONCAT('[{"producto_id":', @p3, ',"cantidad":5}]'), @venta_c);
SELECT sku, existencia FROM producto WHERE producto_id = @p3;          -- 11 - 5 = 6

CALL cancelar_venta(@venta_c, 3, NULL);
SELECT venta_id, estado FROM venta WHERE venta_id = @venta_c;          -- CANCELADA
SELECT sku, existencia FROM producto WHERE producto_id = @p3;          -- regresa a 11

-- Historial completo de AS-003 con saldo acumulado (consulta 11)
SELECT m.fecha, t.clave AS tipo, t.signo * m.cantidad AS efecto,
       SUM(t.signo * m.cantidad) OVER (ORDER BY m.fecha, m.movimiento_id) AS saldo,
       m.venta_id, m.observacion
  FROM movimiento_inventario m
  JOIN tipo_movimiento t ON t.tipo_movimiento_id = m.tipo_movimiento_id
 WHERE m.producto_id = @p3
 ORDER BY m.fecha, m.movimiento_id;

-- =============================================================================
-- PASO 7 · Intentos de violar reglas: todos deben aparecer como RECHAZADO
-- =============================================================================
SELECT '7. Violaciones de reglas' AS paso;

-- Stock negativo (RN-16): AS-002 tiene 4 piezas
CALL demo_intentar('RN-16 vender más de lo que hay en existencia',
     CONCAT('CALL registrar_venta(2, 2, NULL, ''[{"producto_id":', @p2, ',"cantidad":50}]'', @x)'));

-- FK inexistente: cliente 999 no existe
CALL demo_intentar('FK venta a un cliente inexistente',
     CONCAT('CALL registrar_venta(999, 2, NULL, ''[{"producto_id":', @p1, ',"cantidad":1}]'', @x)'));

-- Pago excedente (RN-13): la venta 31 tiene saldo de $2,269.00
CALL demo_intentar('RN-13 pago mayor que el saldo pendiente',
     'INSERT INTO pago (venta_id, metodo_pago_id, monto) VALUES (31, 1, 5000)');

-- Pago a una venta cancelada (RN-13)
CALL demo_intentar('RN-13 pago a una venta cancelada',
     CONCAT('INSERT INTO pago (venta_id, metodo_pago_id, monto) VALUES (', @venta_c, ', 1, 10)'));

-- Venta sin renglones (RN-07)
CALL demo_intentar('RN-07 venta sin productos',
     'CALL registrar_venta(2, 2, NULL, ''[]'', @x)');

-- Historial inmutable (RN-17)
CALL demo_intentar('RN-17 borrar un movimiento de inventario',
     'DELETE FROM movimiento_inventario WHERE movimiento_id = 1');

-- Existencia solo cambia con movimientos (RN-19)
CALL demo_intentar('RN-19 editar la existencia directamente',
     CONCAT('UPDATE producto SET existencia = 500 WHERE producto_id = ', @p1));

-- Borrado restringido: producto con ventas (FK RESTRICT)
CALL demo_intentar('RESTRICT borrar un producto que ya se vendió',
     CONCAT('DELETE FROM producto WHERE producto_id = ', @p1));

-- Cancelar una venta pagada (RN-12)
CALL demo_intentar('RN-12 cancelar una venta ya PAGADA',
     CONCAT('CALL cancelar_venta(', @venta, ', 2, NULL)'));

-- Dominio (CHECK): precio negativo (RN-03)
CALL demo_intentar('RN-03 producto con precio negativo',
     CONCAT('INSERT INTO producto (sku, nombre, categoria_id, precio_venta, costo) VALUES (''AS-999'', ''X'', ', @cat, ', -10, 1)'));

-- Ninguno de los intentos dejó rastro: la conciliación sigue sin diferencias
SELECT SUM(diferencia <> 0) AS productos_con_diferencia FROM v_conciliacion_inventario;

-- =============================================================================
-- PASO 8 · Una consulta de cada nivel
-- =============================================================================
SELECT '8. Consultas por nivel' AS paso;

-- BÁSICO · Consulta 4: productos debajo del umbral (ahora incluye AS-002)
SELECT p.sku, p.nombre, p.existencia, p.stock_minimo, p.stock_minimo - p.existencia AS faltante
  FROM producto p
 WHERE p.activo = 1 AND p.existencia < p.stock_minimo
 ORDER BY faltante DESC;

-- INTERMEDIO · Consulta 7: clientes con gasto mayor a $10,000 (HAVING)
SELECT CONCAT_WS(' ', c.nombre, c.apellido) AS cliente,
       COUNT(DISTINCT v.venta_id)          AS ventas,
       SUM(d.cantidad * d.precio_unitario) AS gasto_total
  FROM cliente c
  JOIN venta         v ON v.cliente_id = c.cliente_id
  JOIN detalle_venta d ON d.venta_id   = v.venta_id
 WHERE v.estado <> 'CANCELADA' AND c.cliente_id <> 1
 GROUP BY c.cliente_id, c.nombre, c.apellido
HAVING SUM(d.cantidad * d.precio_unitario) > 10000
 ORDER BY gasto_total DESC;

-- AVANZADO · Consulta 8: productos sin ventas (LEFT JOIN)
SELECT p.sku, p.nombre, p.existencia, p.activo
  FROM producto p
  LEFT JOIN (detalle_venta d
             JOIN venta v ON v.venta_id = d.venta_id AND v.estado <> 'CANCELADA')
         ON d.producto_id = p.producto_id
 WHERE d.producto_id IS NULL
 ORDER BY p.nombre;

DROP PROCEDURE demo_intentar;

-- Fin de 05_demo.sql
