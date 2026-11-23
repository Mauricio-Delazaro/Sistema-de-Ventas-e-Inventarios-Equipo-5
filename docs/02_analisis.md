# Fase 1 · Documento de análisis

**Proyecto integrador — Equipo 5 · Sistema de ventas e inventarios**

---

## 1. Contexto de la empresa (ficticia)

**Suministros Altamira, S.A. de C.V.** es una comercializadora de ferretería y suministros para la
construcción con una sola sucursal y un almacén. Vende al mostrador al público en general y a
clientes frecuentes (contratistas, talleres y pequeñas constructoras). Estos clientes con frecuencia
pagan en parcialidades. Compra su mercancía a varios proveedores, y un mismo artículo puede
surtirlo más de uno.

Maneja ocho líneas de producto: herramienta manual, herramienta eléctrica, plomería, material
eléctrico, pinturas, tornillería y fijación, jardinería y seguridad industrial.

## 2. Planteamiento del problema

Hoy la empresa controla ventas e inventario con hojas de cálculo separadas. Esto provoca:

1. **Precios históricos perdidos.** Cuando cambia el precio de un producto se sobrescribe la celda,
   y ya no se puede saber a qué precio se vendió antes ni calcular el margen real de ventas pasadas.
2. **Existencias sin respaldo.** Solo se guarda el saldo actual. Cuando el conteo físico no coincide
   no hay historial que explique la diferencia (qué entró, qué salió, cuándo y por qué).
3. **Inventario negativo.** Se registran ventas de artículos que ya no hay, y el saldo queda en negativo.
4. **Pagos parciales sin control.** No se sabe cuánto debe cada venta ni se evita cobrar de más.
5. **Datos duplicados e inconsistentes.** El nombre de la categoría o del cliente se escribe a mano en
   cada renglón, con variantes ortográficas.
6. **Sin reportes confiables.** Los productos más vendidos, los mejores clientes, las ventas mensuales
   y el margen por categoría se calculan a mano.

**Objetivo:** diseñar e implementar una base de datos relacional normalizada (3FN) que registre
ventas detalladas por producto con su precio y costo históricos, controle los pagos y mantenga un
**historial trazable e inmutable** de entradas y salidas de inventario. La base de datos debe hacer
cumplir por sí misma las reglas críticas, sin depender de que la aplicación las respete.

## 3. Alcance

**Dentro del alcance**
- Catálogos de categorías, productos, proveedores, clientes, empleados, métodos de pago y tipos de movimiento.
- Relación producto–proveedor con costo de compra y proveedor principal.
- Ventas con uno o más renglones, pagos parciales y cancelación.
- Movimientos de inventario: entradas, salidas por venta, ajustes y devoluciones por cancelación.
- Consultas operativas y reportes, entre ellos el margen estimado.

**Fuera del alcance**
- Órdenes de compra a proveedores. Las compras se registran solo como movimientos `ENTRADA`.
- Facturación electrónica (CFDI), impuestos desglosados y descuentos.
- Reembolsos y devoluciones parciales de ventas ya pagadas.
- Varios almacenes o sucursales.
- Usuarios, contraseñas y permisos de la aplicación.

**Supuestos**
- Moneda: pesos mexicanos (MXN), con dos decimales. Los precios incluyen IVA.
- El precio aplicado en una venta es el precio de catálogo vigente en el momento de la venta.
- Un solo almacén, así que la existencia es un único saldo por producto.

## 4. Actores

| Actor | Tipo | Responsabilidad en el sistema |
|---|---|---|
| Administrador de catálogo | Interno (empleado, puesto `ADMIN`) | Da de alta y mantiene categorías, productos (precio, costo, stock mínimo), proveedores y la relación producto–proveedor. Consulta reportes. |
| Vendedor / cajero | Interno (`VENDEDOR`) | Registra clientes, ventas y pagos. Cancela ventas pendientes. Consulta existencias y saldos. |
| Almacenista | Interno (`ALMACENISTA`) | Registra entradas de mercancía y ajustes de inventario. Consulta el historial y los productos bajo umbral. |
| Cliente | Externo | Compra productos y paga en una o varias exhibiciones. No usa el sistema; sus datos se registran. |
| Proveedor | Externo | Surte productos. No usa el sistema; sus datos y costos se registran. |

## 5. Requerimientos funcionales

Los marcados con ★ son los cinco que da el escenario. Los demás los agrega el equipo para cubrir el
mínimo de 10 y las reglas definidas en la Fase 0.

| ID | Requerimiento | Actor principal | Reglas |
|---|---|---|---|
| RF-01 ★ | Administrar categorías: alta, modificación y consulta. | Administrador | RN-01, RN-02 |
| RF-02 ★ | Administrar productos: SKU, nombre, categoría, precio de venta, costo, stock mínimo y baja lógica. | Administrador | RN-01–RN-05 |
| RF-03 ★ | Administrar proveedores y asociarlos a productos con costo de compra, clave del proveedor y proveedor principal. | Administrador | RN-02, RN-04, RN-23 |
| RF-04 ★ | Registrar y consultar clientes, incluido el cliente genérico "PÚBLICO EN GENERAL". | Vendedor | RN-02, RN-06 |
| RF-05 | Registrar empleados con su puesto. | Administrador | RN-22 |
| RF-06 | Registrar entradas de mercancía (inventario inicial y compras recibidas). | Almacenista | RN-15–RN-17, RN-20 |
| RF-07 | Registrar ajustes de inventario a favor o en contra, con observación del motivo. | Almacenista | RN-15–RN-17, RN-20 |
| RF-08 ★ | Registrar una venta con uno o más renglones (producto y cantidad). El sistema toma el precio aplicado y el costo vigente, y genera las salidas de inventario. | Vendedor | RN-06–RN-11, RN-16, RN-18, RN-20 |
| RF-09 ★ | Registrar pagos de una venta, parciales o totales, con método de pago. Al cubrir el total, la venta pasa a `PAGADA`. | Vendedor | RN-12–RN-14, RN-20 |
| RF-10 | Cancelar una venta pendiente sin pagos. El inventario se repone mediante movimientos de devolución. | Vendedor | RN-12, RN-18 |
| RF-11 ★ | Consultar existencias actuales y productos debajo del umbral de existencias. | Almacenista, Vendedor | RN-16, RN-19 |
| RF-12 ★ | Consultar el historial de movimientos de un producto con su saldo acumulado. | Almacenista | RN-15, RN-17 |
| RF-13 | Consultar las ventas de un cliente y el total, lo pagado y el saldo de cada venta. | Vendedor | RN-10, RN-13 |
| RF-14 | Emitir reportes: productos más vendidos, clientes con mayor gasto, productos sin ventas, ventas mensuales, y ventas y margen estimado por categoría. | Administrador | RN-21 |
| RF-15 | Conciliar la existencia almacenada con la calculada a partir del historial de movimientos. | Administrador, Almacenista | RN-19 |

> ★ RF-11 y RF-12 juntos corresponden al requerimiento del escenario "Consultar existencias y
> movimientos de inventario".

## 6. Reglas de negocio

| ID | Regla |
|---|---|
| RN-01 | Cada producto pertenece a exactamente una categoría. Una categoría puede tener muchos productos. |
| RN-02 | Son únicos el SKU del producto, el nombre de la categoría, el RFC del proveedor, el RFC del cliente (si lo tiene) y el correo del cliente. |
| RN-03 | El precio de venta, el costo y el stock mínimo de un producto son mayores o iguales a 0. |
| RN-04 | Un producto puede tener 0..N proveedores y un proveedor puede surtir 0..N productos. Cada par producto–proveedor se registra una sola vez y su costo de compra es mayor o igual a 0. |
| RN-05 | Un producto con ventas o movimientos no se elimina; se da de baja lógica (`activo = 0`). Un producto inactivo no se puede vender. |
| RN-06 | Toda venta tiene un cliente (el genérico en ventas de mostrador) y un empleado que la registra. |
| RN-07 | Una venta contiene **uno o más** renglones. Un producto aparece a lo más una vez por venta. |
| RN-08 | La cantidad de cada renglón es mayor que 0. |
| RN-09 | El precio unitario y el costo unitario se copian del catálogo al registrar la venta y **se conservan** aunque el catálogo cambie después. |
| RN-10 | El total de una venta es `Σ cantidad × precio_unitario` de sus renglones. Se calcula, no se almacena. |
| RN-11 | Los renglones solo se agregan a ventas `PENDIENTE` y no se modifican ni se eliminan. |
| RN-12 | Estados de venta: `PENDIENTE`, `PAGADA` y `CANCELADA`. La venta pasa de `PENDIENTE` a `PAGADA` automáticamente al cubrirse el total. Pasa de `PENDIENTE` a `CANCELADA` solo si no tiene pagos. `PAGADA` y `CANCELADA` son estados finales. Toda venta se crea `PENDIENTE` y de una venta registrada solo puede cambiar el estado (no la fecha, el cliente ni el empleado). |
| RN-13 | Cada pago tiene monto mayor que 0, un método de pago del catálogo y una fecha no anterior a la de la venta. La suma de los pagos de una venta no puede superar su total. Una venta cancelada no recibe pagos. |
| RN-14 | Los pagos registrados no se modifican ni se eliminan. |
| RN-15 | Todo cambio de existencia se registra como un movimiento con producto, tipo, cantidad mayor que 0 y fecha. El sentido (+/−) lo determina el signo del tipo de movimiento. |
| RN-16 | La existencia de un producto nunca puede quedar negativa. |
| RN-17 | El historial de movimientos es inmutable: los movimientos no se modifican ni se eliminan. Las correcciones se hacen con un ajuste. |
| RN-18 | Cada salida por venta y cada devolución por cancelación referencian la venta que las originó. La fecha de la salida es la fecha de la venta. |
| RN-19 | La existencia almacenada de cada producto es igual a `Σ signo × cantidad` de sus movimientos. |
| RN-20 | Las fechas de ventas, pagos y movimientos no pueden ser futuras. |
| RN-21 | Los reportes de ventas excluyen las ventas canceladas. El gasto de un cliente es el importe de sus ventas no canceladas. El margen estimado es `Σ cantidad × (precio_unitario − costo_unitario)`. |
| RN-22 | El puesto de un empleado es `ADMIN`, `VENDEDOR` o `ALMACENISTA`. |
| RN-23 | Un producto tiene a lo más un proveedor marcado como principal. |

## 7. Trazabilidad: regla → implementación

Los nombres de objetos SQL son los que se usarán en `sql/01_ddl.sql` (Fase 5). Esta tabla permite
seguir cada regla hasta el lugar donde se hace cumplir y donde se demuestra.

| Regla | Mecanismo | Objeto(s) | Evidencia |
|---|---|---|---|
| RN-01 | FK NOT NULL | `producto.categoria_id → categoria` | Consulta 2 |
| RN-02 | UNIQUE | `producto.sku`, `categoria.nombre`, `proveedor.rfc`, `cliente.rfc`, `cliente.email` | Demo: SKU duplicado |
| RN-03 | CHECK | `producto` (`precio_venta`, `costo`, `stock_minimo`) | — |
| RN-04 | PK compuesta + CHECK | `producto_proveedor (producto_id, proveedor_id)`, `costo_compra >= 0` | — |
| RN-05 | FK RESTRICT + columna `activo` + validación | FKs hacia `producto`; `registrar_venta` | Demo: DELETE de producto con ventas |
| RN-06 | FK NOT NULL | `venta.cliente_id`, `venta.empleado_id` | Demo: FK inexistente |
| RN-07 | Procedimiento transaccional + PK compuesta | `registrar_venta`; PK `detalle_venta (venta_id, producto_id)` | Demo: venta sin renglones |
| RN-08 | CHECK | `detalle_venta.cantidad > 0` | — |
| RN-09 | Columnas históricas + procedimiento | `detalle_venta.precio_unitario`, `costo_unitario`; `registrar_venta` | Demo: cambiar precio y ver el detalle anterior |
| RN-10 | Función + vista | `fn_total_venta`, `v_venta_saldos` | Consulta 5 |
| RN-11 | Triggers | `trg_detalle_venta_bi`, `trg_detalle_venta_bu`, `trg_detalle_venta_bd` | — |
| RN-12 | CHECK + triggers + procedimiento | CHECK `venta.estado`; `trg_venta_bi`, `trg_venta_bu`, `trg_pago_ai`; `cancelar_venta` | Demo: pago total → `PAGADA` |
| RN-13 | CHECK + FK + trigger | `pago.monto > 0`; FK `metodo_pago_id`; `trg_pago_bi` | Demo: pago excedente, pago a venta cancelada |
| RN-14 | Triggers | `trg_pago_bu`, `trg_pago_bd` | — |
| RN-15 | Tabla + CHECK + catálogo | `movimiento_inventario` (`cantidad > 0`), `tipo_movimiento.signo IN (1,-1)` | Consulta 11 |
| RN-16 | Trigger + CHECK | `trg_movimiento_bi`; CHECK `producto.existencia >= 0` | Demo: stock negativo |
| RN-17 | Triggers | `trg_movimiento_bu`, `trg_movimiento_bd` | Demo: borrar un movimiento |
| RN-18 | FK nula + triggers | `movimiento_inventario.venta_id`; `trg_detalle_venta_ai`, `trg_movimiento_bi`, `cancelar_venta` | Demo: movimientos generados |
| RN-19 | Triggers + vista | `trg_movimiento_ai` (mantiene el saldo); `trg_producto_bi`, `trg_producto_bu` (impiden editar la existencia directamente); `v_conciliacion_inventario` | Demo: diferencia = 0 |
| RN-20 | Triggers (un `CHECK` no admite `NOW()`) | `trg_venta_bi`, `trg_pago_bi`, `trg_movimiento_bi` | — |
| RN-21 | Criterio de consulta | Consultas 7, 9 y 10 | Consulta 10 |
| RN-22 | CHECK | `empleado.puesto` | — |
| RN-23 | Triggers | `trg_producto_proveedor_bi`, `trg_producto_proveedor_bu` | — |

## 8. Cobertura de los requerimientos del escenario

| Requisito del escenario | Cubierto por |
|---|---|
| Administrar productos, categorías y proveedores | RF-01, RF-02, RF-03 |
| Registrar clientes y ventas | RF-04, RF-08 |
| Capturar renglones con cantidad y precio aplicado | RF-08, RN-09 |
| Registrar pagos de ventas | RF-09 |
| Consultar existencias y movimientos | RF-11, RF-12 |
| Regla: producto en una categoría; producto–proveedor N:M | RN-01, RN-04 |
| Regla: una venta con uno o más renglones | RN-07 |
| Regla: precio unitario conservado en el detalle | RN-09 |
| Regla: el inventario no queda negativo | RN-16 |
| Regla: movimientos con producto, cantidad, tipo y fecha; el historial no se infiere del saldo | RN-15, RN-17, RN-19 |
