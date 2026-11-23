# Fase 4 · Normalización hasta 3FN

**Proyecto integrador — Equipo 5 · Sistema de ventas e inventarios**

El punto de partida es la hoja de cálculo con la que Suministros Altamira controla hoy sus ventas
(ver el problema en [02_analisis.md](02_analisis.md)). Se normaliza paso a paso hasta llegar al
modelo relacional de la Fase 3 ([04_modelo_relacional.md](04_modelo_relacional.md)).

---

## 1. Tabla plana de partida (forma no normalizada, 0FN)

`VENTAS_PLANILLA`: una fila por venta, tal como está en la hoja de cálculo.

| folio | fecha | cliente | rfc_cliente | email_cliente | vendedor | puesto_vendedor | productos | proveedores | pagos | total | estado |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 101 | 2026-06-03 10:15 | Constructora Robles | CRO010101AB2 | compras@robles.mx | Ana Pérez | VENDEDOR | HM-001 Martillo 16 oz (Herr. manual) ×2 @ $150; PL-004 Llave de paso ½" (Plomería) ×3 @ $95 | HM-001: Truper Dist. (TDI990101AA1), Ferremayoreo (FMA850505BB2); PL-004: Hidrotec (HID000303CC3) | $300 efectivo 06-03; $285 transferencia 06-10 | $585 | PAGADA |
| 102 | 2026-06-04 17:40 | Público en general | — | — | Luis Gómez | VENDEDOR | HM-001 Martillo 16 oz (Herr. manual) ×1 @ $150 | HM-001: Truper Dist. (TDI990101AA1), Ferremayoreo (FMA850505BB2) | $150 tarjeta 06-04 | $150 | PAGADA |
| 117 | 2026-07-12 12:05 | Constructora Robles | CRO010101AB2 | compras@robles.mx | Ana Pérez | VENDEDOR | HM-001 Martillo 16 oz (Herr. manual) ×4 @ **$165**; PI-002 Pintura vinílica 19 L (Pinturas) ×1 @ $1,250 | HM-001: …; PI-002: Comex Norte (CNO111111DD4) | $500 efectivo 07-12 | $1,910 | PENDIENTE |

La existencia de cada producto está en **otra** hoja, con una sola celda de "saldo actual" que se
corrige a mano.

---

## 2. Anomalías de la tabla plana

| Tipo | Ejemplo concreto |
|---|---|
| **Inserción** | No se puede registrar un producto nuevo, un cliente nuevo ni un proveedor nuevo hasta que haya una venta que los incluya. Un producto recién comprado que todavía no se vende "no existe". |
| **Actualización** | Si Constructora Robles cambia su correo, hay que corregirlo en **todas** sus ventas. Si se olvida una, el cliente tiene dos correos. Lo mismo pasa al renombrar la categoría "Herr. manual", al cambiar el puesto de Ana Pérez o el teléfono de un proveedor. |
| **Actualización (dato derivado)** | `total` se escribe a mano. Si se corrige una cantidad y no el total, la venta se contradice a sí misma. |
| **Borrado** | Si se elimina la venta 117, que es la única con PI-002, se pierde que existe la pintura vinílica, su categoría y que la surte Comex Norte. |
| **Atomicidad** | `productos`, `proveedores` y `pagos` son listas dentro de una celda. No se puede sumar cuántos martillos se vendieron ni filtrar los pagos en efectivo sin descomponer texto. |
| **Historial** | Al guardar solo el saldo de existencia no se puede saber por qué cambió. No hay entradas, salidas ni ajustes. |

---

## 3. Dependencias funcionales (DF)

Se identifican sobre los atributos atómicos que contiene la tabla plana.

**Venta**
- DF1: `folio → fecha, rfc_cliente, vendedor, estado`
- DF2: `rfc_cliente → cliente, email_cliente` (y `email_cliente → rfc_cliente`: ambos identifican al cliente)
- DF3: `vendedor → puesto_vendedor`

**Producto**
- DF4: `sku → nombre_producto, categoria, precio_catalogo, costo_catalogo, existencia, stock_minimo`
- DF5: `categoria → descripcion_categoria`

**Renglón de venta**
- DF6: `(folio, sku) → cantidad, precio_unitario, costo_unitario`

**Proveedor y su oferta**
- DF7: `rfc_proveedor → razon_social, telefono_proveedor`
- DF8: `(sku, rfc_proveedor) → costo_compra, clave_proveedor, es_principal`

**Pago**
- DF9: `(folio, num_pago) → fecha_pago, monto, metodo_pago`

**Dato derivado**
- `folio → total`, donde `total = Σ cantidad × precio_unitario` de los renglones del folio. Se
  calcula a partir de otras filas, así que no es un hecho independiente.

**Dependencias que NO existen** (son las que justifican el diseño):
- `sku ↛ precio_unitario`. El martillo HM-001 se vendió a $150 en la venta 101 y a $165 en la 117.
  El precio aplicado depende de la venta **y** del producto, no solo del producto.
- `sku ↛ costo_unitario`, por el mismo razonamiento.
- `sku ↛ rfc_proveedor`. Un producto tiene varios proveedores (relación N:M).
- `folio ↛ metodo_pago`. Una venta tiene varios pagos con métodos distintos.

---

## 4. Primera forma normal (1FN)

**Regla:** todos los atributos son atómicos y no hay grupos repetitivos. Cada relación tiene clave.

**Pasos:**
1. La celda `productos` se convierte en **una fila por producto vendido**, con columnas atómicas:
   `sku`, `nombre_producto`, `categoria`, `cantidad`, `precio_unitario`.
2. `pagos` y `proveedores` también son grupos repetitivos, pero **independientes** de los productos
   vendidos. Si se aplanaran en la misma tabla, cada renglón se combinaría con cada pago y con cada
   proveedor (producto cartesiano: 2 renglones × 2 pagos × 3 proveedores = 12 filas para la venta
   101). Eso es una dependencia multivaluada. Por eso cada grupo pasa a **su propia relación**
   desde esta etapa.
3. Las existencias se separan de las ventas. Como el escenario exige historial (RN-15), cada
   cambio de saldo se registra como un hecho atómico.

**Resultado en 1FN:**

```
VENTA_LINEA        (folio, sku, fecha, rfc_cliente, cliente, email_cliente, vendedor, puesto_vendedor,
                    estado, nombre_producto, categoria, descripcion_categoria, precio_catalogo,
                    costo_catalogo, existencia, stock_minimo, cantidad, precio_unitario, costo_unitario)
                    PK = (folio, sku)

PAGO_VENTA         (folio, num_pago, fecha_pago, monto, metodo_pago)
                    PK = (folio, num_pago)

OFERTA_PROVEEDOR   (sku, rfc_proveedor, razon_social, telefono_proveedor, costo_compra,
                    clave_proveedor, es_principal)
                    PK = (sku, rfc_proveedor)

MOVIMIENTO         (num_movimiento, sku, tipo, signo, cantidad, fecha, folio, capturista)
                    PK = num_movimiento
```

`total` se elimina: se puede obtener de `VENTA_LINEA`, y guardarlo repetiría información que ya
está ahí.

**Anomalías que siguen:** en `VENTA_LINEA`, los datos del cliente se repiten en cada renglón de la
venta y los del producto en cada venta donde aparece. Siguen las anomalías de actualización y
borrado.

---

## 5. Segunda forma normal (2FN)

**Regla:** está en 1FN y ningún atributo no clave depende de **una parte** de una clave compuesta.

**Dependencias parciales encontradas:**

| Relación | Parte de la clave | Atributos que dependen solo de esa parte |
|---|---|---|
| VENTA_LINEA (folio, sku) | `folio` | fecha, rfc_cliente, cliente, email_cliente, vendedor, puesto_vendedor, estado (DF1–DF3) |
| VENTA_LINEA (folio, sku) | `sku` | nombre_producto, categoria, descripcion_categoria, precio_catalogo, costo_catalogo, existencia, stock_minimo (DF4–DF5) |
| OFERTA_PROVEEDOR (sku, rfc_proveedor) | `rfc_proveedor` | razon_social, telefono_proveedor (DF7) |

`PAGO_VENTA` no tiene dependencias parciales: `fecha_pago`, `monto` y `metodo_pago` describen al pago
`num_pago` **de ese** folio. `MOVIMIENTO` tiene clave simple, así que ya está en 2FN.

**Descomposición:**

```
VENTA            (folio, fecha, rfc_cliente, cliente, email_cliente, vendedor, puesto_vendedor, estado)
PRODUCTO         (sku, nombre_producto, categoria, descripcion_categoria, precio_catalogo,
                  costo_catalogo, existencia, stock_minimo)
DETALLE_VENTA    (folio, sku, cantidad, precio_unitario, costo_unitario)
PAGO_VENTA       (folio, num_pago, fecha_pago, monto, metodo_pago)
PROVEEDOR        (rfc_proveedor, razon_social, telefono_proveedor)
OFERTA_PROVEEDOR (sku, rfc_proveedor, costo_compra, clave_proveedor, es_principal)
MOVIMIENTO       (num_movimiento, sku, tipo, signo, cantidad, fecha, folio, capturista)
```

**Por qué `precio_unitario` y `costo_unitario` se quedan en `DETALLE_VENTA`:** no dependen
parcialmente de `sku`, porque `sku ↛ precio_unitario` (sección 3). Dependen de la clave completa
`(folio, sku)`.

**Anomalías resueltas:** un producto o un proveedor ya se pueden registrar sin ventas (inserción),
y borrar una venta ya no borra el producto (borrado).

**Anomalías que siguen:** en `VENTA`, el correo del cliente se repite en cada venta de ese cliente.
En `PRODUCTO`, la descripción de la categoría se repite en cada producto.

---

## 6. Tercera forma normal (3FN)

**Regla:** está en 2FN y ningún atributo no clave depende de otro atributo no clave (no hay
dependencias **transitivas**).

**Dependencias transitivas encontradas:**

| Relación | Cadena transitiva | Se extrae a |
|---|---|---|
| VENTA | `folio → rfc_cliente → cliente, email_cliente` | **CLIENTE** (rfc_cliente, cliente, email_cliente) |
| VENTA | `folio → vendedor → puesto_vendedor` | **EMPLEADO** (empleado, nombre, puesto) |
| PRODUCTO | `sku → categoria → descripcion_categoria` | **CATEGORIA** (categoria, descripcion) |
| MOVIMIENTO | `num_movimiento → tipo → signo` | **TIPO_MOVIMIENTO** (tipo, descripcion, signo) |
| MOVIMIENTO | `num_movimiento → capturista → (datos del empleado)` | **EMPLEADO** (la misma relación) |

Además, `metodo_pago` en `PAGO_VENTA` pasa a la relación **METODO_PAGO**. Esto no se debe a una
dependencia transitiva (el método no tiene otros atributos), sino a **control de dominio**: evita
variantes como "Efectivo", "efectivo" y "EFECTIVO". Se documenta como decisión de diseño, no como
paso obligatorio de la 3FN.

**Esquema en 3FN:**

```
CATEGORIA        (categoria, descripcion)
PRODUCTO         (sku, nombre_producto, categoria→, precio_catalogo, costo_catalogo, existencia,
                  stock_minimo)
PROVEEDOR        (rfc_proveedor, razon_social, telefono_proveedor)
OFERTA_PROVEEDOR (sku→, rfc_proveedor→, costo_compra, clave_proveedor, es_principal)
CLIENTE          (rfc_cliente, nombre, email)
EMPLEADO         (empleado, nombre, puesto)
VENTA            (folio, fecha, rfc_cliente→, empleado→, estado)
DETALLE_VENTA    (folio→, sku→, cantidad, precio_unitario, costo_unitario)
METODO_PAGO      (metodo_pago)
PAGO_VENTA       (folio→, num_pago, fecha_pago, monto, metodo_pago→)
TIPO_MOVIMIENTO  (tipo, descripcion, signo)
MOVIMIENTO       (num_movimiento, sku→, tipo→, cantidad, fecha, folio→, empleado→)
```

### Paso final: claves sustitutas

En el modelo físico se sustituyen las claves naturales por enteros (`producto_id`, `cliente_id`,
`pago_id`…), y las naturales se conservan como `UNIQUE` (`sku`, `rfc`, `email`). Esto **no cambia la
forma normal**: solo agrega una clave candidata más. Las razones son tres:
- `rfc_cliente` no siempre existe (público en general);
- un SKU o un RFC pueden corregirse, y la PK sustituta nunca cambia;
- las FK enteras son más cortas.

`PAGO_VENTA (folio, num_pago)` pasa a `pago (pago_id)` con FK `venta_id`, que es equivalente.

| Relación 3FN | Tabla final (Fase 3) |
|---|---|
| CATEGORIA | `categoria` |
| PRODUCTO | `producto` |
| PROVEEDOR | `proveedor` |
| OFERTA_PROVEEDOR | `producto_proveedor` |
| CLIENTE | `cliente` |
| EMPLEADO | `empleado` |
| VENTA | `venta` |
| DETALLE_VENTA | `detalle_venta` |
| METODO_PAGO | `metodo_pago` |
| PAGO_VENTA | `pago` |
| TIPO_MOVIMIENTO | `tipo_movimiento` |
| MOVIMIENTO | `movimiento_inventario` |

### Verificación adicional: forma normal de Boyce-Codd (FNBC)

En cada tabla final, todo determinante es clave candidata:
- en `producto`, `producto_id` y `sku`;
- en `cliente`, `cliente_id`, `rfc` y `email`;
- en `proveedor`, `proveedor_id` y `rfc`;
- en las asociativas, su clave compuesta.

No queda ninguna DF cuyo determinante no sea clave, así que el esquema también cumple **FNBC**.

---

## 7. Justificaciones para la defensa

### 7.1 ¿Por qué `precio_unitario` en el detalle no viola la 3FN?

Porque **no es el precio del producto**. Es el precio **pactado en esa venta**, un hecho histórico
de la transacción:
- La DF que lo determina es `(venta_id, producto_id) → precio_unitario`, es decir, la clave completa
  del detalle. Está en 2FN.
- No depende de ningún atributo no clave, así que está en 3FN.
- `producto.precio_venta` representa otro hecho: el precio **vigente** hoy. Los dos solo coinciden en
  el instante de la venta. Después, el catálogo cambia (HM-001 pasó de $150 a $165) y el detalle
  conserva el valor original (RN-09).

Si se eliminara `precio_unitario` y se usara el precio de catálogo, cada cambio de precio
**reescribiría** retroactivamente los importes de todas las ventas pasadas. Eso es una anomalía de
actualización, no una mejora. Con `costo_unitario` pasa lo mismo, y es lo que permite calcular el
margen histórico real (consulta 10).

### 7.2 ¿Por qué `producto.existencia` no viola la 3FN?

- La DF `producto_id → existencia` depende **directamente de la clave**. Ningún otro atributo de
  `producto` la determina, así que no hay dependencia parcial ni transitiva y **la 3FN se cumple**.
- Lo que sí hay es **redundancia entre tablas**: el saldo se puede calcular como
  `Σ signo × cantidad` de `movimiento_inventario`. Las formas normales analizan dependencias
  **dentro** de una relación; un agregado de otra tabla no está en su alcance.
- **Por qué se acepta esta redundancia (controlada):**
  1. **Rendimiento:** la validación de stock (RN-16) y la consulta 4 leen una columna en lugar de
     sumar todo el historial en cada venta.
  2. **Consistencia garantizada:** solo la modifica `trg_movimiento_ai`, en la misma transacción que
     el movimiento. Si el movimiento se revierte, el saldo también.
  3. **Verificable:** `v_conciliacion_inventario` compara el saldo con el historial y debe mostrar
     diferencia 0 (RN-19).
- El historial sigue siendo la **fuente de verdad**, como pide el escenario: el saldo se deriva del
  historial y no al revés.

### 7.3 ¿Por qué `venta.total` NO se almacena?

Es el mismo caso que la existencia, pero aquí el beneficio de guardarlo no compensa el riesgo:
- calcular el total de una venta suma pocos renglones (barato);
- si se guardara, cualquier cambio de detalle exigiría otro trigger para mantenerlo, y otra
  oportunidad de inconsistencia;
- sin el total almacenado, la consulta 5 ("calcular importe total de una venta") se resuelve de
  verdad desde el detalle.

### 7.4 ¿Qué anomalía evita cada tabla?

| Tabla | Anomalía que evita |
|---|---|
| `categoria` | Actualización: renombrar una categoría en un solo lugar. Inserción: crear una categoría sin productos. |
| `cliente` | Actualización: correo o RFC repetidos en cada venta. Borrado: perder al cliente al borrar su venta. |
| `empleado` | Actualización: el puesto repetido en cada venta. |
| `producto` | Inserción: un producto sin ventas. Borrado: perder el producto al borrar su única venta. |
| `proveedor` + `producto_proveedor` | Atomicidad: lista de proveedores en una celda. Actualización: datos del proveedor repetidos por producto. |
| `detalle_venta` | Atomicidad: lista de productos en una celda. Conserva el precio histórico. |
| `pago` + `metodo_pago` | Atomicidad: lista de pagos en una celda. Dominio: métodos escritos de formas distintas. |
| `movimiento_inventario` + `tipo_movimiento` | Historial: el saldo deja de ser un dato sin respaldo. Transitiva: el signo depende del tipo. |
