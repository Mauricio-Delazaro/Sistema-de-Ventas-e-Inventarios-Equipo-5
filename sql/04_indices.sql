-- =============================================================================
-- Proyecto integrador · Equipo 5 · Sistema de ventas e inventarios
-- 04_indices.sql — Índices adicionales con evidencia EXPLAIN antes/después.
--
-- Orden recomendado (con volumen, para que el efecto sea visible):
--     01_ddl.sql → 02_dml.sql → 04b_volumen_benchmark.sql → 04_indices.sql
-- También funciona sin 04b (01 → 02 → 04); con pocos datos el optimizador puede
-- seguir prefiriendo leer la tabla completa. Ver docs/06_indices_optimizacion.md.
--
-- Ejecutar UNA vez sobre una base recién cargada: si los índices ya existen,
-- CREATE INDEX falla por nombre duplicado (recargar con 01 y 02).
-- Ejecución: mysql -u root --default-character-set=utf8mb4 -t < sql/04_indices.sql
--
-- Ninguno de estos índices repite uno que InnoDB ya creó por PK, UNIQUE o FK
-- (lista en docs/04_modelo_relacional.md, sección 5).
--
-- Cómo leer EXPLAIN:
--   type   ALL = recorre la tabla completa · index = recorre un índice completo
--          range = rango de un índice · ref/eq_ref = búsqueda puntual por índice
--   key    índice elegido (NULL = ninguno)
--   rows   filas que el optimizador estima examinar
--   Extra  Using filesort = ordena en memoria/disco · Using index = el índice
--          cubre la consulta y no se lee la fila · Using index condition = el
--          filtro se evalúa dentro del índice
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ventas_equipo5;

ANALYZE TABLE producto, venta, detalle_venta, movimiento_inventario;

-- =============================================================================
-- ÍNDICE 1 · idx_producto_nombre ON producto (nombre)
-- Consultas: 1 (listado por nombre, paginado) y 1b (búsqueda por prefijo).
-- Justificación: el listado ordena por nombre y la búsqueda filtra con
-- LIKE 'texto%'. Sin índice, ambas recorren la tabla y ordenan (filesort).
-- Un LIKE con comodín solo al final puede resolverse como rango del índice.
-- =============================================================================
SELECT 'ÍNDICE 1 · ANTES · consulta 1b (LIKE prefijo)' AS evidencia;
EXPLAIN
SELECT p.sku, p.nombre, p.precio_venta, p.existencia
  FROM producto p
 WHERE p.nombre LIKE 'Llave%'
 ORDER BY p.nombre;

SELECT 'ÍNDICE 1 · ANTES · consulta 1 paginada (primeros 20 por nombre)' AS evidencia;
EXPLAIN
SELECT p.sku, p.nombre, p.precio_venta, p.existencia
  FROM producto p
 ORDER BY p.nombre
 LIMIT 20;

CREATE INDEX idx_producto_nombre ON producto (nombre);
ANALYZE TABLE producto;

SELECT 'ÍNDICE 1 · DESPUÉS · consulta 1b (LIKE prefijo)' AS evidencia;
EXPLAIN
SELECT p.sku, p.nombre, p.precio_venta, p.existencia
  FROM producto p
 WHERE p.nombre LIKE 'Llave%'
 ORDER BY p.nombre;

SELECT 'ÍNDICE 1 · DESPUÉS · consulta 1 paginada (primeros 20 por nombre)' AS evidencia;
EXPLAIN
SELECT p.sku, p.nombre, p.precio_venta, p.existencia
  FROM producto p
 ORDER BY p.nombre
 LIMIT 20;

-- =============================================================================
-- ÍNDICE 2 · idx_venta_fecha_estado ON venta (fecha, estado)
-- Consulta: 9 (ventas mensuales en un periodo) y reportes por rango de fechas.
-- Justificación: el filtro principal es un rango sobre fecha; estado va como
-- segunda columna para evaluar estado <> 'CANCELADA' dentro del índice. Como
-- InnoDB agrega la PK (venta_id) a todo índice secundario, el índice CUBRE la
-- parte de venta de la consulta (venta_id, fecha, estado) sin leer la tabla.
-- fecha va primero: estado tiene solo 3 valores (baja selectividad) y una
-- desigualdad sobre la primera columna impediría usar el rango de fecha.
-- =============================================================================
SELECT 'ÍNDICE 2 · ANTES · consulta 9 (ventas mensuales jun–nov 2026)' AS evidencia;
EXPLAIN
SELECT DATE_FORMAT(t.fecha, '%Y-%m') AS mes, COUNT(*) AS ventas, SUM(t.total) AS importe
  FROM (SELECT v.venta_id, v.fecha, SUM(d.cantidad * d.precio_unitario) AS total
          FROM venta v
          JOIN detalle_venta d ON d.venta_id = v.venta_id
         WHERE v.estado <> 'CANCELADA'
           AND v.fecha >= '2026-06-01' AND v.fecha < '2026-12-01'
         GROUP BY v.venta_id, v.fecha) t
 GROUP BY DATE_FORMAT(t.fecha, '%Y-%m');

CREATE INDEX idx_venta_fecha_estado ON venta (fecha, estado);
ANALYZE TABLE venta;

SELECT 'ÍNDICE 2 · DESPUÉS · consulta 9 (ventas mensuales jun–nov 2026)' AS evidencia;
EXPLAIN
SELECT DATE_FORMAT(t.fecha, '%Y-%m') AS mes, COUNT(*) AS ventas, SUM(t.total) AS importe
  FROM (SELECT v.venta_id, v.fecha, SUM(d.cantidad * d.precio_unitario) AS total
          FROM venta v
          JOIN detalle_venta d ON d.venta_id = v.venta_id
         WHERE v.estado <> 'CANCELADA'
           AND v.fecha >= '2026-06-01' AND v.fecha < '2026-12-01'
         GROUP BY v.venta_id, v.fecha) t
 GROUP BY DATE_FORMAT(t.fecha, '%Y-%m');

-- =============================================================================
-- ÍNDICE 3 · idx_mov_producto_fecha ON movimiento_inventario (producto_id, fecha)
-- Consulta: 11 (historial de un producto) y kárdex por periodo.
-- Justificación: el índice de la FK (producto_id) ya localiza los movimientos
-- del producto, pero después hay que ordenarlos por fecha (filesort) y no
-- puede filtrar un rango de fechas. Con (producto_id, fecha) los movimientos
-- salen ya ordenados y el rango de fechas se resuelve en el índice.
-- Este índice compuesto también sirve para la FK (su primera columna es producto_id).
-- =============================================================================
SELECT 'ÍNDICE 3 · ANTES · kárdex de ME-004 desde 2026-09-01' AS evidencia;
EXPLAIN
SELECT m.movimiento_id, m.fecha, m.tipo_movimiento_id, m.cantidad
  FROM movimiento_inventario m
 WHERE m.producto_id = 16
   AND m.fecha >= '2026-09-01'
 ORDER BY m.fecha;

CREATE INDEX idx_mov_producto_fecha ON movimiento_inventario (producto_id, fecha);
ANALYZE TABLE movimiento_inventario;

SELECT 'ÍNDICE 3 · DESPUÉS · kárdex de ME-004 desde 2026-09-01' AS evidencia;
EXPLAIN
SELECT m.movimiento_id, m.fecha, m.tipo_movimiento_id, m.cantidad
  FROM movimiento_inventario m
 WHERE m.producto_id = 16
   AND m.fecha >= '2026-09-01'
 ORDER BY m.fecha;

-- =============================================================================
-- ÍNDICE 4 · idx_detalle_producto_cubriente ON detalle_venta (producto_id, cantidad, precio_unitario)
-- Consultas: 6 (productos más vendidos) y 8 (productos sin ventas).
-- Justificación: el índice de la FK (producto_id) solo localiza renglones; para
-- sumar cantidad × precio_unitario hay que leer cada fila. Este índice es
-- CUBRIENTE: contiene producto_id, cantidad, precio_unitario y, por ser InnoDB,
-- la PK (venta_id, producto_id). La consulta 6 se resuelve leyendo solo el
-- índice ("Using index"), que es más angosto que la tabla.
-- =============================================================================
SELECT 'ÍNDICE 4 · ANTES · consulta 6 (más vendidos)' AS evidencia;
EXPLAIN
SELECT p.sku, p.nombre, SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS importe
  FROM detalle_venta d
  JOIN venta    v ON v.venta_id    = d.venta_id
  JOIN producto p ON p.producto_id = d.producto_id
 WHERE v.estado <> 'CANCELADA'
 GROUP BY p.producto_id, p.sku, p.nombre
 ORDER BY unidades DESC
 LIMIT 10;

SELECT 'ÍNDICE 4 · ANTES · consulta 8 (sin ventas, LEFT JOIN)' AS evidencia;
EXPLAIN
SELECT p.sku, p.nombre
  FROM producto p
  LEFT JOIN (detalle_venta d
             JOIN venta v ON v.venta_id = d.venta_id AND v.estado <> 'CANCELADA')
         ON d.producto_id = p.producto_id
 WHERE d.producto_id IS NULL;

CREATE INDEX idx_detalle_producto_cubriente ON detalle_venta (producto_id, cantidad, precio_unitario);
ANALYZE TABLE detalle_venta;

SELECT 'ÍNDICE 4 · DESPUÉS · consulta 6 (más vendidos)' AS evidencia;
EXPLAIN
SELECT p.sku, p.nombre, SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS importe
  FROM detalle_venta d
  JOIN venta    v ON v.venta_id    = d.venta_id
  JOIN producto p ON p.producto_id = d.producto_id
 WHERE v.estado <> 'CANCELADA'
 GROUP BY p.producto_id, p.sku, p.nombre
 ORDER BY unidades DESC
 LIMIT 10;

SELECT 'ÍNDICE 4 · DESPUÉS · consulta 8 (sin ventas, LEFT JOIN)' AS evidencia;
EXPLAIN
SELECT p.sku, p.nombre
  FROM producto p
  LEFT JOIN (detalle_venta d
             JOIN venta v ON v.venta_id = d.venta_id AND v.estado <> 'CANCELADA')
         ON d.producto_id = p.producto_id
 WHERE d.producto_id IS NULL;

-- =============================================================================
-- RESUMEN · índices adicionales creados
-- =============================================================================
SELECT TABLE_NAME AS tabla,
       INDEX_NAME AS indice,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ', ') AS columnas
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA = 'ventas_equipo5'
   AND INDEX_NAME LIKE 'idx\_%'
 GROUP BY TABLE_NAME, INDEX_NAME
 ORDER BY TABLE_NAME;

-- -----------------------------------------------------------------------------
-- Evidencia con filas REALES (opcional; la sintaxis depende del motor):
--   MariaDB:  ANALYZE SELECT ...            (columnas r_rows y r_filtered)
--   MySQL 8:  EXPLAIN ANALYZE SELECT ...    (8.0.18+, tiempos y filas reales)
-- -----------------------------------------------------------------------------

-- Fin de 04_indices.sql
