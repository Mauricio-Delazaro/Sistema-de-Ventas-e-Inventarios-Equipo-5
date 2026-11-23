# Fase 9 · Guía de presentación y defensa

**Proyecto integrador — Equipo 5 · Sistema de ventas e inventarios**

Esta guía prepara a **cada integrante** para explicar cualquier decisión del diseño. Las respuestas
citan el modelo real del equipo (tablas, reglas RN-xx, objetos SQL). La regla es no memorizar:
cada respuesta tiene una frase corta para decir y un "dónde mostrarlo" para respaldarla.

---

## 1. Guion de la presentación (6 secciones)

| # | Sección | Qué decir (idea central) | Qué mostrar | Fuente |
|---|---|---|---|---|
| 1 | Presentación del problema | Suministros Altamira controla ventas e inventario en hojas de cálculo. Pierde precios históricos, el inventario no cuadra, quedan existencias negativas y los pagos parciales no se controlan. | La tabla plana con sus anomalías | [02_analisis.md](02_analisis.md) §2, [05_normalizacion.md](05_normalizacion.md) §1–2 |
| 2 | Modelo ER | 12 entidades, 11 relaciones (9 de tipo 1:N y 2 N:M con tabla asociativa). El historial de movimientos es la fuente de verdad del inventario. | Diagrama ER, tabla de cardinalidades | [03_modelo_er.md](03_modelo_er.md) |
| 3 | Modelo relacional y normalización | Esquema en 3FN (y FNBC). Precio y costo históricos en el detalle. Existencia como redundancia controlada. Borrados `RESTRICT`. | Paso 1FN → 2FN → 3FN; tabla de FK y políticas | [04_modelo_relacional.md](04_modelo_relacional.md), [05_normalizacion.md](05_normalizacion.md) |
| 4 | Demostración en MySQL | La base hace cumplir las reglas por sí misma: triggers, CHECK, FK y transacciones. | `sql/05_demo.sql`, pasos 1 a 7 | [sql/05_demo.sql](../sql/05_demo.sql) |
| 5 | Consultas y optimización | 10 consultas en 3 niveles. 4 índices justificados con `EXPLAIN` antes y después. | Paso 8 de la demo; tablas antes/después | [sql/03_consultas.sql](../sql/03_consultas.sql), [06_indices_optimizacion.md](06_indices_optimizacion.md) |
| 6 | Preguntas | — | Esta guía | — |

### Preparación antes de presentar

1. Iniciar MySQL desde el panel de XAMPP.
2. Recargar la base: `mysql -u root < sql/01_ddl.sql` y después
   `mysql -u root --default-character-set=utf8mb4 < sql/02_dml.sql`.
3. Abrir `sql/05_demo.sql` en Workbench o phpMyAdmin y ejecutarlo **paso por paso**.
4. Si se pide ver un error "crudo" en lugar de la fila RECHAZADO, copiar la sentencia que está entre
   comillas en el `demo_intentar` y ejecutarla sola.

---

## 2. Las 12 preguntas sugeridas

### 1. ¿Por qué se creó esta entidad?

**Regla general:** cada entidad representa un hecho independiente que tiene sus propios atributos,
o resuelve una relación N:M.

| Entidad | Respuesta corta |
|---|---|
| `movimiento_inventario` | El escenario exige que el historial **no se infiera del saldo**. Cada entrada, salida o ajuste es un hecho con fecha. El saldo se deriva de él. |
| `tipo_movimiento` | No es solo un nombre: guarda el **signo** (+1/−1) que dice si el movimiento suma o resta. Por ese atributo es una tabla y no un `ENUM`. |
| `empleado` | Responde "¿quién registró esta venta o este ajuste?" y representa a los actores internos (vendedor, almacenista). |
| `metodo_pago` | Controla el dominio: evita "Efectivo", "efectivo" y "EFECTIVO" como tres valores distintos. |
| `detalle_venta` | Resuelve venta N:M producto y guarda lo que solo existe en esa combinación: cantidad, precio y costo aplicados. |
| `producto_proveedor` | Resuelve producto N:M proveedor y guarda el costo de compra de cada proveedor. |

**Dónde mostrarlo:** [03_modelo_er.md](03_modelo_er.md) §2.

### 2. ¿Qué regla de negocio representa esta relación?

| Relación | Regla |
|---|---|
| Categoría 1:N Producto | RN-01: cada producto pertenece a exactamente una categoría (FK `NOT NULL`). |
| Venta N:M Producto | RN-07: una venta tiene **uno o más** renglones y un producto aparece una sola vez por venta (PK compuesta). |
| Venta 1:N Pago | RN-13: se permiten pagos parciales y su suma no supera el total. |
| Producto 1:N Movimiento | RN-15: todo cambio de existencia queda registrado. |
| Venta 0..1:N Movimiento | RN-18: cada salida por venta y cada devolución dice qué venta la originó. |

**Dónde mostrarlo:** [03_modelo_er.md](03_modelo_er.md) §3, columna "Regla".

### 3. ¿Por qué la cardinalidad es 1:N o N:M?

- **1:N Categoría–Producto:** el escenario dice que *cada* producto pertenece a *una* categoría. Si
  pudiera estar en varias, sería N:M.
- **N:M Producto–Proveedor:** un tornillo lo surten varios distribuidores y un distribuidor surte
  muchos productos.
- **N:M Venta–Producto:** una venta lleva varios productos y un producto se vende muchas veces.
- **1:N Venta–Pago:** los pagos parciales exigen varios pagos por venta, y cada pago abona a una
  sola venta.
- **Participación:**
  - una venta **debe** tener al menos un renglón (1..N);
  - un producto **puede** no tener ventas (0..N), y eso es lo que encuentra la consulta 8;
  - un movimiento **puede** no tener venta (0..1): las entradas y los ajustes no vienen de ventas.

### 4. ¿Cómo se resolvió una relación N:M?

Con una **tabla asociativa** cuya PK es la combinación de las dos FK:
- `detalle_venta (venta_id, producto_id)`;
- `producto_proveedor (producto_id, proveedor_id)`.

Cada N:M se convierte en dos relaciones 1:N. La PK compuesta impide pares repetidos. Además, la
tabla guarda **atributos de la relación**: `cantidad` y `precio_unitario` no son del producto ni de la
venta, sino de *ese producto en esa venta*.

**Demostración:** `registrar_venta` con el mismo producto dos veces → error 1062, llave duplicada
([07_evidencias.md](07_evidencias.md), Fase 5).

### 5. ¿Cuál es la PK y por qué?

- **Tablas principales: PK entera sustituta** (`producto_id`, `venta_id`…).
  - Es corta, estable (nunca cambia) y hace las FK eficientes.
  - Las claves naturales se conservan como `UNIQUE`: `sku`, `rfc`, `email`.
  - El RFC no puede ser PK de cliente porque el público en general no tiene RFC.
  - Un SKU puede corregirse, y si fuera PK habría que cambiarlo en todas las FK.
- **Asociativas: PK compuesta.** Ahí la identidad **es** la combinación. Un renglón *es* "producto X
  en la venta Y".

### 6. ¿Qué anomalía se evita con la normalización?

Con el ejemplo de la tabla plana ([05_normalizacion.md](05_normalizacion.md) §2):
- **Actualización:** el correo de Constructora Robles repetido en cada venta. Al cambiarlo en una
  fila y no en otra, el cliente queda con dos correos.
- **Inserción:** no se podía dar de alta un producto que aún no se vendía.
- **Borrado:** al borrar la única venta de la pintura vinílica se perdía el producto y su proveedor.

Cada tabla final evita una de estas anomalías ([05_normalizacion.md](05_normalizacion.md) §7.4).

### 7. ¿Por qué el modelo cumple 3FN?

- **1FN:** valores atómicos, sin listas en celdas.
- **2FN:** ningún atributo depende de *parte* de una PK compuesta. En `detalle_venta`, `cantidad` y
  `precio_unitario` dependen de `(venta_id, producto_id)` completo.
- **3FN:** ningún atributo no clave depende de otro no clave. Por ejemplo, la descripción de la
  categoría salió de `producto` y el signo salió de `movimiento_inventario`.
- Además cumple **FNBC**: todo determinante es clave candidata.

**Preguntas trampa:**
- *¿El `precio_unitario` en el detalle no repite el precio del producto?* No. `sku ↛ precio_unitario`:
  el martillo se vendió a $150 y luego a $165. Es el precio **de esa venta**, un hecho histórico.
- *¿Y `producto.existencia`?* Depende solo de la PK, así que no viola la 3FN. Es redundancia
  **entre tablas**, controlada por trigger y verificada por `v_conciliacion_inventario` (§7.2 de
  normalización).
- *¿Por qué no se guarda el total de la venta?* Porque se calcula barato del detalle y guardarlo
  crearía otra fuente de inconsistencia (§7.3).

### 8. ¿Qué garantiza esta FK o restricción?

| Restricción | Garantiza |
|---|---|
| `fk_venta_cliente` | No hay ventas de clientes inexistentes (demo: error 1452). |
| `ck_detalle_cantidad` (`cantidad > 0`) | No hay renglones con cantidad 0 o negativa. |
| `uq_producto_sku` | Dos productos no comparten código. |
| `ck_tipo_movimiento_signo` | El signo solo puede ser +1 o −1. |
| `ck_venta_estado` | El estado es uno de los 3 válidos. |
| `trg_movimiento_bi` | La existencia nunca queda negativa (RN-16). |
| `trg_pago_bi` | Los pagos no superan el total (RN-13). |

**Distinción clave:**
- Un `CHECK` valida una fila **sola**.
- Las reglas que necesitan **otras filas** (saldo de pagos, existencia) o la **fecha actual** van en
  triggers, porque un `CHECK` no puede consultar otras tablas ni usar `NOW()`.

Tabla completa: [04_modelo_relacional.md](04_modelo_relacional.md) §6.

### 9. ¿Qué ocurre al eliminar un registro relacionado?

Respuesta preparada en [04_modelo_relacional.md](04_modelo_relacional.md) §4:
- **Producto vendido:** error 1451 (`RESTRICT`). Se da de baja con `activo = 0`.
- **Venta:** error 1451. Las ventas **no se borran, se cancelan** con `cancelar_venta`, que repone el
  stock.
- **Movimiento:** siempre rechazado por trigger (RN-17). El historial es inmutable.
- **Proveedor sin historial:** se permite, y sus ofertas en `producto_proveedor` se borran en
  `CASCADE`.

**El argumento fuerte:** en MySQL y MariaDB, un `ON DELETE CASCADE` **no dispara triggers**. Si
`detalle_venta` borrara en cascada, el inventario quedaría descuadrado sin ningún error. Por eso todo
lo transaccional es `RESTRICT`.

### 10. ¿Por qué se creó este índice?

Para cada índice existe la tabla antes/después ([06_indices_optimizacion.md](06_indices_optimizacion.md) §4):

| Índice | Una frase |
|---|---|
| `producto(nombre)` | La búsqueda `LIKE 'Llave%'` pasa de leer 3,030 filas y ordenarlas a leer 152 ya ordenadas. |
| `venta(fecha, estado)` | La consulta 9 pasa de leer 20,060 ventas a leer 4,584, y sin tocar la tabla (índice cubriente). |
| `movimiento(producto_id, fecha)` | El historial sale ya ordenado y filtrado por fecha (sin filesort). |
| `detalle(producto_id, cantidad, precio_unitario)` | La consulta 6 suma desde el índice sin leer ninguna fila. |

**Si preguntan por qué no se indexó `detalle_venta(producto_id)`:** porque InnoDB ya lo indexa por
la FK. Un índice repetido solo gasta espacio y hace más lentas las escrituras.

### 11. ¿Qué hace el JOIN de esta consulta?

| Consulta | JOIN | Explicación |
|---|---|---|
| 2, 3, 4 | `INNER JOIN` | Solo filas con pareja en ambas tablas (todo producto tiene categoría). |
| 7 | `INNER JOIN` + `HAVING` | Une cliente → venta → detalle, agrupa por cliente y filtra **después** de sumar. `WHERE` filtra filas y `HAVING` filtra grupos. |
| **8** | **`LEFT JOIN … IS NULL`** | Conserva todos los productos. Los que no tienen renglón quedan con `NULL` y se filtran (anti-join). La condición `estado <> 'CANCELADA'` va en el **`ON`**: en el `WHERE` eliminaría justo las filas `NULL` que se buscan. |
| 10 | 4 `INNER JOIN` | categoría → producto → detalle → venta, para agrupar por categoría y excluir canceladas. |
| 11 | `LEFT JOIN empleado` | Las salidas por venta no tienen capturista; con `INNER` desaparecerían del historial. |

### 12. ¿Cómo podría optimizarse?

En [06_indices_optimizacion.md](06_indices_optimizacion.md) §8:
- `venta(cliente_id, fecha)` para el historial de un cliente;
- un índice cubriente para el listado paginado;
- una tabla resumen mensual;
- particionar el historial por año;
- usar rangos de fecha en lugar de `YEAR(fecha)`.

**Mostrar que se entendió el optimizador:** el listado paginado **no** usó el índice con 3,030
productos, porque leer y ordenar resultó más barato. Y con solo 60 ventas casi ningún índice se usa
(§6). Un índice se diseña para el volumen real de operación.

---

## 3. Preguntas adicionales probables

| Pregunta | Respuesta |
|---|---|
| ¿Por qué validar en la base y no en la aplicación? | Porque la base es el único punto por el que pasan **todos** los accesos: la aplicación, phpMyAdmin o un script. Si la regla vive solo en la aplicación, un `UPDATE` manual la rompe. La demo lo prueba: cada intento se rechaza aunque se ejecute directamente en SQL. |
| ¿Cómo se garantiza que una venta tenga al menos un renglón? | No se puede declarar con `CHECK` ni con un trigger, porque al insertar la venta todavía no tiene renglones. Lo garantiza `registrar_venta`: inserta la venta y sus renglones en **una transacción** y hace `ROLLBACK` si recibe 0 renglones o si cualquier renglón falla. |
| ¿Qué pasa si un renglón falla a mitad de la venta? | `ROLLBACK` completo: no queda la venta ni los renglones anteriores ni sus salidas de inventario. Probado en las evidencias (RN-16, rollback). |
| ¿Qué es el error 1442 y cómo lo evitaron? | MySQL no deja que un trigger modifique una tabla que está usando la sentencia que lo disparó. Por eso `registrar_venta` lee el precio con `SELECT … INTO` y luego hace `INSERT … VALUES`, en lugar de `INSERT … SELECT FROM producto`. |
| ¿Por qué hay huecos en los folios de venta? | `AUTO_INCREMENT` no retrocede con `ROLLBACK`, así que una venta rechazada consume su número. El folio identifica, no cuenta. |
| ¿Cómo se calcula el margen? | `Σ cantidad × (precio_unitario − costo_unitario)` con los valores **históricos** del detalle, excluyendo las ventas canceladas. El porcentaje es margen / ingreso × 100 (consulta 10). |
| ¿Qué pasa con dos ventas simultáneas del último artículo? | `trg_movimiento_bi` lee la existencia con `SELECT … FOR UPDATE`. La segunda transacción espera a que termine la primera y después ve el saldo real, así que una de las dos se rechaza por RN-16. |
| ¿Por qué no se puede cancelar una venta pagada? | Implicaría un reembolso, que quedó fuera del alcance (§3 del análisis). Solo se cancelan ventas `PENDIENTE` sin pagos. |
| ¿Es MySQL o MariaDB? | Se desarrolló y probó en MariaDB 10.4 (XAMPP). Los scripts evitan las funciones exclusivas de cada motor para ser compatibles con MySQL 8.0.16+. La única diferencia visible es el código de error de `CHECK`: 4025 en MariaDB y 3819 en MySQL. |

---

## 4. Reparto entre integrantes (3)

Cada integrante presenta sus secciones y es el primero en responder las preguntas de su bloque.
**Todos** deben poder responder las preguntas 5, 7 y 9, porque son las que más se repiten en una
defensa individual. En la sección 6 (preguntas) responde quien tenga el tema y los demás apoyan.

| Integrante | Secciones que presenta | Preguntas principales | Documentos y scripts que debe dominar |
|---|---|---|---|
| **Juan** | 1. Presentación del problema · 2. Modelo ER | 1, 2, 3, 4 | [02_analisis.md](02_analisis.md), [03_modelo_er.md](03_modelo_er.md) |
| **Mauricio** | 3. Modelo relacional y normalización · 4. Demostración (pasos 1 a 7) | 5, 6, 7, 8, 9 y las adicionales sobre triggers, transacciones, el error 1442 y la concurrencia | [04_modelo_relacional.md](04_modelo_relacional.md), [05_normalizacion.md](05_normalizacion.md), [sql/01_ddl.sql](../sql/01_ddl.sql), [sql/05_demo.sql](../sql/05_demo.sql) |
| **Chris** | 4. Demostración (paso 8, consultas por nivel) · 5. Consultas y optimización | 10, 11, 12 y las adicionales sobre margen y MariaDB/MySQL | [sql/03_consultas.sql](../sql/03_consultas.sql), [sql/04_indices.sql](../sql/04_indices.sql), [06_indices_optimizacion.md](06_indices_optimizacion.md) |

**Cómo se equilibra:** Juan cubre la parte conceptual. Mauricio cubre la parte lógica y física (la
más amplia, pero continua: el modelo relacional desemboca en el DDL que se ve en la demo). Chris
cubre consultas e índices, la parte más técnica del `EXPLAIN`.

**Relevo en la demo:** Mauricio ejecuta los pasos 1 a 7 y Chris toma el control en el paso 8. Así
las consultas que se muestran en vivo las explica quien las va a defender.

**Preparación cruzada recomendada:** antes de la defensa, cada integrante explica a los otros dos una
pregunta de su bloque sin leer la guía.

---

## 5. Lista de verificación final (docente)

| Punto | Estado | Evidencia |
|---|---|---|
| Problema, actores, ≥10 RF y reglas claras | ✅ | 15 RF, 23 RN, 5 actores, en [02_analisis.md](02_analisis.md) |
| ≥6 entidades y ≥6 relaciones | ✅ | 12 entidades y 11 relaciones, en [03_modelo_er.md](03_modelo_er.md) |
| ≥3 relaciones 1:N y ≥2 N:M con tabla asociativa | ✅ | 9 de tipo 1:N y 2 N:M |
| PK en todas las tablas; FK apropiadas | ✅ | 12 PK y 13 FK, en [04_modelo_relacional.md](04_modelo_relacional.md) |
| Normalización hasta 3FN justificada | ✅ | [05_normalizacion.md](05_normalizacion.md), que incluye FNBC |
| Restricciones ↔ reglas de negocio | ✅ | Trazabilidad RN → objeto en [02_analisis.md](02_analisis.md) §7; 62 pruebas |
| Datos coherentes y suficientes | ✅ | 60 ventas en 6 meses, con datos sembrados para cada consulta |
| 10 consultas ejecutables y graduales | ✅ | 4 básicas, 3 intermedias, 3 avanzadas (+1) |
| ≥3 índices adicionales justificados | ✅ | 4 índices |
| `EXPLAIN` documentado con análisis | ✅ | [06_indices_optimizacion.md](06_indices_optimizacion.md) |
| Demostración funcional | ✅ | `05_demo.sql` ejecutado sin errores; 10 de 10 violaciones rechazadas |
| Cada integrante puede explicar el diseño | ⏳ | Depende del equipo: reparto entre Juan, Mauricio y Chris en la §4 |
