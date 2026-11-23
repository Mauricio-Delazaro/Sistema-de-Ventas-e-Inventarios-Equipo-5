# Fase 3 · Modelo relacional

**Proyecto integrador — Equipo 5 · Sistema de ventas e inventarios**

Este documento traduce el modelo ER ([03_modelo_er.md](03_modelo_er.md)) a tablas. Por cada columna
indica tipo, nulabilidad, valor por defecto y restricciones. Los nombres de las restricciones son los
mismos que se usarán en `sql/01_ddl.sql`, para que el documento y el diseño físico coincidan.

**Motor:** InnoDB · **Juego de caracteres:** `utf8mb4` · **Compatibilidad:** MariaDB 10.4+ (XAMPP) y MySQL 8.0.16+.

---

## 1. Reglas de transformación aplicadas

| Elemento del ER | Transformación |
|---|---|
| Entidad | Tabla con PK entera sustituta `AUTO_INCREMENT`. |
| Relación 1:N | FK en la tabla del lado "muchos". |
| Participación total del lado "muchos" | FK `NOT NULL`. |
| Participación parcial (0..1) | FK que admite `NULL` (`movimiento_inventario.venta_id` y `empleado_id`). |
| Relación N:M | Tabla asociativa con **PK compuesta** por las dos FK y con los atributos propios de la relación. |
| Atributo derivado no almacenado (`total`) | No se crea columna. Se calcula con la función `fn_total_venta` y la vista `v_venta_saldos`. |
| Clave alterna (SKU, RFC, correo) | `UNIQUE`. |
| Dominio de valores (estado, puesto, signo) | `CHECK … IN (…)`. |

### Convención de nombres

| Prefijo | Significado | Ejemplo |
|---|---|---|
| `uq_<tabla>_<columna>` | Restricción UNIQUE | `uq_producto_sku` |
| `ck_<tabla>_<regla>` | Restricción CHECK | `ck_producto_precio` |
| `fk_<tabla>_<tabla referida>` | Llave foránea | `fk_venta_cliente` |

### Tipos de dato elegidos

| Uso | Tipo | Razón |
|---|---|---|
| PK de tablas principales | `INT UNSIGNED` | Hasta 4 mil millones de filas; no hay identificadores negativos. |
| PK de catálogos pequeños | `TINYINT UNSIGNED` | Pocos valores (métodos de pago, tipos de movimiento). |
| Importes | `DECIMAL(10,2)` | Exactitud decimal en dinero; `FLOAT` introduce errores de redondeo. |
| Cantidades y existencia | `INT` **con signo** | Se opera `existencia + signo × cantidad`. Con `UNSIGNED`, una resta intermedia daría error de rango. El dominio lo controla `CHECK`. |
| Fechas de transacción | `DATETIME` | Fecha y hora de la venta, el pago y el movimiento. |
| Banderas | `TINYINT(1)` + `CHECK IN (0,1)` | Equivale a `BOOLEAN` y no admite otros valores. |
| Estados y dominios cortos | `VARCHAR` + `CHECK IN` | Funciona igual en ambos motores; un `ENUM` acepta `''` en modo no estricto. |

---

## 2. Esquema relacional

Notación: **PK** subrayada como `_columna_`; FK con `→ tabla`.

```
categoria            (_categoria_id_, nombre, descripcion)
producto             (_producto_id_, sku, nombre, categoria_id → categoria, precio_venta, costo,
                      existencia, stock_minimo, activo)
proveedor            (_proveedor_id_, rfc, razon_social, telefono, email)
producto_proveedor   (_producto_id_ → producto, _proveedor_id_ → proveedor, costo_compra,
                      clave_proveedor, es_principal)
cliente              (_cliente_id_, rfc, nombre, apellido, email, telefono, fecha_registro)
empleado             (_empleado_id_, nombre, apellido, puesto, activo)
metodo_pago          (_metodo_pago_id_, nombre)
tipo_movimiento      (_tipo_movimiento_id_, clave, descripcion, signo)
venta                (_venta_id_, cliente_id → cliente, empleado_id → empleado, fecha, estado)
detalle_venta        (_venta_id_ → venta, _producto_id_ → producto, cantidad, precio_unitario,
                      costo_unitario)
pago                 (_pago_id_, venta_id → venta, metodo_pago_id → metodo_pago, fecha, monto,
                      referencia)
movimiento_inventario(_movimiento_id_, producto_id → producto, tipo_movimiento_id → tipo_movimiento,
                      cantidad, fecha, venta_id → venta [NULL], empleado_id → empleado [NULL],
                      observacion)
```

---

## 3. Definición de tablas

Columnas: **N** = admite NULL.

### 3.1 `categoria`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| categoria_id | INT UNSIGNED | No | AUTO_INCREMENT | PK |
| nombre | VARCHAR(60) | No | | `uq_categoria_nombre` |
| descripcion | VARCHAR(255) | Sí | | |

### 3.2 `producto`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| producto_id | INT UNSIGNED | No | AUTO_INCREMENT | PK |
| sku | VARCHAR(20) | No | | `uq_producto_sku` |
| nombre | VARCHAR(120) | No | | |
| categoria_id | INT UNSIGNED | No | | `fk_producto_categoria` |
| precio_venta | DECIMAL(10,2) | No | | `ck_producto_precio`: `precio_venta >= 0` |
| costo | DECIMAL(10,2) | No | | `ck_producto_costo`: `costo >= 0` |
| existencia | INT | No | 0 | `ck_producto_existencia`: `existencia >= 0` |
| stock_minimo | INT | No | 0 | `ck_producto_stock_minimo`: `stock_minimo >= 0` |
| activo | TINYINT(1) | No | 1 | `ck_producto_activo`: `activo IN (0,1)` |

Reglas: RN-01, RN-02, RN-03, RN-05, RN-16.

`existencia` **no se escribe directamente**. La mantiene `trg_movimiento_ai`. No se exige
`precio_venta >= costo`, porque vender por debajo del costo (liquidación) es una decisión válida
del negocio y se refleja como margen negativo.

### 3.3 `proveedor`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| proveedor_id | INT UNSIGNED | No | AUTO_INCREMENT | PK |
| rfc | VARCHAR(13) | No | | `uq_proveedor_rfc`; `ck_proveedor_rfc`: `CHAR_LENGTH(rfc) IN (12,13)` |
| razon_social | VARCHAR(120) | No | | |
| telefono | VARCHAR(20) | Sí | | |
| email | VARCHAR(120) | Sí | | `ck_proveedor_email`: `email LIKE '%_@_%._%'` |

### 3.4 `producto_proveedor` (asociativa N:M)

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| producto_id | INT UNSIGNED | No | | PK (1/2), `fk_prodprov_producto` |
| proveedor_id | INT UNSIGNED | No | | PK (2/2), `fk_prodprov_proveedor` |
| costo_compra | DECIMAL(10,2) | No | | `ck_prodprov_costo`: `costo_compra >= 0` |
| clave_proveedor | VARCHAR(30) | Sí | | Código del artículo en el catálogo del proveedor |
| es_principal | TINYINT(1) | No | 0 | `ck_prodprov_principal`: `es_principal IN (0,1)` |

Reglas: RN-04 y RN-23 (a lo más un proveedor principal por producto, con `trg_producto_proveedor_bi` y `_bu`).

> MySQL no permite `CHECK` sobre columnas usadas en una FK con `CASCADE`. Por eso
> `producto_id` y `proveedor_id` no llevan `CHECK`.
>
> RN-23 no puede ser un índice `UNIQUE` parcial: MySQL no los tiene y una columna generada no admite
> FK con `CASCADE`. Por eso se valida con un trigger.

### 3.5 `cliente`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| cliente_id | INT UNSIGNED | No | AUTO_INCREMENT | PK |
| rfc | VARCHAR(13) | Sí | | `uq_cliente_rfc`; `ck_cliente_rfc`: `rfc IS NULL OR CHAR_LENGTH(rfc) IN (12,13)` |
| nombre | VARCHAR(60) | No | | |
| apellido | VARCHAR(60) | Sí | | NULL en el cliente genérico y en las personas morales |
| email | VARCHAR(120) | Sí | | `uq_cliente_email`; `ck_cliente_email`: `email IS NULL OR email LIKE '%_@_%._%'` |
| telefono | VARCHAR(20) | Sí | | |
| fecha_registro | DATETIME | No | CURRENT_TIMESTAMP | |

`UNIQUE` admite varios `NULL` en ambos motores, así que los clientes sin RFC o sin correo no chocan
entre sí. El registro `cliente_id = 1` es "PÚBLICO EN GENERAL" (RN-06).

### 3.6 `empleado`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| empleado_id | INT UNSIGNED | No | AUTO_INCREMENT | PK |
| nombre | VARCHAR(60) | No | | |
| apellido | VARCHAR(60) | No | | |
| puesto | VARCHAR(12) | No | | `ck_empleado_puesto`: `IN ('ADMIN','VENDEDOR','ALMACENISTA')` |
| activo | TINYINT(1) | No | 1 | `ck_empleado_activo`: `activo IN (0,1)` |

### 3.7 `metodo_pago`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| metodo_pago_id | TINYINT UNSIGNED | No | AUTO_INCREMENT | PK |
| nombre | VARCHAR(30) | No | | `uq_metodo_pago_nombre` |

### 3.8 `tipo_movimiento`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| tipo_movimiento_id | TINYINT UNSIGNED | No | AUTO_INCREMENT | PK |
| clave | VARCHAR(20) | No | | `uq_tipo_movimiento_clave` |
| descripcion | VARCHAR(100) | No | | |
| signo | TINYINT | No | | `ck_tipo_movimiento_signo`: `signo IN (1,-1)` |

Valores fijos (los carga `02_dml.sql`):

| clave | signo |
|---|---|
| ENTRADA | +1 |
| SALIDA_VENTA | −1 |
| AJUSTE_ENTRADA | +1 |
| AJUSTE_SALIDA | −1 |
| DEVOLUCION | +1 |

### 3.9 `venta`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| venta_id | INT UNSIGNED | No | AUTO_INCREMENT | PK |
| cliente_id | INT UNSIGNED | No | | `fk_venta_cliente` |
| empleado_id | INT UNSIGNED | No | | `fk_venta_empleado` |
| fecha | DATETIME | No | CURRENT_TIMESTAMP | No futura (`trg_venta_bi`) |
| estado | VARCHAR(10) | No | 'PENDIENTE' | `ck_venta_estado`: `IN ('PENDIENTE','PAGADA','CANCELADA')`; transiciones con `trg_venta_bu` |

Reglas: RN-06, RN-12, RN-20. No hay columna `total` (RN-10).

### 3.10 `detalle_venta` (asociativa N:M)

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| venta_id | INT UNSIGNED | No | | PK (1/2), `fk_detalle_venta` |
| producto_id | INT UNSIGNED | No | | PK (2/2), `fk_detalle_producto` |
| cantidad | INT | No | | `ck_detalle_cantidad`: `cantidad > 0` |
| precio_unitario | DECIMAL(10,2) | No | | `ck_detalle_precio`: `precio_unitario >= 0` |
| costo_unitario | DECIMAL(10,2) | No | | `ck_detalle_costo`: `costo_unitario >= 0` |

Reglas: RN-07, RN-08, RN-09, RN-11.

La PK (`venta_id`, `producto_id`) impide que el mismo producto aparezca dos veces en una venta: si se
venden más piezas, se aumenta la cantidad del renglón.

### 3.11 `pago`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| pago_id | INT UNSIGNED | No | AUTO_INCREMENT | PK |
| venta_id | INT UNSIGNED | No | | `fk_pago_venta` |
| metodo_pago_id | TINYINT UNSIGNED | No | | `fk_pago_metodo` |
| fecha | DATETIME | No | CURRENT_TIMESTAMP | No futura y ≥ fecha de la venta (`trg_pago_bi`) |
| monto | DECIMAL(10,2) | No | | `ck_pago_monto`: `monto > 0`; Σ ≤ total (`trg_pago_bi`) |
| referencia | VARCHAR(50) | Sí | | Folio de la tarjeta o de la transferencia |

Reglas: RN-13, RN-14, RN-20.

### 3.12 `movimiento_inventario`

| Columna | Tipo | N | Default | Restricción |
|---|---|---|---|---|
| movimiento_id | INT UNSIGNED | No | AUTO_INCREMENT | PK |
| producto_id | INT UNSIGNED | No | | `fk_mov_producto` |
| tipo_movimiento_id | TINYINT UNSIGNED | No | | `fk_mov_tipo` |
| cantidad | INT | No | | `ck_mov_cantidad`: `cantidad > 0` |
| fecha | DATETIME | No | CURRENT_TIMESTAMP | No futura (`trg_movimiento_bi`) |
| venta_id | INT UNSIGNED | **Sí** | | `fk_mov_venta`. Obligatoria solo para `SALIDA_VENTA` y `DEVOLUCION` (`trg_movimiento_bi`) |
| empleado_id | INT UNSIGNED | **Sí** | | `fk_mov_empleado` |
| observacion | VARCHAR(255) | Sí | | Motivo del ajuste o de la entrada |

Reglas: RN-15 a RN-19.

---

## 4. Llaves foráneas y política de borrado

Aplica a todas: **`ON UPDATE RESTRICT`**. Las PK son sustitutas y nunca cambian, así que no hay nada
que propagar.

| FK | Columna → referencia | ON DELETE | Justificación |
|---|---|---|---|
| `fk_producto_categoria` | producto.categoria_id → categoria | RESTRICT | No se puede borrar una categoría con productos, porque quedarían huérfanos (RN-01). Primero se reasignan. |
| `fk_prodprov_producto` | producto_proveedor.producto_id → producto | **CASCADE** | La asociación solo tiene sentido si existe el producto. No tiene historial transaccional. En la práctica solo se borra un producto sin historial, porque las demás FK lo impiden. |
| `fk_prodprov_proveedor` | producto_proveedor.proveedor_id → proveedor | **CASCADE** | Al dar de baja un proveedor desaparecen sus ofertas. Ningún dato histórico apunta al proveedor. |
| `fk_venta_cliente` | venta.cliente_id → cliente | RESTRICT | Un cliente con ventas no se borra, porque se perdería a quién se le vendió. |
| `fk_venta_empleado` | venta.empleado_id → empleado | RESTRICT | Se perdería quién registró la venta. Al empleado se le da de baja con `activo = 0`. |
| `fk_detalle_venta` | detalle_venta.venta_id → venta | RESTRICT | **Las ventas no se borran, se cancelan** (RN-12). Con CASCADE, los renglones se borrarían **sin disparar triggers** y el inventario no se revertiría. |
| `fk_detalle_producto` | detalle_venta.producto_id → producto | RESTRICT | Un producto vendido no se borra (RN-05); se usa `activo = 0`. |
| `fk_pago_venta` | pago.venta_id → venta | RESTRICT | Los pagos son evidencia de cobro (RN-14). |
| `fk_pago_metodo` | pago.metodo_pago_id → metodo_pago | RESTRICT | Los pagos históricos perderían su método. |
| `fk_mov_producto` | movimiento_inventario.producto_id → producto | RESTRICT | El historial es inmutable (RN-17). |
| `fk_mov_tipo` | movimiento_inventario.tipo_movimiento_id → tipo_movimiento | RESTRICT | Sin el tipo se pierde el signo del movimiento y no se puede reconstruir el saldo (RN-19). |
| `fk_mov_venta` | movimiento_inventario.venta_id → venta | RESTRICT | Se perdería la trazabilidad de la salida (RN-18). |
| `fk_mov_empleado` | movimiento_inventario.empleado_id → empleado | RESTRICT | Se perdería quién capturó el movimiento. |

### ¿Qué ocurre al eliminar un registro relacionado? (pregunta de defensa)

- **Borrar un producto con ventas o movimientos:** error 1451 (*Cannot delete or update a parent
  row*). La forma correcta es `UPDATE producto SET activo = 0`.
- **Borrar un producto recién creado sin historial:** se permite, y sus filas de
  `producto_proveedor` se eliminan en cascada.
- **Borrar una venta:** error 1451 si tiene renglones, pagos o movimientos. Una venta se cancela con
  `cancelar_venta`, que repone el stock mediante movimientos `DEVOLUCION`.
- **Borrar un movimiento:** `trg_movimiento_bd` lo rechaza siempre (RN-17).

**Por qué no se usa `CASCADE` en las transacciones:** en MySQL y en MariaDB, las acciones
referenciales en cascada **no activan triggers**. Un borrado en cascada de `detalle_venta` o de
`movimiento_inventario` dejaría `producto.existencia` desincronizada sin ningún error.

---

## 5. Índices que el motor crea automáticamente

Sirven de punto de partida para la Fase 8, donde los índices adicionales deben ser distintos de estos.

| Tabla | Índice implícito | Origen |
|---|---|---|
| Todas | PRIMARY | PK |
| categoria | `uq_categoria_nombre` | UNIQUE |
| producto | `uq_producto_sku`, `fk_producto_categoria` (categoria_id) | UNIQUE, FK |
| proveedor | `uq_proveedor_rfc` | UNIQUE |
| producto_proveedor | PRIMARY (producto_id, proveedor_id) cubre la FK de producto; `fk_prodprov_proveedor` (proveedor_id) | PK, FK |
| cliente | `uq_cliente_rfc`, `uq_cliente_email` | UNIQUE |
| metodo_pago / tipo_movimiento | `uq_metodo_pago_nombre`, `uq_tipo_movimiento_clave` | UNIQUE |
| venta | `fk_venta_cliente` (cliente_id), `fk_venta_empleado` (empleado_id) | FK |
| detalle_venta | PRIMARY (venta_id, producto_id) cubre la FK de venta; `fk_detalle_producto` (producto_id) | PK, FK |
| pago | `fk_pago_venta` (venta_id), `fk_pago_metodo` (metodo_pago_id) | FK |
| movimiento_inventario | `fk_mov_producto`, `fk_mov_tipo`, `fk_mov_venta`, `fk_mov_empleado` | FK |

---

## 6. Restricciones que no son declarativas

Estas reglas necesitan consultar otras filas o tablas, o la fecha actual. Un `CHECK` no puede hacerlo,
así que se implementan en la Fase 5:

| Regla | Objeto |
|---|---|
| RN-07 Venta con ≥1 renglón | `registrar_venta` |
| RN-11 Detalle inmutable y solo en ventas `PENDIENTE` | `trg_detalle_venta_bi`, `_bu`, `_bd` |
| RN-12 Transiciones de estado | `trg_venta_bu`, `trg_pago_ai`, `cancelar_venta` |
| RN-13 Σ pagos ≤ total; sin pagos a canceladas; fecha del pago ≥ fecha de la venta | `trg_pago_bi` |
| RN-14 Pagos inmutables | `trg_pago_bu`, `trg_pago_bd` |
| RN-16 Existencia no negativa (primera defensa) | `trg_movimiento_bi` |
| RN-17 Historial inmutable | `trg_movimiento_bu`, `trg_movimiento_bd` |
| RN-18 `venta_id` obligatoria en salidas por venta y devoluciones | `trg_movimiento_bi` |
| RN-19 Saldo = Σ movimientos | `trg_movimiento_ai`, `trg_producto_bi`, `trg_producto_bu`, `v_conciliacion_inventario` |
| RN-20 Fechas no futuras | `trg_venta_bi`, `trg_pago_bi`, `trg_movimiento_bi` |
| RN-23 Un solo proveedor principal por producto | `trg_producto_proveedor_bi`, `_bu` |
