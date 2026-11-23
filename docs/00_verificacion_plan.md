# Verificación del plan de trabajo contra la especificación — Equipo 5

Documento de control previo a la implementación. Compara `plan_fases_equipo5.md` con la
especificación del proyecto integrador (sección *Equipo 5. Sistema de ventas e inventarios*,
la lista de verificación docente y las consideraciones finales).

> **Estado (2026-11-23):** los 15 cambios de la sección 4 quedaron incorporados en
> [01_plan_corregido.md](01_plan_corregido.md). Motor de trabajo: XAMPP con MariaDB 10.4.32;
> scripts compatibles con MySQL 8.0.16+. Se incluye `Empleado`.

**Conclusión general:** el plan cubre todos los entregables, entidades, relaciones, consultas y
criterios de demostración exigidos. No falta ningún requisito obligatorio. Sí hay **huecos de
diseño** (reglas que el plan menciona pero no define) y **algunos puntos técnicos que fallarían
en MySQL** si se implementan tal como están escritos. Se listan abajo con una propuesta de
corrección para cada uno.

Leyenda: ✅ cumple · ⚠️ cumple con ajustes · ❌ falta o es incorrecto

---

## 1. Cobertura de la especificación

### 1.1 Requerimientos funcionales del escenario

| Requerimiento (spec) | Dónde lo cubre el plan | Estado |
|---|---|---|
| Administrar productos, categorías y proveedores | Fase 2 (entidades), Fase 5 (DDL) | ✅ |
| Registrar clientes y ventas | Fase 2, Fase 5 (`registrar_venta`) | ✅ |
| Capturar líneas de detalle con cantidad y precio aplicado | `Detalle_Venta` con `precio_unitario` | ✅ |
| Registrar pagos de ventas | `Pago`, trigger de tope | ✅ |
| Consultar existencias y movimientos de inventario | Vista de existencias (Fase 5) | ⚠️ Ninguna de las 10 consultas ni la vista muestra el **historial de movimientos**. Se propone agregarlo a la demo (paso 5) y como consulta adicional. |
| ≥ 10 RF (lista docente) | Fase 1 | ✅ (pendiente de redactar) |

### 1.2 Entidades sugeridas

Las 9 entidades sugeridas están en el plan: `Producto`, `Categoría`, `Proveedor`,
`Producto_Proveedor`, `Cliente`, `Venta`, `Detalle_Venta`, `Pago`, `Movimiento_Inventario`. ✅
Las adicionales (`Método_Pago`, `Tipo_Movimiento`, `Empleado`) están justificadas. ✅

### 1.3 Relaciones mínimas sugeridas

| Relación (spec) | En el plan | Estado |
|---|---|---|
| Categoría 1:N Producto | Sí | ✅ |
| Producto N:M Proveedor (`Producto_Proveedor`) | Sí | ✅ |
| Cliente 1:N Venta | Sí | ✅ |
| Venta N:M Producto (`Detalle_Venta`) | Sí | ✅ |
| Venta 1:N Pago | Sí | ✅ |
| Producto 1:N Movimiento_Inventario | Sí | ✅ |

Conteo: 4 relaciones 1:N + 2 N:M = **6**. El plan dice que "se superan los mínimos", pero con las
6 base solo **se alcanzan**. Se superan al sumar las de los catálogos:
`Método_Pago 1:N Pago`, `Tipo_Movimiento 1:N Movimiento_Inventario`, `Empleado 1:N Venta` (9 o más). ⚠️ Corregir la redacción.

### 1.4 Reglas de negocio del escenario

| Regla (spec) | Implementación en el plan | Estado |
|---|---|---|
| Cada producto pertenece a una categoría | FK `categoria_id NOT NULL` | ✅ |
| Producto–proveedor puede ser N:M | `Producto_Proveedor` | ✅ |
| Una venta contiene **uno o más** renglones | Solo se menciona en el diagrama ("1..N") | ❌ No dice cómo se garantiza. Ver H-01. |
| Precio unitario se conserva en el detalle | `Detalle_Venta.precio_unitario` | ✅ |
| Inventario no negativo | Trigger + saldo mantenido | ✅ (ver H-05 y T-01) |
| Movimientos con producto, cantidad, tipo y fecha; historial no inferido del saldo | `Movimiento_Inventario` como fuente de verdad | ✅ (ver H-04 y T-03) |

### 1.5 Consultas obligatorias

Las 10 coinciden una a una con la especificación, en el mismo orden y con niveles graduales. ✅
Para que no sean ambiguas hay que definir algunos criterios (H-06, H-07).

### 1.6 Criterios de demostración

Registrar catálogo y proveedor → inventario inicial → venta con varios productos → pagos →
verificar detalle, movimientos y reporte → una consulta por nivel. El guion de la Fase 9 los cubre
todos y además agrega pruebas de violación de reglas. ✅

### 1.7 Entregables y lista de verificación docente

| Punto | Fase | Estado |
|---|---|---|
| Análisis: problema, actores, ≥10 RF, reglas | 1 | ✅ |
| ≥6 entidades y ≥6 relaciones | 2 | ✅ |
| ≥3 1:N y ≥2 N:M con tabla asociativa | 2 | ✅ |
| PK en todas las tablas, FK apropiadas | 3 | ✅ |
| Normalización 3FN justificada | 4 | ⚠️ Falta justificar `Producto.existencia` (H-08) |
| Restricciones ↔ reglas de negocio | 3, 5 | ⚠️ `CHECK` de fechas no es válido en MySQL (T-02) |
| Datos de prueba coherentes | 6 | ⚠️ Fechas de los movimientos (T-03) |
| 10 consultas ejecutables y graduales | 7 | ✅ |
| ≥3 índices adicionales justificados | 8 | ⚠️ Uno es redundante (T-05) |
| `EXPLAIN` con análisis | 8 | ⚠️ Volumen de datos (T-06) |
| Demostración funcional | 9 | ✅ |

Alcance de este repositorio: scripts `.sql` y documentación `.md` en `docs/`. El diagrama ER
como imagen, el reporte Word/PDF y la presentación quedan **fuera de alcance**. El diagrama se
puede dejar en texto (Mermaid) dentro de un `.md` para que el equipo lo pase a imagen.

---

## 2. Huecos de diseño (reglas sin definir)

**H-01. "Una venta contiene uno o más renglones".** MySQL no puede validar esto con `CHECK` ni con
un trigger (al insertar la venta todavía no existen sus detalles).
*Propuesta:* la venta solo se crea con el procedimiento `registrar_venta`, que en una transacción
inserta la cabecera y los renglones y hace `ROLLBACK` si recibe cero renglones. Se documenta como
regla garantizada **por procedimiento**, no por restricción declarativa.

**H-02. Efecto de cancelar una venta.** Existe el estado `CANCELADA`, pero el plan no dice qué
pasa con el inventario ni con los pagos.
*Propuesta:* procedimiento `cancelar_venta` que cambia el estado y genera un movimiento
`DEVOLUCION` por cada renglón, para que el stock regrese y el historial lo conserve. No se aceptan
pagos para una venta cancelada. Las ventas canceladas se excluyen de los reportes.

**H-03. Origen de `costo_unitario`.** El margen usa `Detalle_Venta.costo_unitario`, pero ninguna
tabla define el costo del producto.
*Propuesta:* agregar `Producto.costo` (costo vigente). `Producto_Proveedor.costo_compra` guarda el
precio de cada proveedor. Al vender, se copia `Producto.costo` al detalle, igual que el precio.

**H-04. Signo de los movimientos `AJUSTE`.** Un ajuste puede subir o bajar el stock, así que el
tipo `AJUSTE` por sí solo no indica la dirección.
*Propuesta:* `cantidad` siempre positiva (`CHECK cantidad > 0`) y `Tipo_Movimiento` con una columna
`signo` (+1 / −1). Los tipos quedan así: `ENTRADA(+1)`, `SALIDA_VENTA(−1)`, `AJUSTE_ENTRADA(+1)`,
`AJUSTE_SALIDA(−1)` y `DEVOLUCION(+1)`. Esto también justifica que `Tipo_Movimiento` sea una tabla
con atributos propios y no solo un `ENUM`.

**H-05. `Venta.total`: ¿se almacena o se calcula?** El trigger de pagos necesita el total.
*Propuesta:* **no** almacenarlo. El total se calcula con `SUM(cantidad × precio_unitario)` del
detalle. Así no hay dato derivado en `Venta`, la consulta 5 tiene sentido y la 3FN queda limpia.
Un trigger en `Pago` cambia el estado a `PAGADA` cuando la suma de los pagos alcanza el total.

**H-06. Umbral de existencias (consulta 4).** No hay ningún atributo para el umbral.
*Propuesta:* `Producto.stock_minimo` (`CHECK >= 0`).

**H-07. Definiciones para los reportes.**
- "Gasto de un cliente" (consulta 7) = importe de sus ventas no canceladas.
- Las ventas mensuales (9) y el reporte por categoría (10) excluyen `CANCELADA`.
- Margen estimado = `Σ cantidad × (precio_unitario − costo_unitario)`. El reporte también
  muestra el % de margen = margen / ingreso.

**H-08. `Producto.existencia` frente a 3FN.** El saldo se puede derivar del historial. No viola la
3FN en sentido formal (depende solo de la PK `producto_id`), pero es **redundancia controlada**.
*Propuesta:* justificarla en el documento de normalización (rendimiento de consulta y del trigger
de validación) e incluir una vista de conciliación `saldo almacenado` frente a
`SUM(signo × cantidad)` que demuestre que ambos coinciden.

**H-09. Participación opcional (la spec pide explicitarla).**
- Venta → Cliente: obligatoria. Las ventas de mostrador usan un cliente genérico
  "PÚBLICO EN GENERAL" para no tener FK nulas.
- Producto → Proveedor: 0..N (un producto puede no tener proveedor registrado).
- Producto → Detalle_Venta: 0..N (por eso existe la consulta 8).
- Venta → Pago: 0..N (una venta `PENDIENTE` puede no tener pagos).

**H-10. Trazabilidad del movimiento.** Un movimiento `SALIDA_VENTA` debería indicar qué venta lo
originó.
*Propuesta:* `Movimiento_Inventario.venta_id` como FK nula (solo se llena en salidas por venta y
devoluciones) y `empleado_id` para saber quién registró entradas y ajustes (actor almacenista).

**H-11. `Empleado`.** El plan lo marca como opcional. *Recomendación:* incluirlo. Cuesta poco,
agrega relaciones 1:N (`Empleado → Venta`, `Empleado → Movimiento`) y responde la pregunta
"¿quién registró esto?" en la defensa.

---

## 3. Problemas técnicos en MySQL

**T-01. Error 1442 en la cadena de triggers.** La cadena prevista es
`INSERT detalle_venta → trigger inserta movimiento → trigger actualiza producto`.
Es válida **solo si** la sentencia original no usa la tabla `producto`. Si `registrar_venta` hace
`INSERT INTO detalle_venta SELECT … FROM … JOIN producto`, MySQL lanza el error 1442 (no se puede
modificar una tabla que la sentencia que disparó el trigger está usando).
*Corrección:* en el procedimiento, leer precio y costo en variables o con un cursor, y después
hacer `INSERT … VALUES`.

**T-02. `CHECK` con fechas "válidas".** En MySQL 8, un `CHECK` no admite funciones no
deterministas (`NOW()`, `CURDATE()`).
*Corrección:* usar `CHECK` solo entre columnas o con constantes, y validar "fecha no futura" con
un trigger `BEFORE INSERT`.

**T-03. Fecha del movimiento generado.** Si el trigger usa `NOW()`, las ~60 ventas sembradas en
6 meses tendrían todos sus movimientos con la fecha de carga, lo que rompe el historial.
*Corrección:* el movimiento toma `fecha` de la venta. Las entradas iniciales del DML se fechan
antes de la primera venta.

**T-04. `FK … ON DELETE CASCADE` no dispara triggers.** En MySQL las acciones en cascada de las FK
no activan triggers. Si `Venta → Detalle_Venta` fuera `CASCADE`, borrar una venta eliminaría los
renglones sin revertir el stock.
*Corrección:* `RESTRICT` en `Venta`, `Producto`, `Cliente` y en los catálogos con historial. Las
ventas no se borran, se cancelan (H-02). Los productos se dan de baja lógica con `activo`.
`CASCADE` solo en `Producto_Proveedor` (no tiene historial transaccional).

**T-05. Índice redundante.** El plan dice que InnoDB ya indexa las FK y aun así propone
`detalle_venta(producto_id)`, que es exactamente el índice que ya crea la FK.
*Corrección:* sustituirlo por uno de estos:
- `detalle_venta(producto_id, cantidad)`: índice cubriente para "más vendidos";
- `venta(estado, fecha)`: reportes que excluyen canceladas por periodo;
- `cliente(apellido, nombre)` o `producto(categoria_id, nombre)`.

Los compuestos `movimiento_inventario(producto_id, fecha)` y `venta(fecha)` sí están bien
justificados.

**T-06. `EXPLAIN` con pocos datos.** Con 30 productos y 60 ventas el optimizador suele preferir un
recorrido completo aunque exista el índice, y la evidencia "antes/después" saldría plana.
*Corrección:* en `04_indices.sql`, generar un volumen adicional (por ejemplo, miles de ventas con un
CTE recursivo) en un bloque opcional y usar `EXPLAIN ANALYZE` (8.0.18+), o documentar el efecto
con el volumen real si se prefiere no inflar los datos.

**T-07. Pasar varios productos a `registrar_venta`.** Un procedimiento de MySQL no recibe arreglos.
*Propuesta:* parámetro `JSON` (`[{"producto_id":1,"cantidad":2}, …]`) recorrido con `JSON_TABLE`
(8.0.4+) en un cursor (para respetar T-01).

**T-08. Concurrencia en pagos y stock.** Para que el tope de pagos y la validación de stock no
fallen con operaciones simultáneas, los triggers y procedimientos leen con
`SELECT … FOR UPDATE` la fila de `venta` o `producto`. Es una mejora menor que conviene mencionar
en la defensa.

**Versión mínima de MySQL:** **8.0.16** por los `CHECK` (también cubre `JSON_TABLE` y los índices
funcionales). Se recomienda 8.0.18+ por `EXPLAIN ANALYZE`.
**Estado del entorno:** MySQL **no** está instalado en esta máquina (no está en el PATH ni en
`C:\Program Files\MySQL`). Hace falta para ejecutar y evidenciar los scripts.

---

## 4. Resumen de cambios propuestos al plan

| # | Cambio | Fase afectada |
|---|---|---|
| 1 | Garantizar "≥1 renglón" mediante `registrar_venta` transaccional | 0, 5 |
| 2 | Definir `cancelar_venta` con movimientos `DEVOLUCION` | 0, 5, 9 |
| 3 | Agregar `Producto.costo`, `Producto.stock_minimo`, `Producto.activo` | 3 |
| 4 | `Tipo_Movimiento.signo`; dividir `AJUSTE` en entrada y salida | 0, 2, 3 |
| 5 | No almacenar `Venta.total`; estado `PAGADA` automático | 0, 3, 5 |
| 6 | Cliente genérico "PÚBLICO EN GENERAL" | 3, 6 |
| 7 | `Movimiento_Inventario.venta_id` (nula) y `empleado_id` | 2, 3 |
| 8 | Incluir `Empleado` | 2 |
| 9 | Políticas de borrado: `RESTRICT` salvo `Producto_Proveedor` | 3 |
| 10 | Validar fechas con trigger, no con `CHECK` | 3, 5 |
| 11 | Movimientos fechados con la fecha de la venta | 5, 6 |
| 12 | Cambiar el índice redundante `detalle_venta(producto_id)` | 8 |
| 13 | Volumen extra o `EXPLAIN ANALYZE` para la evidencia | 8 |
| 14 | Agregar a la demo una consulta del historial de movimientos | 9 |
| 15 | Justificar `existencia` como redundancia controlada y crear la vista de conciliación | 4, 5 |

## 5. Decisiones pendientes del equipo

1. Versión de MySQL (mínimo 8.0.16) e instalación local.
2. Confirmar la inclusión de `Empleado` (recomendado).
3. Número de integrantes, para repartir la guía de defensa.
4. Aceptar o rechazar los 15 cambios de la sección 4.
