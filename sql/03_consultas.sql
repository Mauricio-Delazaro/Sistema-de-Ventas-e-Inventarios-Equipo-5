-- =============================================================================
-- Proyecto integrador · Equipo 5 · Sistema de ventas e inventarios
-- 03_consultas.sql — Las 10 consultas obligatorias (y una complementaria).
--
-- Requisito: haber ejecutado 01_ddl.sql y 02_dml.sql.
-- Ejecución:  mysql -u root --default-character-set=utf8mb4 -t < sql/03_consultas.sql
--
-- Cada consulta indica: qué hace · tipo de JOIN · nivel de dificultad.
-- Los parámetros se fijan con SET @variable justo antes de cada consulta;
-- se pueden cambiar para probar otros casos.
--
-- Criterios comunes (docs/02_analisis.md, RN-21):
--   · Las ventas CANCELADA no cuentan como ventas en reportes ni rankings.
--   · Importe de un renglón     = cantidad × precio_unitario (precio histórico).
--   · Margen estimado           = Σ cantidad × (precio_unitario − costo_unitario).
-- =============================================================================

-- COLLATE explícito: las variables @ toman la colación de la conexión y deben
-- coincidir con la de las columnas (utf8mb4_unicode_ci) para compararse con ellas.
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ventas_equipo5;

-- -----------------------------------------------------------------------------
-- CONSULTA 1 · Listar productos por nombre
-- Qué hace : catálogo completo ordenado alfabéticamente, con categoría, precio
--            vigente, existencia y si está activo.
-- JOIN     : INNER JOIN producto–categoria (todo producto tiene categoría, RN-01).
-- Nivel    : BÁSICO
-- -----------------------------------------------------------------------------
SELECT p.sku,
       p.nombre,
       c.nombre        AS categoria,
       p.precio_venta,
       p.existencia,
       p.activo
  FROM producto  p
  JOIN categoria c ON c.categoria_id = p.categoria_id
 ORDER BY p.nombre;

-- 1b · Búsqueda por nombre (prefijo). Variante usada en la Fase 8 para el índice producto(nombre).
SET @buscar = 'Llave';
SELECT p.sku, p.nombre, p.precio_venta, p.existencia
  FROM producto p
 WHERE p.nombre LIKE CONCAT(@buscar, '%')
 ORDER BY p.nombre;

-- -----------------------------------------------------------------------------
-- CONSULTA 2 · Consultar productos de una categoría
-- Qué hace : productos de la categoría indicada por nombre, ordenados por nombre.
-- JOIN     : INNER JOIN producto–categoria; el filtro se aplica sobre la categoría.
-- Nivel    : BÁSICO
-- -----------------------------------------------------------------------------
SET @categoria = 'Material eléctrico';
SELECT c.nombre AS categoria,
       p.sku,
       p.nombre,
       p.precio_venta,
       p.existencia
  FROM producto  p
  JOIN categoria c ON c.categoria_id = p.categoria_id
 WHERE c.nombre = @categoria
 ORDER BY p.nombre;

-- -----------------------------------------------------------------------------
-- CONSULTA 3 · Mostrar ventas de un cliente
-- Qué hace : historial de ventas del cliente indicado, con fecha, vendedor y estado.
-- JOIN     : INNER JOIN venta–cliente y venta–empleado.
-- Nivel    : BÁSICO
-- -----------------------------------------------------------------------------
SET @cliente_id = 2;   -- Constructora Robles
SELECT v.venta_id,
       v.fecha,
       CONCAT_WS(' ', c.nombre, c.apellido) AS cliente,
       CONCAT(e.nombre, ' ', e.apellido)    AS vendedor,
       v.estado
  FROM venta    v
  JOIN cliente  c ON c.cliente_id  = v.cliente_id
  JOIN empleado e ON e.empleado_id = v.empleado_id
 WHERE v.cliente_id = @cliente_id
 ORDER BY v.fecha;

-- -----------------------------------------------------------------------------
-- CONSULTA 4 · Listar productos debajo del umbral de existencias
-- Qué hace : productos activos cuya existencia es menor que su stock mínimo y
--            cuántas piezas faltan para alcanzarlo. Lista de reabastecimiento.
-- JOIN     : INNER JOIN producto–categoria.
-- Nivel    : BÁSICO
-- -----------------------------------------------------------------------------
SELECT p.sku,
       p.nombre,
       c.nombre                        AS categoria,
       p.existencia,
       p.stock_minimo,
       p.stock_minimo - p.existencia   AS faltante
  FROM producto  p
  JOIN categoria c ON c.categoria_id = p.categoria_id
 WHERE p.activo = 1
   AND p.existencia < p.stock_minimo
 ORDER BY faltante DESC, p.nombre;

-- -----------------------------------------------------------------------------
-- CONSULTA 5 · Calcular importe total de una venta
-- Qué hace : (a) renglones de la venta con su subtotal; (b) total, pagado y saldo.
--            El total NO está almacenado (RN-10): se calcula del detalle.
-- JOIN     : INNER JOIN detalle_venta–producto (a); venta–cliente–detalle_venta (b);
--            subconsulta correlacionada para la suma de pagos.
-- Nivel    : INTERMEDIO (agregación SUM con GROUP BY sobre varias tablas)
-- -----------------------------------------------------------------------------
SET @venta_id = 31;   -- venta de Constructora Robles con pago parcial

-- 5a · Renglones de la venta
SELECT d.venta_id,
       p.sku,
       p.nombre,
       d.cantidad,
       d.precio_unitario,
       d.cantidad * d.precio_unitario AS subtotal
  FROM detalle_venta d
  JOIN producto      p ON p.producto_id = d.producto_id
 WHERE d.venta_id = @venta_id
 ORDER BY p.nombre;

-- 5b · Total de la venta
SELECT v.venta_id,
       v.fecha,
       CONCAT_WS(' ', c.nombre, c.apellido)       AS cliente,
       v.estado,
       COUNT(*)                                   AS renglones,
       SUM(d.cantidad)                            AS piezas,
       SUM(d.cantidad * d.precio_unitario)        AS total,
       (SELECT COALESCE(SUM(pg.monto), 0)
          FROM pago pg WHERE pg.venta_id = v.venta_id) AS pagado,
       SUM(d.cantidad * d.precio_unitario)
     - (SELECT COALESCE(SUM(pg.monto), 0)
          FROM pago pg WHERE pg.venta_id = v.venta_id) AS saldo
  FROM venta         v
  JOIN cliente       c ON c.cliente_id = v.cliente_id
  JOIN detalle_venta d ON d.venta_id   = v.venta_id
 WHERE v.venta_id = @venta_id
 GROUP BY v.venta_id, v.fecha, c.nombre, c.apellido, v.estado;

-- -----------------------------------------------------------------------------
-- CONSULTA 6 · Mostrar productos más vendidos
-- Qué hace : top 10 por unidades vendidas, con el importe que generaron.
--            Excluye ventas CANCELADA.
-- JOIN     : INNER JOIN detalle_venta–venta–producto.
-- Nivel    : INTERMEDIO (SUM + GROUP BY + ORDER BY + LIMIT)
-- -----------------------------------------------------------------------------
SELECT p.sku,
       p.nombre,
       SUM(d.cantidad)                      AS unidades_vendidas,
       COUNT(DISTINCT d.venta_id)           AS ventas,
       SUM(d.cantidad * d.precio_unitario)  AS importe
  FROM detalle_venta d
  JOIN venta         v ON v.venta_id    = d.venta_id
  JOIN producto      p ON p.producto_id = d.producto_id
 WHERE v.estado <> 'CANCELADA'
 GROUP BY p.producto_id, p.sku, p.nombre
 ORDER BY unidades_vendidas DESC, importe DESC
 LIMIT 10;

-- -----------------------------------------------------------------------------
-- CONSULTA 7 · Encontrar clientes con mayor gasto
-- Qué hace : clientes cuyo gasto acumulado supera @gasto_minimo, de mayor a menor.
--            Gasto = importe de sus ventas no canceladas (RN-21). Se excluye al
--            cliente genérico PÚBLICO EN GENERAL (cliente_id = 1) porque agrupa
--            ventas de mostrador de personas distintas.
-- JOIN     : INNER JOIN cliente–venta–detalle_venta.
-- Nivel    : INTERMEDIO (GROUP BY + HAVING sobre un agregado)
-- -----------------------------------------------------------------------------
SET @gasto_minimo = 10000;
SELECT c.cliente_id,
       CONCAT_WS(' ', c.nombre, c.apellido)   AS cliente,
       COUNT(DISTINCT v.venta_id)             AS ventas,
       SUM(d.cantidad * d.precio_unitario)    AS gasto_total
  FROM cliente       c
  JOIN venta         v ON v.cliente_id = c.cliente_id
  JOIN detalle_venta d ON d.venta_id   = v.venta_id
 WHERE v.estado <> 'CANCELADA'
   AND c.cliente_id <> 1
 GROUP BY c.cliente_id, c.nombre, c.apellido
HAVING SUM(d.cantidad * d.precio_unitario) > @gasto_minimo
 ORDER BY gasto_total DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 8 · Identificar productos sin ventas
-- Qué hace : productos que no aparecen en ninguna venta válida (no cancelada).
-- JOIN     : LEFT JOIN producto → (detalle_venta INNER JOIN venta). El LEFT JOIN
--            conserva todos los productos; los que no tienen pareja quedan con
--            columnas NULL y se filtran con IS NULL (anti-join).
--            La condición estado <> 'CANCELADA' va en el ON del join interno y no
--            en el WHERE: en el WHERE descartaría las filas NULL del LEFT JOIN y la
--            consulta ya no encontraría nada.
-- Nivel    : AVANZADO
-- -----------------------------------------------------------------------------
SELECT p.sku,
       p.nombre,
       c.nombre       AS categoria,
       p.existencia,
       p.activo
  FROM producto  p
  JOIN categoria c ON c.categoria_id = p.categoria_id
  LEFT JOIN (detalle_venta d
             JOIN venta v ON v.venta_id = d.venta_id
                         AND v.estado  <> 'CANCELADA')
         ON d.producto_id = p.producto_id
 WHERE d.producto_id IS NULL
 ORDER BY p.nombre;

-- -----------------------------------------------------------------------------
-- CONSULTA 9 · Consultar ventas mensuales
-- Qué hace : por mes del periodo [@desde, @hasta): número de ventas, piezas,
--            importe vendido y ticket promedio. Excluye ventas CANCELADA.
-- JOIN     : INNER JOIN venta–detalle_venta dentro de una tabla derivada que
--            calcula el total por venta; después se agrupa por mes.
-- Nivel    : AVANZADO (agregación en dos niveles + funciones de fecha)
-- -----------------------------------------------------------------------------
SET @desde = '2026-06-01', @hasta = '2026-12-01';
SELECT DATE_FORMAT(t.fecha, '%Y-%m')      AS mes,
       COUNT(*)                           AS ventas,
       SUM(t.piezas)                      AS piezas,
       SUM(t.total)                       AS importe,
       ROUND(AVG(t.total), 2)             AS ticket_promedio
  FROM (SELECT v.venta_id,
               v.fecha,
               SUM(d.cantidad)                     AS piezas,
               SUM(d.cantidad * d.precio_unitario) AS total
          FROM venta         v
          JOIN detalle_venta d ON d.venta_id = v.venta_id
         WHERE v.estado <> 'CANCELADA'
           AND v.fecha >= @desde AND v.fecha < @hasta
         GROUP BY v.venta_id, v.fecha) t
 GROUP BY DATE_FORMAT(t.fecha, '%Y-%m')
 ORDER BY mes;

-- -----------------------------------------------------------------------------
-- CONSULTA 10 · Reporte de ventas por categoría y margen estimado
-- Qué hace : por categoría: unidades, ingreso, costo, margen y % de margen.
--            Excluye ventas CANCELADA.
-- FÓRMULA  : ingreso        = Σ cantidad × precio_unitario
--            costo          = Σ cantidad × costo_unitario
--            margen         = Σ cantidad × (precio_unitario − costo_unitario)
--                           = ingreso − costo
--            margen %       = margen / ingreso × 100
--            precio_unitario y costo_unitario son los HISTÓRICOS guardados en el
--            detalle al momento de vender (RN-09), no los vigentes del catálogo.
-- JOIN     : INNER JOIN categoria–producto–detalle_venta–venta (4 tablas).
-- Nivel    : AVANZADO
-- -----------------------------------------------------------------------------
SELECT c.nombre                                                    AS categoria,
       SUM(d.cantidad)                                             AS unidades,
       SUM(d.cantidad * d.precio_unitario)                         AS ingreso,
       SUM(d.cantidad * d.costo_unitario)                          AS costo,
       SUM(d.cantidad * (d.precio_unitario - d.costo_unitario))    AS margen,
       ROUND(SUM(d.cantidad * (d.precio_unitario - d.costo_unitario))
             / SUM(d.cantidad * d.precio_unitario) * 100, 2)       AS margen_pct
  FROM categoria     c
  JOIN producto      p ON p.categoria_id = c.categoria_id
  JOIN detalle_venta d ON d.producto_id  = p.producto_id
  JOIN venta         v ON v.venta_id     = d.venta_id
 WHERE v.estado <> 'CANCELADA'
 GROUP BY c.categoria_id, c.nombre
 ORDER BY margen DESC;

-- -----------------------------------------------------------------------------
-- CONSULTA 11 (complementaria) · Historial de movimientos de un producto
-- Qué hace : todos los movimientos del producto en orden cronológico, con su
--            efecto (+/−) y el saldo acumulado. Cubre el requerimiento
--            "consultar movimientos de inventario" (RF-12) y demuestra que el
--            saldo se reconstruye desde el historial (RN-19).
-- JOIN     : INNER JOIN movimiento–tipo_movimiento; LEFT JOIN movimiento–empleado
--            (las salidas por venta no tienen capturista).
-- Nivel    : AVANZADO (función de ventana SUM() OVER)
-- -----------------------------------------------------------------------------
SET @producto_id = 16;   -- ME-004 Foco LED: incluye ventas y devoluciones
SELECT m.movimiento_id,
       m.fecha,
       t.clave                                      AS tipo,
       t.signo * m.cantidad                         AS efecto,
       SUM(t.signo * m.cantidad)
           OVER (ORDER BY m.fecha, m.movimiento_id) AS saldo,
       m.venta_id,
       CONCAT(e.nombre, ' ', e.apellido)            AS capturo,
       m.observacion
  FROM movimiento_inventario m
  JOIN tipo_movimiento       t ON t.tipo_movimiento_id = m.tipo_movimiento_id
  LEFT JOIN empleado         e ON e.empleado_id        = m.empleado_id
 WHERE m.producto_id = @producto_id
 ORDER BY m.fecha, m.movimiento_id;

-- Fin de 03_consultas.sql
