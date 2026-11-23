# Fase 8 · Índices y optimización

**Proyecto integrador — Equipo 5 · Sistema de ventas e inventarios**

Scripts: [sql/04_indices.sql](../sql/04_indices.sql) (índices y `EXPLAIN` antes/después) y
[sql/04b_volumen_benchmark.sql](../sql/04b_volumen_benchmark.sql) (volumen opcional).
Motor de la evidencia: **MariaDB 10.4.32 (XAMPP)**. Fecha: 2026-11-23.

---

## 1. Punto de partida: índices que ya existen

InnoDB crea un índice por cada PK, cada `UNIQUE` y cada FK que no tenga uno
(ver [04_modelo_relacional.md](04_modelo_relacional.md), sección 5). Por eso ya están indexados, entre otros:
- `producto.sku`;
- `venta.cliente_id`;
- `detalle_venta.producto_id`;
- `movimiento_inventario.producto_id`.

**Regla del equipo:** un índice adicional solo se justifica si resuelve algo que esos índices **no**
resuelven: un orden, un rango sobre otra columna o cubrir la consulta. Por eso el índice
`detalle_venta(producto_id)` del plan original se descartó: era idéntico al de la FK (T-05).

## 2. Índices adicionales

| # | Índice | Columnas | Consultas que atiende |
|---|---|---|---|
| 1 | `idx_producto_nombre` | `producto (nombre)` | 1 (listado por nombre) y 1b (búsqueda por prefijo) |
| 2 | `idx_venta_fecha_estado` | `venta (fecha, estado)` | 9 (ventas mensuales) y reportes por periodo |
| 3 | `idx_mov_producto_fecha` | `movimiento_inventario (producto_id, fecha)` | 11 (historial / kárdex por periodo) |
| 4 | `idx_detalle_producto_cubriente` | `detalle_venta (producto_id, cantidad, precio_unitario)` | 6 (productos más vendidos) |

**Efecto lateral:** al crear los índices 3 y 4, MariaDB **eliminó automáticamente** los índices de
FK `fk_mov_producto` y `fk_detalle_producto`. Los índices nuevos empiezan con `producto_id`, así que
ya pueden respaldar la FK. Resultado: los índices compuestos **no duplican almacenamiento** de lo que
ya existía. MySQL 8 hace lo mismo.

---

## 3. Por qué la evidencia usa volumen adicional

Con los datos de `02_dml.sql` (30 productos y 60 ventas), el optimizador prefiere leer la tabla
completa en varias consultas: leer 60 filas cuesta menos que recorrer un índice y luego buscar cada
fila. El `EXPLAIN` "antes" y "después" salía casi igual (sección 6). Por eso
`04b_volumen_benchmark.sql` agrega:
- 3,000 productos;
- 20,000 ventas (de nov-2024 a nov-2026);
- 40,000 renglones;
- 43,000 movimientos.

Todo pasa por los mismos triggers, así que las reglas de negocio se siguen cumpliendo y la
conciliación de inventario queda en diferencia 0. La carga tardó **10.5 s**.

**Orden de ejecución:** `01 → 02 → 04b → 04`. Después, `01 → 02` para volver a los datos limpios.

### Cómo leer `EXPLAIN`

| Columna | Significado |
|---|---|
| `type` | `ALL` = recorre toda la tabla · `index` = recorre todo un índice · `range` = solo un rango del índice · `ref` / `eq_ref` = búsqueda puntual |
| `key` | Índice elegido (`NULL` = ninguno) |
| `rows` | Filas que el optimizador **estima** examinar |
| `r_rows` | Filas **reales** (solo en `ANALYZE SELECT` de MariaDB) |
| `Using filesort` | Ordena los resultados aparte |
| `Using index` | Índice cubriente: no lee la fila de la tabla |
| `Using index condition` | El filtro se evalúa dentro del índice |

---

## 4. Evidencia `EXPLAIN` antes y después (con volumen)

### Índice 1 · `idx_producto_nombre ON producto (nombre)`

**Justificación:** la consulta 1 ordena por nombre y la búsqueda 1b filtra con `LIKE 'texto%'`.
Un `LIKE` con comodín **solo al final** se puede resolver como rango del índice. Un `LIKE '%texto'`
no podría.

**Consulta 1b · `WHERE nombre LIKE 'Llave%' ORDER BY nombre`**

| | type | key | rows | Extra |
|---|---|---|---|---|
| Antes | `ALL` | — | 3,030 | Using where; **Using filesort** |
| Después | **`range`** | `idx_producto_nombre` | **152** | Using index condition |

**Análisis:** pasa de recorrer los 3,030 productos y ordenarlos a leer solo el rango de 152 nombres
que empiezan con "Llave". Esos nombres ya salen ordenados del índice, así que desaparece el
**filesort**. Las filas examinadas bajan **95 %**.

**Consulta 1 paginada · `ORDER BY nombre LIMIT 20`**

| | type | key | rows | Extra |
|---|---|---|---|---|
| Antes | `ALL` | — | 3,030 | Using filesort |
| Después (elección del optimizador) | `ALL` | — | 3,030 | Using filesort |
| Con `FORCE INDEX (idx_producto_nombre)` | `index` | `idx_producto_nombre` | lee 20 (`r_rows = 20`) | sin filesort |

**Análisis (resultado honesto):** MariaDB 10.4 **no eligió** el índice para el listado paginado.
Estimó más barato leer 3,030 filas cortas y ordenarlas que recorrer el índice y buscar cada fila,
porque el índice no cubre `sku`, `precio_venta` ni `existencia`. Con `FORCE INDEX`, el plan lee
solo los 20 primeros nombres y no ordena.

Este caso responde a la pregunta "¿cómo podría optimizarse?": con más productos, o con un índice
cubriente `(nombre, sku, precio_venta, existencia)`, el optimizador elegiría el índice. El
optimizador de MySQL 8 tiende a preferir el índice con `ORDER BY … LIMIT`; no se verificó en
este entorno.

### Índice 2 · `idx_venta_fecha_estado ON venta (fecha, estado)`

**Justificación:**
- La consulta 9 filtra un **rango de fechas**, y ese es el filtro selectivo.
- `estado` va como segunda columna para evaluar `estado <> 'CANCELADA'` dentro del índice.
- InnoDB agrega la PK (`venta_id`) a todo índice secundario, así que el índice **cubre** toda la
  parte de `venta` de la consulta (`venta_id`, `fecha`, `estado`).
- `fecha` va primero porque `estado` solo tiene 3 valores, y una desigualdad (`<>`) en la primera
  columna impediría aprovechar el rango de fechas.

**Consulta 9 · ventas mensuales de jun a nov 2026 (tabla `v` dentro de la tabla derivada)**

| | type | key | rows (estimadas) | r_rows (reales) | Extra |
|---|---|---|---|---|---|
| Antes | `ALL` | — | 20,313 | **20,060** | Using where; Using temporary; Using filesort |
| Después | **`range`** | `idx_venta_fecha_estado` | 4,584 | **4,584** | Using where; **Using index**; Using temporary; Using filesort |

**Análisis:**
- Antes se leían las 20,060 ventas y se descartaba el 77 % (`r_filtered = 22.84 %`). Después solo
  se lee el rango de 6 meses: **4,584 filas, 77 % menos**.
- `Using index` indica que ni siquiera se lee la fila de la tabla.
- El `Using temporary; Using filesort` que queda viene del `GROUP BY` por mes sobre una expresión
  (`DATE_FORMAT`). Ningún índice lo evita, pero ahora se aplica a 4,584 filas y no a 20,060.

### Índice 3 · `idx_mov_producto_fecha ON movimiento_inventario (producto_id, fecha)`

**Justificación:** el índice de la FK (`producto_id`) encuentra los movimientos de un producto, pero
**no puede** filtrar un rango de fechas ni entregarlos ordenados. El kárdex siempre se consulta por
producto **y** en orden cronológico.

**Kárdex de ME-004 desde 2026-09-01 · `WHERE producto_id = 16 AND fecha >= … ORDER BY fecha`**

| | type | key | rows | Extra |
|---|---|---|---|---|
| Antes | `ref` | `fk_mov_producto` | 15 | Using where; **Using filesort** |
| Después | **`range`** | `idx_mov_producto_fecha` | **7** | Using index condition |

**Análisis:**
- Antes, el plan leía los 15 movimientos del producto, descartaba los anteriores a septiembre y
  ordenaba.
- Después lee directamente los 7 del periodo, ya ordenados: **no hay filesort**.
- El efecto se ve **incluso sin volumen adicional**, porque el problema era el orden y no el tamaño.
- Con miles de movimientos por producto (años de historia), la diferencia crece en proporción.

### Índice 4 · `idx_detalle_producto_cubriente ON detalle_venta (producto_id, cantidad, precio_unitario)`

**Justificación:** la consulta 6 suma `cantidad` y `cantidad × precio_unitario` por producto. El
índice de la FK solo localiza los renglones, y después hay que leer cada fila completa. Este índice
contiene esas columnas más la PK (`venta_id`), así que es **cubriente** para `detalle_venta`.

**Consulta 6 · productos más vendidos (tabla `d`)**

| | type | key | rows | Extra |
|---|---|---|---|---|
| Antes | `ref` | `fk_detalle_producto` | 6 por producto | (lee cada fila) |
| Después | `ref` | `idx_detalle_producto_cubriente` | 6 por producto | **Using index** |

**Análisis:**
- El número de renglones es el mismo, pero ahora **no se toca la tabla**: todo sale del índice, que
  es más angosto. En los 40,156 renglones eso evita igual número de lecturas de fila.
- El `Using temporary; Using filesort` sobre `producto` viene de ordenar por la suma
  (`ORDER BY unidades DESC`). Un ranking sobre un agregado no se puede indexar.

**Consulta 8 · productos sin ventas (resultado honesto):** el plan **no cambió**. Antes ya mostraba
`Using index; Not exists` con el índice de la FK, porque el anti-join solo necesita `producto_id` y
`venta_id`, y esa PK ya va dentro de cualquier índice secundario. `Not exists` significa que MariaDB
deja de buscar en cuanto encuentra un renglón: es la ejecución óptima de un `LEFT JOIN … IS NULL`.
**Este índice no se justifica por la consulta 8**, sino por la 6.

---

## 5. Resumen de la mejora (con volumen)

| Índice | Consulta | Antes | Después | Mejora |
|---|---|---|---|---|
| `idx_producto_nombre` | 1b | `ALL` 3,030 + filesort | `range` 152 | −95 % filas, sin filesort |
| `idx_venta_fecha_estado` | 9 | `ALL` 20,060 reales | `range` 4,584 reales, cubriente | −77 % filas |
| `idx_mov_producto_fecha` | 11 / kárdex | `ref` 15 + filesort | `range` 7 | −53 % filas, sin filesort |
| `idx_detalle_producto_cubriente` | 6 | `ref` + lectura de fila | `ref` cubriente | sin lectura de filas |

Cumple el requisito: **4 índices adicionales justificados** (mínimo 3), con `EXPLAIN` antes y
después y análisis del plan.

---

## 6. Contraste: los mismos índices sin volumen adicional

Ejecutando `01 → 02 → 04` (30 productos, 60 ventas):

| Índice | Plan después | ¿Se aprovecha? |
|---|---|---|
| 1 (búsqueda 1b) | `range`, 2 filas | Sí |
| 2 (consulta 9) | `index` (recorre las 60 entradas del índice) | Parcial: el rango abarca todas las ventas, así que no hay nada que descartar |
| 3 (kárdex) | `range`, 7 filas, sin filesort | Sí |
| 4 (consulta 6) | No se usa: el plan empieza por `venta` | No: con 60 ventas es más barato otro orden de join |

**Conclusión para la defensa:** un índice no garantiza que se use. El optimizador decide por costo
según el volumen y las estadísticas (`ANALYZE TABLE`). Los índices se diseñan para el volumen
esperado en operación, no para el de prueba.

---

## 7. Índices descartados y por qué

| Candidato | Razón para no crearlo |
|---|---|
| `detalle_venta (producto_id)` | Idéntico al índice de la FK (T-05). |
| `venta (estado)` | Solo 3 valores. Un índice sobre una columna de tan baja cardinalidad casi nunca se elige. |
| Índice para "existencia < stock_minimo" (consulta 4) | Compara dos columnas de la misma fila, y un índice B-tree no resuelve esa condición. Haría falta una columna generada `bajo_umbral` indexada, y con 30–3,000 productos no compensa. |
| `producto (categoria_id, nombre)` | La consulta 2 ya usa el índice de la FK `categoria_id`. Con ~4 productos por categoría el orden es trivial. |

## 8. ¿Cómo podría optimizarse más? (pregunta de defensa)

1. **`venta (cliente_id, fecha)`** para la consulta 3. Elimina el filesort del historial de un
   cliente y reemplazaría al índice de la FK `cliente_id`.
2. **Índice cubriente para el listado paginado:** `producto (nombre, sku, precio_venta, existencia)`,
   para que el optimizador lo elija con `ORDER BY nombre LIMIT n` (sección 4, índice 1).
3. **Tabla resumen mensual** (ventas por mes y categoría) actualizada por trigger o por un proceso
   nocturno. Las consultas 9 y 10 leerían decenas de filas en lugar de miles. Sería redundancia
   controlada, igual que `producto.existencia`.
4. **Particionar `movimiento_inventario` por año** si el historial crece a millones de filas.
5. **Evitar funciones sobre columnas indexadas en el `WHERE`**: `WHERE YEAR(fecha) = 2026` anula el
   índice. Por eso las consultas usan rangos (`fecha >= … AND fecha < …`).
