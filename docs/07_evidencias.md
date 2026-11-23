# Evidencias de ejecución

**Proyecto integrador — Equipo 5 · Sistema de ventas e inventarios**

Este documento acumula las evidencias de cada fase. Las ejecuciones se hicieron en
**MariaDB 10.4.32 (XAMPP)** con el cliente `mysql` de línea de comandos.

---

## Fase 5 · `sql/01_ddl.sql` (2026-11-23)

### Objetos creados

Ejecución: `mysql -u root < sql/01_ddl.sql`. Terminó sin errores (código de salida 0).

| Objeto | Cantidad | Detalle |
|---|---|---|
| Tablas | 12 | Las 12 del modelo relacional |
| Restricciones CHECK | 20 | Todas con nombre `ck_…` |
| Triggers | 18 | `producto` 2, `producto_proveedor` 2, `venta` 2, `detalle_venta` 4, `pago` 4, `movimiento_inventario` 4 |
| Funciones | 2 | `fn_total_venta`, `fn_pagado_venta` |
| Procedimientos | 2 | `registrar_venta`, `cancelar_venta` |
| Vistas | 3 | `v_existencias`, `v_conciliacion_inventario`, `v_venta_saldos` |

### Pruebas de humo: 62 de 62 pasan

Las pruebas usaron datos mínimos (3 productos, 2 clientes, 2 empleados) cargados sobre una base
recién creada. Al terminar se volvió a ejecutar `01_ddl.sql` para dejar la base limpia.

**Flujo correcto: 21 pruebas, todas PASS**

| Prueba | Resultado esperado y obtenido |
|---|---|
| Entrada inicial | `existencia` pasa de 0 a 10 por el trigger |
| `registrar_venta` con 2 productos | Crea la venta, 2 renglones, precio y costo copiados del catálogo |
| Salidas automáticas | 2 movimientos `SALIDA_VENTA` con `venta_id` y **la fecha de la venta** |
| Total calculado | `fn_total_venta` = 3×150 + 2×95 = **640.00** |
| Pago parcial (300) | La venta sigue `PENDIENTE` |
| Pago final (340) | La venta pasa a `PAGADA` automáticamente; `v_venta_saldos.saldo` = 0 |
| Cambio de precio de catálogo 150 → 165 | El detalle conserva 150 (RN-09) |
| `cancelar_venta` | Estado `CANCELADA`, existencia repuesta y movimiento `DEVOLUCION` con `venta_id` |
| Ajuste `AJUSTE_SALIDA` | Descuenta existencia |
| Rollback de venta fallida | No queda la venta ni salidas parciales |
| Borrar proveedor sin historial | Sus filas de `producto_proveedor` se borran en cascada |
| `v_conciliacion_inventario` | Diferencia 0 en todos los productos (RN-19) |
| `v_existencias` | Marca `bajo_umbral = 1` cuando la existencia es menor que `stock_minimo` |

**Violaciones de reglas: 41 pruebas, todas rechazadas con el error esperado**

| Regla | Intento | Error obtenido |
|---|---|---|
| RN-16 | Venta de 999 piezas con 7 en existencia | 1644 `RN-16: existencia insuficiente del producto 1 (disponible = 7, solicitado = 999)`. Rollback completo: tampoco quedó el primer renglón válido. |
| RN-16 | Ajuste que deja saldo negativo | 1644 `RN-16: …` |
| RN-07 | Venta con `[]`, JSON inválido o producto inexistente | 1644 `RN-07: …` |
| RN-07 | Mismo producto dos veces en la venta | 1062 *Duplicate entry* (PK de `detalle_venta`) |
| RN-08 | Cantidad 0 | 4025 `CONSTRAINT ck_detalle_cantidad failed` |
| FK | Cliente, método de pago o categoría inexistentes | 1452 *foreign key constraint fails* |
| RN-13 | Pago mayor que el saldo | 1644 `RN-13: el pago excede el saldo pendiente de la venta (saldo = 45.00)` |
| RN-13 | Pago a venta cancelada, pago anterior a la venta, monto 0 | 1644 `RN-13: …` y 4025 `ck_pago_monto` |
| RN-14 | `UPDATE` o `DELETE` de un pago | 1644 `RN-14: …` |
| RN-12 | Cancelar una venta con pagos o `PAGADA`; marcar `PAGADA` a mano; insertar una venta ya `PAGADA`; cambiar la fecha de una venta | 1644 `RN-12: …` |
| RN-20 | Venta con fecha 2030 | 1644 `RN-20: la fecha de la venta no puede ser futura` |
| RN-11 | Modificar o borrar un renglón; agregar un renglón a una venta `PAGADA` | 1644 `RN-11: …` |
| RN-17 | `UPDATE` o `DELETE` de un movimiento | 1644 `RN-17: …` |
| RN-18 | `SALIDA_VENTA` sin venta; `ENTRADA` con venta | 1644 `RN-18: …` |
| RN-15 | Cantidad negativa en un movimiento | 4025 `ck_mov_cantidad` |
| RN-19 | `UPDATE producto SET existencia = 999`; producto nuevo con existencia 5 | 1644 `RN-19: …` |
| RN-23 | Segundo proveedor principal | 1644 `RN-23: …` |
| RN-02 | SKU duplicado | 1062 `Duplicate entry 'HM-001' for key 'uq_producto_sku'` |
| RN-03 / RN-22 | Precio negativo; puesto `GERENTE` | 4025 `ck_producto_precio` y `ck_empleado_puesto` |
| RN-05 | Vender un producto inactivo | 1644 `RN-05: el producto está inactivo y no se puede vender` |
| RESTRICT | Borrar un producto vendido, una venta, una categoría con productos o un cliente con ventas | 1451 *Cannot delete or update a parent row* |

### Observaciones técnicas

- **Error 1442 evitado.** La cadena `detalle_venta → movimiento_inventario → producto` funciona,
  porque `registrar_venta` inserta con `VALUES` y no con `INSERT … SELECT FROM producto`.
- **Rollback total.** Si falla un renglón, la venta y los renglones anteriores se deshacen. Es la
  garantía de RN-07.
- **Huecos en los folios.** `AUTO_INCREMENT` no retrocede con un `ROLLBACK`, así que una venta
  rechazada consume su número (en la prueba, el intento con producto repetido recibió el folio 6,
  aunque solo existían 3 ventas). Es el
  comportamiento normal de InnoDB y no afecta la integridad. Si se pregunta en la defensa: el folio
  es un identificador, no un contador de ventas.
- **Errores de `CHECK` en MariaDB.** Aparecen con código **4025**. En MySQL 8 el código es **3819**,
  pero el nombre de la restricción aparece en ambos.

---

## Fase 6 · `sql/02_dml.sql` (2026-11-23)

Ejecución: `01_ddl.sql` y después `02_dml.sql`. Ambos terminaron sin errores (código de salida 0).

### Volumen cargado

| Tabla | Filas | Tabla | Filas |
|---|---|---|---|
| categoria | 8 | venta | 60 |
| producto | 30 | detalle_venta | 156 |
| proveedor | 6 | pago | 59 |
| producto_proveedor | 41 | movimiento_inventario | 197 |
| cliente | 21 (20 + público en general) | empleado | 5 |

**Estados de las ventas:** 51 `PAGADA`, 6 `PENDIENTE` y 3 `CANCELADA`.

**Movimientos:**

| Tipo | Cantidad | Origen |
|---|---|---|
| `ENTRADA` | 33 | 30 de inventario inicial y 3 de compra |
| `SALIDA_VENTA` | 156 | Uno por renglón, generados por el trigger |
| `DEVOLUCION` | 5 | Renglones de las 3 ventas canceladas |
| `AJUSTE_SALIDA` | 2 | Ajustes |
| `AJUSTE_ENTRADA` | 1 | Ajuste |

**Integridad de la carga:**
- `v_conciliacion_inventario` no muestra ninguna diferencia (RN-19).
- La existencia mínima es 1, así que ningún producto quedó en negativo.
- Ninguna venta tiene pagos mayores que su total.

### Datos sembrados para las consultas

| Para | Resultado obtenido |
|---|---|
| Consulta 4: bajo umbral | HE-001 (1 de mínimo 2), PL-001 (4/10), ME-004 (20/25), SI-002 (3/15) |
| Consulta 8: sin ventas | HE-003, PI-002, SI-004 y JA-002 (descontinuado, `activo = 0`) |
| Consulta 7: mayor gasto | Pinturas y Acabados del Norte $38,962 · Inst. Eléctricas Mendoza $27,823 · Constructora Robles $26,091. Le sigue el público en general con $4,944. |
| Saldos pendientes | V22, V31, V35 y V49 con pago parcial; V55 y V57 sin pagos |
| Consulta 9: mensual | Entre 9 y 10 ventas por mes de junio a noviembre, de $13,677 a $22,253 |
| RN-09: precio histórico | HM-001: 2 renglones a $150 (jun–jul) y 4 a $165 (ago–nov) |

---

## Fase 7 · `sql/03_consultas.sql` (2026-11-23)

Ejecución sobre la base recién cargada (`01` → `02` → `03`). Las 11 consultas terminaron sin errores
(código de salida 0) y todas devuelven filas.

| # | Consulta | Nivel | Filas | Resultado destacado |
|---|---|---|---|---|
| 1 | Productos por nombre | Básico | 30 | Catálogo completo de "Ancla expansiva" a "Tubo PVC". JA-002 aparece con `activo = 0`. |
| 1b | Búsqueda por prefijo `'Llave'` | Básico | 2 | PL-001, PL-004 |
| 2 | Productos de "Material eléctrico" | Básico | 4 | ME-001 a ME-004 |
| 3 | Ventas de Constructora Robles | Básico | 10 | 8 `PAGADA` y 2 `PENDIENTE` (V31, V57) |
| 4 | Bajo umbral | Básico | 4 | SI-002 (faltan 12), PL-001 (6), ME-004 (5), HE-001 (1) |
| 5 | Importe total de la venta 31 | Intermedio | 4 + 1 | 4 renglones · total $4,538.00 · pagado $2,269.00 · saldo $2,269.00 |
| 6 | Más vendidos (top 10) | Intermedio | 10 | 1.º TF-003 con 230 unidades. PI-001 genera el mayor importe ($38,750). |
| 7 | Clientes con gasto > $10,000 (`HAVING`) | Intermedio | 3 | Pinturas y Acabados del Norte $38,962 · Mendoza $27,823 · Robles $26,091 |
| 8 | Productos sin ventas (`LEFT JOIN`) | Avanzado | 4 | HE-003, PI-002, SI-004, JA-002 |
| 9 | Ventas mensuales jun–nov | Avanzado | 6 | Mejor mes: julio ($22,253). Mejor ticket promedio: agosto ($2,259.33). |
| 10 | Ventas y margen por categoría | Avanzado | 8 | Mayor margen absoluto: Pinturas ($15,598). Mayor margen %: Tornillería (54.84 %). |
| 11 | Historial de ME-004 con saldo acumulado | Avanzado | 15 | El saldo parte de 80 y termina en 20 = `producto.existencia`. Incluye 2 devoluciones por cancelación. |

**Validaciones cruzadas:**
- El ingreso total de la consulta 10 ($114,926.00) es igual a la suma de los importes mensuales de la
  consulta 9. Ambas excluyen las ventas canceladas, así que los dos reportes son consistentes.
- En la consulta 6, ME-004 suma 60 unidades en 10 ventas. Los 5 focos de las ventas canceladas V29 y
  V58 no se cuentan.

**Corrección aplicada durante la fase:** la consulta 1b falló con el error 1267 (*Illegal mix of
collations*). `SET NAMES utf8mb4` deja la conexión en `utf8mb4_general_ci`, mientras que las columnas
están en `utf8mb4_unicode_ci`, y las variables `@` toman la colación de la conexión. En MySQL 8 pasaría
lo mismo, porque su colación por defecto es `utf8mb4_0900_ai_ci`. Se cambió a
`SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci` en los tres scripts y se volvieron a ejecutar
`01`, `02` y `03` sin errores.

---

## Fase 8 · `sql/04b_volumen_benchmark.sql` y `sql/04_indices.sql` (2026-11-23)

| Ejecución | Resultado |
|---|---|
| `01 → 02 → 04b` | Sin errores en **10.5 s**. Quedan 3,030 productos, 20,060 ventas, 40,156 renglones y 43,197 movimientos. La conciliación del inventario sigue en diferencia 0. |
| `04` sobre el volumen | Sin errores. Se crearon 4 índices. Las tablas `EXPLAIN` antes/después y su análisis están en [06_indices_optimizacion.md](06_indices_optimizacion.md). |
| `ANALYZE SELECT` (filas reales) | Consulta 9: 20,060 filas leídas antes y 4,584 después. Paginado con `FORCE INDEX`: 20 filas. |
| `01 → 02 → 04` (sin volumen) | Sin errores. Solo la búsqueda 1b y el kárdex muestran mejora; el resto lo explica la sección 6 del documento de índices. |
| Estado final | Se recargó con `01 → 02` (datos limpios, sin índices adicionales) y se detuvo el servidor. |

**Hallazgo:** MariaDB eliminó automáticamente los índices de FK `fk_mov_producto` y
`fk_detalle_producto` al crear los índices compuestos que empiezan con `producto_id`.

---

## Fase 9 · `sql/05_demo.sql` (2026-11-23)

Ejecución sobre una base recién cargada (`01 → 02 → 05`). Terminó sin errores (código de salida 0).

| Paso | Resultado obtenido |
|---|---|
| 1. Catálogo y proveedor | Nueva categoría "Adhesivos y selladores", 3 productos (AS-001 a AS-003) con existencia 0 y un proveedor principal |
| 2. Inventario inicial | 3 entradas: existencias 40, 12 y 15 |
| 3. Venta con varios productos | Venta 61 con 4 renglones (3 productos nuevos y el martillo a $165). Total $3,666.00 |
| 4. Pagos | Anticipo de $1,833.00 → `PENDIENTE`; liquidación de $1,833.00 → `PAGADA` automáticamente |
| 5. Verificaciones | 4 movimientos `SALIDA_VENTA` con `venta_id = 61`. AS-002 queda en 4, bajo su mínimo de 5. Al subir AS-001 a $99, el detalle conserva $89. La conciliación de los 33 productos tiene 0 diferencias. La nueva categoría aparece en el reporte con ingreso $3,336 y margen $1,448. |
| 6. Cancelación | Venta 62 de 5 piezas de AS-003: 11 → 6. Al cancelarla, `CANCELADA` y vuelve a 11. El historial muestra ENTRADA, 2 salidas y la DEVOLUCION. |
| 7. Violaciones | **10 de 10 RECHAZADO**: RN-16 stock negativo · FK cliente inexistente (1452) · RN-13 pago excedente · RN-13 pago a cancelada · RN-07 venta vacía · RN-17 borrar movimiento · RN-19 editar existencia · RESTRICT borrar producto vendido (1451) · RN-12 cancelar pagada · RN-03 precio negativo (4025). Después de los intentos, la conciliación sigue en 0. |
| 8. Consultas por nivel | Básico: 5 productos bajo umbral (se suma AS-002). Intermedio: 3 clientes con `HAVING` (Robles sube a 2.º lugar con $29,757). Avanzado: los mismos 4 productos sin ventas. |

**Estado final:** se recargó con `01 → 02` y se detuvo el servidor.
