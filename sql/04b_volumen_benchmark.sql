-- =============================================================================
-- Proyecto integrador · Equipo 5 · Sistema de ventas e inventarios
-- 04b_volumen_benchmark.sql — Volumen sintético OPCIONAL para evidenciar índices.
--
-- Por qué existe: con 30 productos y 60 ventas el optimizador prefiere leer la
-- tabla completa aunque exista un índice (es más barato), y el EXPLAIN "antes"
-- y "después" sale casi igual. Este script agrega volumen para que el efecto de
-- cada índice sea visible.
--
-- Orden:     01_ddl.sql → 02_dml.sql → 04b_volumen_benchmark.sql → 04_indices.sql
-- Agrega:    3,000 productos · 3,000 entradas · 20,000 ventas · 40,000 renglones
--            · 40,000 salidas de inventario (generadas por los triggers).
-- Duración:  de segundos a pocos minutos (cada renglón dispara la cadena de triggers).
-- Después:   para volver a los datos limpios, ejecutar de nuevo 01_ddl.sql y 02_dml.sql.
--
-- Respeta todas las reglas: las ventas pasan por los triggers (stock, fechas,
-- movimientos). Ningún INSERT ... SELECT lee la tabla producto (evita el error 1442).
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
USE ventas_equipo5;

-- Secuencia 0..99999 con productos cartesianos de dígitos (portable, sin CTE en INSERT).
DROP TABLE IF EXISTS bm_digito;
DROP TABLE IF EXISTS bm_seq;
CREATE TABLE bm_digito (d TINYINT UNSIGNED PRIMARY KEY);
INSERT INTO bm_digito VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);
CREATE TABLE bm_seq (n INT UNSIGNED PRIMARY KEY);
INSERT INTO bm_seq (n)
SELECT a.d + 10 * b.d + 100 * c.d + 1000 * e.d + 10000 * f.d
  FROM bm_digito a, bm_digito b, bm_digito c, bm_digito e, bm_digito f;

-- 1. 3,000 productos (producto_id 31..3030). Nombres con 20 prefijos distintos.
INSERT INTO producto (producto_id, sku, nombre, categoria_id, precio_venta, costo, stock_minimo)
SELECT 30 + n,
       CONCAT('BM-', LPAD(n, 5, '0')),
       CONCAT(ELT(1 + (n % 20),
                  'Abrazadera', 'Broca', 'Cable', 'Candado', 'Cinta', 'Clavo', 'Codo',
                  'Disco', 'Extensión', 'Guante', 'Lija', 'Llave', 'Manguera', 'Nivel',
                  'Pegamento', 'Pintura', 'Regadera', 'Sellador', 'Tornillo', 'Válvula'),
              ' modelo ', LPAD(n, 5, '0')),
       1 + (n % 8),
       20 + (n % 500),
       ROUND((20 + (n % 500)) * 0.6, 2),
       5
  FROM bm_seq
 WHERE n BETWEEN 1 AND 3000;

-- 2. Entrada inicial de 1,000 piezas por producto (lee bm_seq, no producto).
INSERT INTO movimiento_inventario (producto_id, tipo_movimiento_id, cantidad, fecha, empleado_id, observacion)
SELECT 30 + n, 1, 1000, '2024-11-01 08:00:00', 4, 'Benchmark: entrada inicial'
  FROM bm_seq
 WHERE n BETWEEN 1 AND 3000;

-- 3. 20,000 ventas (venta_id 1001..21000) repartidas entre 2024-11-02 y 2026-11-22.
INSERT INTO venta (venta_id, cliente_id, empleado_id, fecha)
SELECT 1000 + n,
       2 + (n % 20),
       2 + (n % 2),
       TIMESTAMP('2024-11-02 08:00:00') + INTERVAL (n % 750) DAY + INTERVAL ((n * 37) % 600) MINUTE
  FROM bm_seq
 WHERE n BETWEEN 1 AND 20000;

-- 4. Dos renglones por venta con productos distintos. El precio y el costo se
--    calculan con la misma fórmula usada al crear el producto (no se lee producto).
INSERT INTO detalle_venta (venta_id, producto_id, cantidad, precio_unitario, costo_unitario)
SELECT 1000 + x.n, 30 + x.m, 1 + (x.n % 5), 20 + (x.m % 500), ROUND((20 + (x.m % 500)) * 0.6, 2)
  FROM (SELECT n, 1 + ((n * 7) % 3000) AS m FROM bm_seq WHERE n BETWEEN 1 AND 20000) x;

INSERT INTO detalle_venta (venta_id, producto_id, cantidad, precio_unitario, costo_unitario)
SELECT 1000 + x.n, 30 + x.m, 1 + (x.n % 3), 20 + (x.m % 500), ROUND((20 + (x.m % 500)) * 0.6, 2)
  FROM (SELECT n, 1 + ((n * 7 + 1500) % 3000) AS m FROM bm_seq WHERE n BETWEEN 1 AND 20000) x;

DROP TABLE bm_seq;
DROP TABLE bm_digito;

ANALYZE TABLE producto, venta, detalle_venta, movimiento_inventario;

-- Verificación
SELECT 'producto' AS tabla, COUNT(*) AS filas FROM producto
UNION ALL SELECT 'venta',                 COUNT(*) FROM venta
UNION ALL SELECT 'detalle_venta',         COUNT(*) FROM detalle_venta
UNION ALL SELECT 'movimiento_inventario', COUNT(*) FROM movimiento_inventario;

-- Debe devolver 0 filas (RN-19 se mantiene con el volumen)
SELECT * FROM v_conciliacion_inventario WHERE diferencia <> 0;

-- Fin de 04b_volumen_benchmark.sql
