# Sistema de Ventas e Inventarios — Equipo 5

Proyecto integrador de la materia **Diseño de Bases de Datos**.

Base de datos relacional para *Suministros Altamira* (empresa ficticia de ferretería). Registra
catálogo, proveedores, clientes, ventas detalladas por producto con precio y costo históricos,
pagos parciales y un **historial trazable e inmutable** de movimientos de inventario. Las reglas de
negocio las hace cumplir la propia base con restricciones, triggers y transacciones.

## Requisitos

- **XAMPP con MariaDB 10.4+** (motor con el que se desarrolló y probó), o **MySQL 8.0.16+**.
- Usuario `root` sin contraseña (configuración por defecto de XAMPP). Si tu usuario tiene
  contraseña, agrega `-p` a los comandos.
- En Windows con XAMPP, el cliente está en `C:\xampp\mysql\bin\mysql.exe`.

## Ejecución

Inicia MySQL desde el panel de XAMPP y ejecuta los scripts **en orden**:

```bash
mysql -u root --default-character-set=utf8mb4    < sql/01_ddl.sql        # crea la base ventas_equipo5
mysql -u root --default-character-set=utf8mb4    < sql/02_dml.sql        # datos de prueba
mysql -u root --default-character-set=utf8mb4 -t < sql/03_consultas.sql  # las 10 consultas (+1)
mysql -u root --default-character-set=utf8mb4 -t < sql/05_demo.sql       # demostración
```

> En PowerShell, la redirección `<` no funciona. Usa `cmd /c "mysql -u root < sql\01_ddl.sql"`,
> o abre los archivos en phpMyAdmin o MySQL Workbench.

**Índices (Fase 8).** Para ver su efecto con volumen:
1. Recarga con `01` y `02`.
2. Ejecuta `sql/04b_volumen_benchmark.sql` (opcional, unos 10 s).
3. Ejecuta `sql/04_indices.sql`.
4. Vuelve a ejecutar `01` y `02` para regresar a los datos limpios.

`01_ddl.sql` **borra y vuelve a crear** la base `ventas_equipo5`. Las demás bases de datos de XAMPP no
se tocan.

## Estructura

| Archivo | Contenido |
|---|---|
| `sql/01_ddl.sql` | 12 tablas, 20 `CHECK`, 13 FK, 18 triggers, 2 funciones, 2 procedimientos, 3 vistas |
| `sql/02_dml.sql` | 30 productos, 21 clientes, 60 ventas (jun–nov 2026), pagos y movimientos |
| `sql/03_consultas.sql` | 10 consultas obligatorias (básico → avanzado) y 1 complementaria |
| `sql/04_indices.sql` | 4 índices adicionales con `EXPLAIN` antes/después |
| `sql/04b_volumen_benchmark.sql` | Volumen sintético opcional (20,000 ventas) para la evidencia de índices |
| `sql/05_demo.sql` | Guion de demostración: alta, inventario, venta, pagos, cancelación, violaciones de reglas y consultas |

| Documento | Fase |
|---|---|
| [docs/00_verificacion_plan.md](docs/00_verificacion_plan.md) | Verificación del plan contra la especificación |
| [docs/01_plan_corregido.md](docs/01_plan_corregido.md) | Plan de trabajo corregido |
| [docs/02_analisis.md](docs/02_analisis.md) | 1 · Problema, actores, 15 RF, 23 reglas de negocio y su trazabilidad |
| [docs/03_modelo_er.md](docs/03_modelo_er.md) | 2 · Diagrama ER (Mermaid), entidades, cardinalidades |
| [docs/04_modelo_relacional.md](docs/04_modelo_relacional.md) | 3 · Tablas, restricciones, FK y políticas de borrado |
| [docs/05_normalizacion.md](docs/05_normalizacion.md) | 4 · De la tabla plana a 3FN / FNBC |
| [docs/06_indices_optimizacion.md](docs/06_indices_optimizacion.md) | 8 · Índices y análisis de `EXPLAIN` |
| [docs/07_evidencias.md](docs/07_evidencias.md) | Evidencias de ejecución de cada fase |
| [docs/08_guia_defensa.md](docs/08_guia_defensa.md) | 9 · Guion de presentación y respuestas para la defensa |

## Compatibilidad MariaDB / MySQL

Los scripts evitan funciones exclusivas de cada motor: no usan `JSON_TABLE`, índices funcionales ni
`EXPLAIN ANALYZE` dentro de los scripts. Diferencias conocidas:

- Un `CHECK` violado da el error **4025** en MariaDB y el **3819** en MySQL 8. El nombre de la
  restricción aparece en ambos.
- Para ver las filas reales de un plan se usa `ANALYZE SELECT …` en MariaDB y `EXPLAIN ANALYZE …`
  en MySQL 8.0.18+.
