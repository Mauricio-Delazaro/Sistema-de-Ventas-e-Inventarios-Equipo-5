# Plan corregido — Equipo 5 · Sistema de ventas e inventarios

## Contexto

La verificación ([docs/00_verificacion_plan.md](docs/00_verificacion_plan.md)) encontró que el plan
original cubre la especificación, pero tiene 11 huecos de diseño (H-01…H-11) y 8 problemas técnicos
de MySQL (T-01…T-08). Este documento es el plan con todas esas correcciones aplicadas.

Al aprobarlo, la única acción inmediata será guardarlo como `docs/01_plan_corregido.md` y marcar en
`docs/00_verificacion_plan.md` que los 15 cambios quedaron incorporados. Las fases de implementación
se ejecutarán **una a una, con confirmación del usuario entre fases**.

Alcance: solo scripts `.sql` y documentación `.md` en `docs/`. Imágenes, PDF y PPT quedan fuera.

---

## Entorno (verificado en la máquina)

- XAMPP en `C:\xampp` con **MariaDB 10.4.32**, no MySQL. Usa el puerto 3306 y ahora no está corriendo.
- MySQL no está instalado.
- **Decisión:** los scripts serán **portables**: deben correr en MySQL 8.0.16+ y en MariaDB 10.4.
  Para lograrlo se evitan `JSON_TABLE`, los índices funcionales y `EXPLAIN FORMAT=TREE`.
  `EXPLAIN ANALYZE` (MySQL) y `ANALYZE SELECT` (MariaDB) quedan como evidencia opcional.
- **Motor de trabajo: XAMPP (MariaDB 10.4)** — se desarrolla y prueba ahí. Instalar MySQL 8.4 LTS
  (puerto 3307) es opcional; solo hace falta si el profesor exige MySQL literalmente.
- En `docs/06_indices_optimizacion.md` se usa `EXPLAIN` + `ANALYZE SELECT` (equivalente de MariaDB).
- En el README y en el reporte se declara el motor usado y la compatibilidad con MySQL 8.0.16+.

---

## Fase 0. Decisiones de alcance (corregidas)

| Tema | Decisión |
|---|---|
| Fuente de verdad del inventario | `movimiento_inventario` (inmutable: los triggers bloquean UPDATE y DELETE). `producto.existencia` es redundancia controlada que mantiene un trigger, y una vista de conciliación prueba que coincide con el historial. |
| Dirección de los movimientos | `cantidad > 0` siempre. El sentido sale de `tipo_movimiento.signo` (+1/−1). |
| Tipos de movimiento | `ENTRADA(+1)`, `SALIDA_VENTA(−1)`, `AJUSTE_ENTRADA(+1)`, `AJUSTE_SALIDA(−1)`, `DEVOLUCION(+1)` |
| Inventario negativo | Un trigger lo rechaza (`SIGNAL 45000`). Además, `CHECK existencia >= 0` como segunda defensa. |
| Total de la venta | **No se almacena.** Se calcula con `fn_total_venta()` = `Σ cantidad × precio_unitario`. |
| Costo y margen | `producto.costo` (vigente) se copia a `detalle_venta.costo_unitario` al vender. Margen = `Σ cantidad × (precio_unitario − costo_unitario)`. |
| Venta con ≥1 renglón | Se garantiza con el procedimiento transaccional `registrar_venta`. Hace ROLLBACK si recibe 0 renglones. |
| Detalle inmutable | Se rechaza un renglón nuevo si la venta no está `PENDIENTE`. UPDATE y DELETE de renglones están bloqueados. |
| Pagos | Se admiten pagos parciales. Σ pagos ≤ total. No se aceptan pagos para una venta `CANCELADA`. Al completar el total, la venta pasa sola a `PAGADA`. |
| Estados de venta | `PENDIENTE → PAGADA` (automático). `PENDIENTE → CANCELADA` (solo si no hay pagos, con `cancelar_venta`). `CANCELADA` es un estado final. Los reembolsos quedan fuera de alcance. |
| Cancelación | Genera un movimiento `DEVOLUCION` por renglón, con `venta_id`. El stock se repone y el historial se conserva. |
| Cliente | `cliente_id NOT NULL`. Las ventas de mostrador usan el cliente "PÚBLICO EN GENERAL". |
| Borrados | Todo es `RESTRICT`, salvo `producto_proveedor` (`CASCADE`): no se borra nada con historial. Las ventas se cancelan y los productos se dan de baja con `activo = 0`. Motivo: en MySQL y MariaDB, las acciones en cascada de una FK **no disparan triggers**. |
| Fechas | No futuras: se valida con trigger, porque `CHECK` no admite `NOW()`. Los movimientos de venta toman la fecha de la venta, no `NOW()`. |
| Reportes | Se excluyen las ventas `CANCELADA`. "Gasto del cliente" = importe de sus ventas no canceladas. |
| `Empleado` | Se incluye (registra ventas y movimientos). |

## Fase 1. Análisis → `docs/02_analisis.md`

- Empresa ficticia, problema y contexto.
- Actores: administrador de catálogo, vendedor/cajero, almacenista, cliente y proveedor.
- ≥12 RF. Además de los 5 de la spec: entradas de mercancía, ajustes, cancelación, consulta del
  historial por producto, alerta de bajo umbral, reportes de ventas y margen, y conciliación de inventario.
- Reglas RN-01…RN-n, con una tabla de trazabilidad RN → restricción/trigger/procedimiento/consulta.

## Fase 2. Modelo ER → `docs/03_modelo_er.md` (diagrama Mermaid en texto)

**12 entidades:** categoria, producto, proveedor, producto_proveedor, cliente, empleado, venta,
detalle_venta, pago, metodo_pago, movimiento_inventario, tipo_movimiento.

**11 relaciones**, con cardinalidad y participación:
- **9 de tipo 1:N:**
  - Categoría → Producto (0..N / 1)
  - Cliente → Venta (0..N / 1)
  - Empleado → Venta (0..N / 1)
  - Venta → Pago (0..N / 1)
  - Método_Pago → Pago
  - Producto → Movimiento (0..N)
  - Tipo_Movimiento → Movimiento
  - Venta → Movimiento (0..N, FK nula)
  - Empleado → Movimiento (0..N, FK nula)
- **2 de tipo N:M:**
  - Producto ↔ Proveedor (`producto_proveedor`, 0..N en ambos lados)
  - Venta ↔ Producto (`detalle_venta`: 1..N renglones por venta, 0..N por producto)

## Fase 3. Modelo relacional → `docs/04_modelo_relacional.md`

| Tabla | Columnas clave y restricciones |
|---|---|
| categoria | PK `categoria_id`; `nombre` UNIQUE NOT NULL |
| producto | PK; `sku` UNIQUE; `nombre`; FK `categoria_id`; `precio_venta ≥ 0`; `costo ≥ 0`; `existencia ≥ 0` DEFAULT 0; `stock_minimo ≥ 0`; `activo` |
| proveedor | PK; `rfc` UNIQUE; `razon_social`; contacto |
| producto_proveedor | PK (`producto_id`, `proveedor_id`); `costo_compra ≥ 0`; `clave_proveedor`; `es_principal` |
| cliente | PK; `rfc` UNIQUE NULL; `nombre`, `apellido`; `email` UNIQUE; `fecha_registro` |
| empleado | PK; nombre; `puesto` CHECK IN ('ADMIN', 'VENDEDOR', 'ALMACENISTA'); `activo` |
| metodo_pago | PK; `nombre` UNIQUE |
| tipo_movimiento | PK; `clave` UNIQUE; `signo` CHECK IN (1, −1) |
| venta | PK; FK `cliente_id`, `empleado_id`; `fecha`; `estado` CHECK IN (…) DEFAULT 'PENDIENTE' — **sin total** |
| detalle_venta | PK (`venta_id`, `producto_id`); `cantidad > 0`; `precio_unitario ≥ 0`; `costo_unitario ≥ 0` |
| pago | PK; FK `venta_id`, `metodo_pago_id`; `fecha`; `monto > 0`; `referencia` |
| movimiento_inventario | PK; FK `producto_id`, `tipo_movimiento_id`; `cantidad > 0`; `fecha`; FK `venta_id` NULL; FK `empleado_id` NULL; `observacion` |

Cada FK lleva su política de borrado justificada. Nota técnica: MySQL no permite `CHECK` sobre
columnas que tengan acciones `CASCADE`, y `producto_proveedor` no las usa.

## Fase 4. Normalización → `docs/05_normalizacion.md`

1. Tabla plana de ventas y sus anomalías de inserción, actualización y borrado.
2. Dependencias funcionales.
3. Paso a 1FN, 2FN y 3FN.
4. Justificaciones:
   - `precio_unitario` y `costo_unitario` son hechos históricos de la transacción.
   - `existencia` depende solo de la PK, así que no viola la 3FN. Es redundancia entre tablas,
     controlada por trigger y verificada por la vista de conciliación.
   - Por qué `total` no se almacena.

## Fase 5. DDL → `sql/01_ddl.sql`

- `DROP/CREATE DATABASE ventas_equipo5`, `utf8mb4`, InnoDB y `sql_mode` estricto en la sesión.
- Tablas con todas las restricciones de la Fase 3.
- Función `fn_total_venta(venta_id)` declarada `READS SQL DATA`, para que la acepte el binlog de MySQL 8.
- **Triggers:**
  - `movimiento` BI: fecha no futura; `SELECT … FOR UPDATE` del producto; rechaza el saldo negativo;
    exige `venta_id` en `SALIDA_VENTA` y `DEVOLUCION`.
  - `movimiento` AI: actualiza `producto.existencia`.
  - `movimiento` BU/BD: bloquean (historial inmutable).
  - `detalle` BI: la venta debe estar `PENDIENTE`.
  - `detalle` AI: inserta `SALIDA_VENTA` con `fecha = venta.fecha`.
  - `detalle` BU/BD: bloquean.
  - `pago` BI: venta no cancelada; fecha ≥ fecha de la venta; Σ pagos + monto ≤ total (`FOR UPDATE` sobre la venta).
  - `pago` AI: cambia la venta a `PAGADA` cuando se completa el total.
  - `pago` BU/BD: bloquean (pagos inmutables, RN-14; si no, un UPDATE de `monto` evadiría el tope).
  - `venta` BI: fecha no futura.
  - `venta` BU: solo transiciones de estado válidas.
  - `producto_proveedor` BI/BU: a lo más un proveedor principal por producto (RN-23).
  - `producto` BI/BU: la existencia solo cambia mediante movimientos (RN-19).
- **Estado:** implementado en `sql/01_ddl.sql` y probado en MariaDB 10.4.32. Las 62 pruebas pasan
  (ver `docs/07_evidencias.md`).
- **Procedimientos:**
  - `registrar_venta(cliente, empleado, fecha NULL→NOW(), items JSON, OUT venta_id)`: transacción;
    recorre el JSON con `JSON_LENGTH`/`JSON_EXTRACT` (portable); lee precio y costo con
    `SELECT … INTO`, **no** con `INSERT … SELECT` (así evita el error 1442); handler con ROLLBACK + RESIGNAL.
  - `cancelar_venta(venta_id, empleado, fecha)`: transacción; genera los movimientos `DEVOLUCION`.
- **Vistas:**
  - `v_existencias`: incluye una marca de bajo umbral.
  - `v_conciliacion_inventario`: saldo almacenado contra `Σ signo × cantidad`.
  - `v_venta_saldos`: total, pagado y saldo de cada venta.

## Fase 6. DML → `sql/02_dml.sql`

Volumen: 8 categorías, 30 productos, 6 proveedores, ~40 renglones en `producto_proveedor`,
20 clientes más "PÚBLICO EN GENERAL", 5 empleados, 4 métodos de pago y 5 tipos de movimiento.

- Entradas iniciales fechadas el **2026-05-25**, mediante INSERT en `movimiento` (el trigger mantiene el saldo).
- ~60 ventas con `CALL registrar_venta` entre **2026-06-01 y 2026-11-20**.
- Pagos totales y parciales, ≥2 ventas canceladas con `cancelar_venta` y algunos ajustes.
- **Datos sembrados a propósito:** ≥3 productos sin ventas, ≥3 bajo el umbral, 2–3 clientes con gasto
  destacado y ventas pendientes con saldo.
- **Estado:** implementado y cargado en MariaDB 10.4.32. Los resultados están en `docs/07_evidencias.md`.

## Fase 7. Consultas → `sql/03_consultas.sql`

Las 10 consultas de la spec, cada una con un comentario de propósito, JOIN usado y nivel. Los
parámetros van con `SET @var`. Aplican las definiciones de la Fase 0: se excluyen canceladas y la
fórmula de margen se escribe en el comentario y en el SELECT.

Consulta complementaria 11: historial de movimientos de un producto con saldo acumulado
(función de ventana, disponible en ambos motores). Cubre el RF "consultar movimientos".

**Estado:** implementado y ejecutado; las 11 consultas devuelven resultados. La consulta 7 excluye al
cliente genérico (`cliente_id = 1`).

## Fase 8. Índices → `sql/04_indices.sql` + `docs/06_indices_optimizacion.md`

Ninguno de estos índices duplica uno de FK:

| Índice | Uso |
|---|---|
| `producto(nombre)` | Consulta 1 y búsquedas |
| `venta(fecha, estado)` | Consulta 9 y reportes por periodo |
| `movimiento_inventario(producto_id, fecha)` | Historial (consulta 11) |
| `detalle_venta(producto_id, cantidad)` | Índice cubriente para las consultas 6 y 8 |

- **Evidencia:** `EXPLAIN` y `EXPLAIN FORMAT=JSON` antes y después de cada índice (en ambos motores).
  Como opcional, `EXPLAIN ANALYZE` en MySQL o `ANALYZE SELECT` en MariaDB.
- **Volumen:** `sql/04b_volumen_benchmark.sql` (opcional) genera miles de ventas con un CTE recursivo,
  solo para la evidencia de `EXPLAIN`. Después se reejecutan `01` y `02` para volver a los datos limpios.
- **Estado:** implementado. El índice cubriente de `detalle_venta` incluye `precio_unitario`
  (`producto_id, cantidad, precio_unitario`) para que la consulta 6 no lea filas. La evidencia y el
  análisis están en `docs/06_indices_optimizacion.md`.

## Fase 9. Demo y defensa

- `sql/05_demo.sql`:
  1. Catálogo y proveedor.
  2. Entrada inicial.
  3. Venta con varios productos.
  4. Pagos parcial y final (→ `PAGADA`).
  5. Verificar detalle, movimientos, conciliación y reporte.
  6. Cancelar otra venta y ver la devolución.
  7. Violaciones esperadas: stock negativo, FK inexistente, pago excedente, venta sin renglones,
     borrar un movimiento, pago a venta cancelada.
  8. Una consulta de cada nivel.
- `docs/07_evidencias.md`: salidas de ejecución en texto.
- `docs/08_guia_defensa.md`: las 12 preguntas sugeridas respondidas con este modelo.
- **Estado:** implementado. La demo se ejecutó completa: 10 de 10 violaciones rechazadas. La guía
  incluye el guion de las 6 secciones de la presentación, preguntas adicionales y un reparto por
  bloques. La presentación en diapositivas queda a cargo del equipo (fuera de alcance).

## Estructura final del repo

```
docs/  00_verificacion_plan.md … 08_guia_defensa.md
sql/   01_ddl.sql  02_dml.sql  03_consultas.sql  04_indices.sql  04b_volumen_benchmark.sql  05_demo.sql
README.md (orden de ejecución y requisitos)
```

## Verificación

- Ejecutar `01` → `05` en orden sobre MySQL 8.4 (3307) o MariaDB 10.4 (XAMPP 3306), con
  `mysql -u root -P <puerto> < sql/0X.sql`, sin errores salvo las violaciones esperadas de la demo.
- `v_conciliacion_inventario` debe mostrar diferencia 0 en todos los productos.
- Cada una de las 10 consultas devuelve filas no vacías.
- Recorrer la checklist docente al cierre de cada fase.
