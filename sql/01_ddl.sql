-- =============================================================================
-- Proyecto integrador · Equipo 5 · Sistema de ventas e inventarios
-- 01_ddl.sql — Creación de la base de datos, tablas, restricciones, función,
--              triggers, procedimientos y vistas.
--
-- Compatibilidad: MariaDB 10.4+ (XAMPP) y MySQL 8.0.16+.
-- Ejecución:      mysql -u root < sql/01_ddl.sql
-- Documentación:  docs/04_modelo_relacional.md (tablas y restricciones)
--                 docs/02_analisis.md          (reglas de negocio RN-xx)
--
-- ADVERTENCIA: borra y vuelve a crear la base ventas_equipo5.
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DROP DATABASE IF EXISTS ventas_equipo5;
CREATE DATABASE ventas_equipo5
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE ventas_equipo5;

-- =============================================================================
-- 1. TABLAS
-- =============================================================================

-- 1.1 Catálogo de categorías (RN-01, RN-02)
CREATE TABLE categoria (
    categoria_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nombre        VARCHAR(60)   NOT NULL,
    descripcion   VARCHAR(255)  NULL,
    CONSTRAINT pk_categoria        PRIMARY KEY (categoria_id),
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

-- 1.2 Productos (RN-01, RN-02, RN-03, RN-05, RN-16)
--     existencia es redundancia controlada: solo la modifica trg_movimiento_ai.
CREATE TABLE producto (
    producto_id   INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    sku           VARCHAR(20)    NOT NULL,
    nombre        VARCHAR(120)   NOT NULL,
    categoria_id  INT UNSIGNED   NOT NULL,
    precio_venta  DECIMAL(10,2)  NOT NULL,
    costo         DECIMAL(10,2)  NOT NULL,
    existencia    INT            NOT NULL DEFAULT 0,
    stock_minimo  INT            NOT NULL DEFAULT 0,
    activo        TINYINT(1)     NOT NULL DEFAULT 1,
    CONSTRAINT pk_producto              PRIMARY KEY (producto_id),
    CONSTRAINT uq_producto_sku          UNIQUE (sku),
    CONSTRAINT ck_producto_precio       CHECK (precio_venta >= 0),
    CONSTRAINT ck_producto_costo        CHECK (costo >= 0),
    CONSTRAINT ck_producto_existencia   CHECK (existencia >= 0),
    CONSTRAINT ck_producto_stock_minimo CHECK (stock_minimo >= 0),
    CONSTRAINT ck_producto_activo       CHECK (activo IN (0, 1)),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id)
        REFERENCES categoria (categoria_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- 1.3 Proveedores (RN-02)
CREATE TABLE proveedor (
    proveedor_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    rfc           VARCHAR(13)   NOT NULL,
    razon_social  VARCHAR(120)  NOT NULL,
    telefono      VARCHAR(20)   NULL,
    email         VARCHAR(120)  NULL,
    CONSTRAINT pk_proveedor       PRIMARY KEY (proveedor_id),
    CONSTRAINT uq_proveedor_rfc   UNIQUE (rfc),
    CONSTRAINT ck_proveedor_rfc   CHECK (CHAR_LENGTH(rfc) IN (12, 13)),
    CONSTRAINT ck_proveedor_email CHECK (email IS NULL OR email LIKE '%_@_%._%')
) ENGINE = InnoDB;

-- 1.4 Asociativa Producto N:M Proveedor (RN-04, RN-23)
--     CASCADE: la asociación no tiene historial transaccional.
--     Las columnas con CASCADE no llevan CHECK (restricción de MySQL).
CREATE TABLE producto_proveedor (
    producto_id      INT UNSIGNED   NOT NULL,
    proveedor_id     INT UNSIGNED   NOT NULL,
    costo_compra     DECIMAL(10,2)  NOT NULL,
    clave_proveedor  VARCHAR(30)    NULL,
    es_principal     TINYINT(1)     NOT NULL DEFAULT 0,
    CONSTRAINT pk_producto_proveedor PRIMARY KEY (producto_id, proveedor_id),
    CONSTRAINT ck_prodprov_costo     CHECK (costo_compra >= 0),
    CONSTRAINT ck_prodprov_principal CHECK (es_principal IN (0, 1)),
    CONSTRAINT fk_prodprov_producto FOREIGN KEY (producto_id)
        REFERENCES producto (producto_id) ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_prodprov_proveedor FOREIGN KEY (proveedor_id)
        REFERENCES proveedor (proveedor_id) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- 1.5 Clientes (RN-02, RN-06). cliente_id = 1 es "PÚBLICO EN GENERAL".
CREATE TABLE cliente (
    cliente_id      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    rfc             VARCHAR(13)   NULL,
    nombre          VARCHAR(60)   NOT NULL,
    apellido        VARCHAR(60)   NULL,
    email           VARCHAR(120)  NULL,
    telefono        VARCHAR(20)   NULL,
    fecha_registro  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cliente       PRIMARY KEY (cliente_id),
    CONSTRAINT uq_cliente_rfc   UNIQUE (rfc),
    CONSTRAINT uq_cliente_email UNIQUE (email),
    CONSTRAINT ck_cliente_rfc   CHECK (rfc IS NULL OR CHAR_LENGTH(rfc) IN (12, 13)),
    CONSTRAINT ck_cliente_email CHECK (email IS NULL OR email LIKE '%_@_%._%')
) ENGINE = InnoDB;

-- 1.6 Empleados (RN-22)
CREATE TABLE empleado (
    empleado_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nombre       VARCHAR(60)   NOT NULL,
    apellido     VARCHAR(60)   NOT NULL,
    puesto       VARCHAR(12)   NOT NULL,
    activo       TINYINT(1)    NOT NULL DEFAULT 1,
    CONSTRAINT pk_empleado        PRIMARY KEY (empleado_id),
    CONSTRAINT ck_empleado_puesto CHECK (puesto IN ('ADMIN', 'VENDEDOR', 'ALMACENISTA')),
    CONSTRAINT ck_empleado_activo CHECK (activo IN (0, 1))
) ENGINE = InnoDB;

-- 1.7 Catálogo de métodos de pago
CREATE TABLE metodo_pago (
    metodo_pago_id  TINYINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(30)       NOT NULL,
    CONSTRAINT pk_metodo_pago        PRIMARY KEY (metodo_pago_id),
    CONSTRAINT uq_metodo_pago_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

-- 1.8 Catálogo de tipos de movimiento; signo define el sentido (RN-15)
CREATE TABLE tipo_movimiento (
    tipo_movimiento_id  TINYINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    clave               VARCHAR(20)       NOT NULL,
    descripcion         VARCHAR(100)      NOT NULL,
    signo               TINYINT           NOT NULL,
    CONSTRAINT pk_tipo_movimiento       PRIMARY KEY (tipo_movimiento_id),
    CONSTRAINT uq_tipo_movimiento_clave UNIQUE (clave),
    CONSTRAINT ck_tipo_movimiento_signo CHECK (signo IN (1, -1))
) ENGINE = InnoDB;

-- 1.9 Ventas (RN-06, RN-10, RN-12, RN-20). Sin columna total: se calcula.
CREATE TABLE venta (
    venta_id     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    cliente_id   INT UNSIGNED  NOT NULL,
    empleado_id  INT UNSIGNED  NOT NULL,
    fecha        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado       VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT pk_venta        PRIMARY KEY (venta_id),
    CONSTRAINT ck_venta_estado CHECK (estado IN ('PENDIENTE', 'PAGADA', 'CANCELADA')),
    CONSTRAINT fk_venta_cliente FOREIGN KEY (cliente_id)
        REFERENCES cliente (cliente_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_venta_empleado FOREIGN KEY (empleado_id)
        REFERENCES empleado (empleado_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- 1.10 Asociativa Venta N:M Producto (RN-07, RN-08, RN-09, RN-11)
CREATE TABLE detalle_venta (
    venta_id         INT UNSIGNED   NOT NULL,
    producto_id      INT UNSIGNED   NOT NULL,
    cantidad         INT            NOT NULL,
    precio_unitario  DECIMAL(10,2)  NOT NULL,
    costo_unitario   DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_detalle_venta     PRIMARY KEY (venta_id, producto_id),
    CONSTRAINT ck_detalle_cantidad  CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_precio    CHECK (precio_unitario >= 0),
    CONSTRAINT ck_detalle_costo     CHECK (costo_unitario >= 0),
    CONSTRAINT fk_detalle_venta FOREIGN KEY (venta_id)
        REFERENCES venta (venta_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (producto_id)
        REFERENCES producto (producto_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- 1.11 Pagos (RN-13, RN-14, RN-20)
CREATE TABLE pago (
    pago_id         INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    venta_id        INT UNSIGNED      NOT NULL,
    metodo_pago_id  TINYINT UNSIGNED  NOT NULL,
    fecha           DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto           DECIMAL(10,2)     NOT NULL,
    referencia      VARCHAR(50)       NULL,
    CONSTRAINT pk_pago       PRIMARY KEY (pago_id),
    CONSTRAINT ck_pago_monto CHECK (monto > 0),
    CONSTRAINT fk_pago_venta FOREIGN KEY (venta_id)
        REFERENCES venta (venta_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_pago_metodo FOREIGN KEY (metodo_pago_id)
        REFERENCES metodo_pago (metodo_pago_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- 1.12 Historial de inventario: fuente de verdad (RN-15 a RN-19)
CREATE TABLE movimiento_inventario (
    movimiento_id       INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    producto_id         INT UNSIGNED      NOT NULL,
    tipo_movimiento_id  TINYINT UNSIGNED  NOT NULL,
    cantidad            INT               NOT NULL,
    fecha               DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    venta_id            INT UNSIGNED      NULL,
    empleado_id         INT UNSIGNED      NULL,
    observacion         VARCHAR(255)      NULL,
    CONSTRAINT pk_movimiento_inventario PRIMARY KEY (movimiento_id),
    CONSTRAINT ck_mov_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_mov_producto FOREIGN KEY (producto_id)
        REFERENCES producto (producto_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_mov_tipo FOREIGN KEY (tipo_movimiento_id)
        REFERENCES tipo_movimiento (tipo_movimiento_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_mov_venta FOREIGN KEY (venta_id)
        REFERENCES venta (venta_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_mov_empleado FOREIGN KEY (empleado_id)
        REFERENCES empleado (empleado_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- =============================================================================
-- 2. FUNCIONES
-- =============================================================================
DELIMITER $$

-- Total de una venta = Σ cantidad × precio_unitario (RN-10)
CREATE FUNCTION fn_total_venta(p_venta_id INT UNSIGNED)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    RETURN (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
              FROM detalle_venta
             WHERE venta_id = p_venta_id);
END$$

-- Suma de los pagos de una venta (RN-13)
CREATE FUNCTION fn_pagado_venta(p_venta_id INT UNSIGNED)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    RETURN (SELECT COALESCE(SUM(monto), 0)
              FROM pago
             WHERE venta_id = p_venta_id);
END$$

-- =============================================================================
-- 3. TRIGGERS
--    Todos los rechazos usan SQLSTATE '45000' y un mensaje con la regla (RN-xx).
-- =============================================================================

-- ---------- producto: existencia solo cambia mediante movimientos (RN-19) ----------
CREATE TRIGGER trg_producto_bi
BEFORE INSERT ON producto
FOR EACH ROW
BEGIN
    IF NEW.existencia <> 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-19: un producto nuevo inicia con existencia 0; use un movimiento ENTRADA';
    END IF;
END$$

CREATE TRIGGER trg_producto_bu
BEFORE UPDATE ON producto
FOR EACH ROW
BEGIN
    -- @ve5_mov_en_curso solo lo activa trg_movimiento_ai mientras actualiza el saldo.
    IF NEW.existencia <> OLD.existencia AND COALESCE(@ve5_mov_en_curso, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-19: la existencia no se edita directamente; registre un movimiento';
    END IF;
END$$

-- ---------- producto_proveedor: un solo proveedor principal (RN-23) ----------
CREATE TRIGGER trg_producto_proveedor_bi
BEFORE INSERT ON producto_proveedor
FOR EACH ROW
BEGIN
    IF NEW.es_principal = 1 AND EXISTS (
        SELECT 1 FROM producto_proveedor
         WHERE producto_id = NEW.producto_id AND es_principal = 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-23: el producto ya tiene un proveedor principal';
    END IF;
END$$

CREATE TRIGGER trg_producto_proveedor_bu
BEFORE UPDATE ON producto_proveedor
FOR EACH ROW
BEGIN
    IF NEW.es_principal = 1 AND EXISTS (
        SELECT 1 FROM producto_proveedor
         WHERE producto_id = NEW.producto_id
           AND es_principal = 1
           AND NOT (producto_id = OLD.producto_id AND proveedor_id = OLD.proveedor_id)
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-23: el producto ya tiene un proveedor principal';
    END IF;
END$$

-- ---------- venta ----------
CREATE TRIGGER trg_venta_bi
BEFORE INSERT ON venta
FOR EACH ROW
BEGIN
    IF NEW.fecha > NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-20: la fecha de la venta no puede ser futura';
    END IF;
    IF NEW.estado <> 'PENDIENTE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-12: toda venta se registra en estado PENDIENTE';
    END IF;
END$$

CREATE TRIGGER trg_venta_bu
BEFORE UPDATE ON venta
FOR EACH ROW
BEGIN
    -- Solo el estado es modificable; cambiar fecha/cliente/empleado rompería RN-18.
    IF NEW.fecha <> OLD.fecha OR NEW.cliente_id <> OLD.cliente_id
       OR NEW.empleado_id <> OLD.empleado_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-12: de una venta registrada solo puede cambiar el estado';
    END IF;

    IF NEW.estado <> OLD.estado THEN
        IF OLD.estado <> 'PENDIENTE' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RN-12: PAGADA y CANCELADA son estados finales';
        END IF;
        IF NEW.estado = 'PAGADA'
           AND fn_pagado_venta(OLD.venta_id) < fn_total_venta(OLD.venta_id) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RN-12: la venta solo pasa a PAGADA cuando los pagos cubren el total';
        END IF;
        IF NEW.estado = 'CANCELADA'
           AND EXISTS (SELECT 1 FROM pago WHERE venta_id = OLD.venta_id) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RN-12: no se puede cancelar una venta que tiene pagos';
        END IF;
    END IF;
END$$

-- ---------- detalle_venta ----------
CREATE TRIGGER trg_detalle_venta_bi
BEFORE INSERT ON detalle_venta
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(10);
    DECLARE v_activo TINYINT;

    SET v_estado = (SELECT estado FROM venta    WHERE venta_id    = NEW.venta_id);
    SET v_activo = (SELECT activo FROM producto WHERE producto_id = NEW.producto_id);

    IF v_estado IS NOT NULL AND v_estado <> 'PENDIENTE' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-11: solo se agregan renglones a ventas PENDIENTE';
    END IF;
    IF v_activo = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-05: el producto está inactivo y no se puede vender';
    END IF;
END$$

-- Genera la salida de inventario con la fecha de la venta (RN-18)
CREATE TRIGGER trg_detalle_venta_ai
AFTER INSERT ON detalle_venta
FOR EACH ROW
BEGIN
    INSERT INTO movimiento_inventario
        (producto_id, tipo_movimiento_id, cantidad, fecha, venta_id, empleado_id, observacion)
    VALUES
        (NEW.producto_id,
         (SELECT tipo_movimiento_id FROM tipo_movimiento WHERE clave = 'SALIDA_VENTA'),
         NEW.cantidad,
         (SELECT fecha FROM venta WHERE venta_id = NEW.venta_id),
         NEW.venta_id,
         NULL,
         CONCAT('Salida por venta #', NEW.venta_id));
END$$

CREATE TRIGGER trg_detalle_venta_bu
BEFORE UPDATE ON detalle_venta
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN-11: los renglones de una venta no se modifican';
END$$

CREATE TRIGGER trg_detalle_venta_bd
BEFORE DELETE ON detalle_venta
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN-11: los renglones de una venta no se eliminan; cancele la venta';
END$$

-- ---------- pago ----------
CREATE TRIGGER trg_pago_bi
BEFORE INSERT ON pago
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(10);
    DECLARE v_fecha  DATETIME;
    DECLARE v_saldo  DECIMAL(12,2);
    DECLARE v_msg    VARCHAR(128);

    IF NEW.fecha > NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-20: la fecha del pago no puede ser futura';
    END IF;

    -- Bloquea la venta para serializar pagos concurrentes.
    SELECT estado, fecha INTO v_estado, v_fecha
      FROM venta WHERE venta_id = NEW.venta_id FOR UPDATE;

    IF v_estado IS NOT NULL THEN          -- si no existe, la FK rechaza el pago
        IF v_estado = 'CANCELADA' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-13: no se aceptan pagos para una venta CANCELADA';
        END IF;
        IF NEW.fecha < v_fecha THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-13: el pago no puede ser anterior a la venta';
        END IF;

        SET v_saldo = fn_total_venta(NEW.venta_id) - fn_pagado_venta(NEW.venta_id);
        IF NEW.monto > v_saldo THEN
            SET v_msg = CONCAT('RN-13: el pago excede el saldo pendiente de la venta (saldo = ', v_saldo, ')');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$

-- Pasa la venta a PAGADA al cubrir el total (RN-12)
CREATE TRIGGER trg_pago_ai
AFTER INSERT ON pago
FOR EACH ROW
BEGIN
    IF fn_pagado_venta(NEW.venta_id) >= fn_total_venta(NEW.venta_id) THEN
        UPDATE venta SET estado = 'PAGADA'
         WHERE venta_id = NEW.venta_id AND estado = 'PENDIENTE';
    END IF;
END$$

CREATE TRIGGER trg_pago_bu
BEFORE UPDATE ON pago
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-14: los pagos registrados no se modifican';
END$$

CREATE TRIGGER trg_pago_bd
BEFORE DELETE ON pago
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-14: los pagos registrados no se eliminan';
END$$

-- ---------- movimiento_inventario ----------
CREATE TRIGGER trg_movimiento_bi
BEFORE INSERT ON movimiento_inventario
FOR EACH ROW
BEGIN
    DECLARE v_signo      TINYINT;
    DECLARE v_clave      VARCHAR(20);
    DECLARE v_existencia INT;
    DECLARE v_msg        VARCHAR(128);

    IF NEW.fecha > NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-20: la fecha del movimiento no puede ser futura';
    END IF;

    SET v_signo = (SELECT signo FROM tipo_movimiento WHERE tipo_movimiento_id = NEW.tipo_movimiento_id);
    SET v_clave = (SELECT clave FROM tipo_movimiento WHERE tipo_movimiento_id = NEW.tipo_movimiento_id);

    -- RN-18: venta_id obligatoria en salidas por venta y devoluciones, y solo en ellas.
    IF v_clave IN ('SALIDA_VENTA', 'DEVOLUCION') AND NEW.venta_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-18: SALIDA_VENTA y DEVOLUCION deben indicar la venta de origen';
    END IF;
    IF v_clave NOT IN ('SALIDA_VENTA', 'DEVOLUCION') AND NEW.venta_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-18: solo SALIDA_VENTA y DEVOLUCION se asocian a una venta';
    END IF;

    -- RN-16: el saldo resultante no puede ser negativo. Bloquea la fila del producto.
    SELECT existencia INTO v_existencia
      FROM producto WHERE producto_id = NEW.producto_id FOR UPDATE;

    IF v_signo IS NOT NULL AND v_existencia IS NOT NULL
       AND v_existencia + v_signo * NEW.cantidad < 0 THEN
        SET v_msg = CONCAT('RN-16: existencia insuficiente del producto ', NEW.producto_id,
                           ' (disponible = ', v_existencia, ', solicitado = ', NEW.cantidad, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

-- Mantiene producto.existencia = Σ signo × cantidad (RN-19)
CREATE TRIGGER trg_movimiento_ai
AFTER INSERT ON movimiento_inventario
FOR EACH ROW
BEGIN
    SET @ve5_mov_en_curso = 1;
    UPDATE producto
       SET existencia = existencia
                      + (SELECT signo FROM tipo_movimiento
                          WHERE tipo_movimiento_id = NEW.tipo_movimiento_id) * NEW.cantidad
     WHERE producto_id = NEW.producto_id;
    SET @ve5_mov_en_curso = NULL;
END$$

CREATE TRIGGER trg_movimiento_bu
BEFORE UPDATE ON movimiento_inventario
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN-17: el historial de inventario no se modifica; registre un ajuste';
END$$

CREATE TRIGGER trg_movimiento_bd
BEFORE DELETE ON movimiento_inventario
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN-17: el historial de inventario no se elimina; registre un ajuste';
END$$

-- =============================================================================
-- 4. PROCEDIMIENTOS
-- =============================================================================

-- registrar_venta: crea la venta y sus renglones en una sola transacción (RN-07, RN-09).
--   p_fecha  NULL = ahora.
--   p_items  arreglo JSON: '[{"producto_id": 1, "cantidad": 2}, ...]'
--   Precio y costo se leen del catálogo en variables (SELECT ... INTO) y luego se
--   inserta con VALUES. No se usa INSERT ... SELECT FROM producto para evitar el
--   error 1442 en la cadena de triggers detalle → movimiento → producto.
--   Nota: START TRANSACTION confirma cualquier transacción abierta por el llamador.
CREATE PROCEDURE registrar_venta(
    IN  p_cliente_id   INT UNSIGNED,
    IN  p_empleado_id  INT UNSIGNED,
    IN  p_fecha        DATETIME,
    IN  p_items        LONGTEXT,
    OUT p_venta_id     INT UNSIGNED
)
BEGIN
    DECLARE v_n            INT;
    DECLARE i              INT DEFAULT 0;
    DECLARE v_producto_id  INT UNSIGNED;
    DECLARE v_cantidad     INT;
    DECLARE v_precio       DECIMAL(10,2);
    DECLARE v_costo        DECIMAL(10,2);
    DECLARE v_msg          VARCHAR(128);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_venta_id = NULL;
        RESIGNAL;
    END;

    IF p_items IS NULL OR JSON_VALID(p_items) = 0 OR JSON_TYPE(p_items) <> 'ARRAY'
       OR JSON_LENGTH(p_items) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN-07: la venta debe contener al menos un renglón';
    END IF;
    SET v_n = JSON_LENGTH(p_items);

    START TRANSACTION;

    INSERT INTO venta (cliente_id, empleado_id, fecha)
    VALUES (p_cliente_id, p_empleado_id, COALESCE(p_fecha, NOW()));
    SET p_venta_id = LAST_INSERT_ID();

    WHILE i < v_n DO
        SET v_producto_id = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', i, '].producto_id')));
        SET v_cantidad    = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', i, '].cantidad')));

        IF v_producto_id IS NULL OR v_cantidad IS NULL THEN
            SET v_msg = CONCAT('RN-07: el renglón ', i + 1, ' debe indicar producto_id y cantidad');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        SET v_precio = (SELECT precio_venta FROM producto WHERE producto_id = v_producto_id);
        SET v_costo  = (SELECT costo        FROM producto WHERE producto_id = v_producto_id);
        IF v_precio IS NULL THEN
            SET v_msg = CONCAT('RN-07: el producto ', v_producto_id, ' no existe');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        INSERT INTO detalle_venta (venta_id, producto_id, cantidad, precio_unitario, costo_unitario)
        VALUES (p_venta_id, v_producto_id, v_cantidad, v_precio, v_costo);

        SET i = i + 1;
    END WHILE;

    COMMIT;
END$$

-- cancelar_venta: cancela una venta PENDIENTE sin pagos y repone el inventario
-- con un movimiento DEVOLUCION por renglón (RN-12, RN-18).
--   p_fecha NULL = ahora.
CREATE PROCEDURE cancelar_venta(
    IN p_venta_id     INT UNSIGNED,
    IN p_empleado_id  INT UNSIGNED,
    IN p_fecha        DATETIME
)
BEGIN
    DECLARE v_estado       VARCHAR(10);
    DECLARE v_fecha_venta  DATETIME;
    DECLARE v_fecha        DATETIME;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_fecha = COALESCE(p_fecha, NOW());

    START TRANSACTION;

    SELECT estado, fecha INTO v_estado, v_fecha_venta
      FROM venta WHERE venta_id = p_venta_id FOR UPDATE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta indicada no existe';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-12: solo se cancelan ventas PENDIENTE';
    END IF;
    IF v_fecha < v_fecha_venta THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RN-20: la cancelación no puede ser anterior a la venta';
    END IF;

    -- trg_venta_bu valida que no tenga pagos.
    UPDATE venta SET estado = 'CANCELADA' WHERE venta_id = p_venta_id;

    INSERT INTO movimiento_inventario
        (producto_id, tipo_movimiento_id, cantidad, fecha, venta_id, empleado_id, observacion)
    SELECT d.producto_id,
           (SELECT tipo_movimiento_id FROM tipo_movimiento WHERE clave = 'DEVOLUCION'),
           d.cantidad,
           v_fecha,
           d.venta_id,
           p_empleado_id,
           CONCAT('Devolución por cancelación de venta #', d.venta_id)
      FROM detalle_venta d
     WHERE d.venta_id = p_venta_id;

    COMMIT;
END$$

DELIMITER ;

-- =============================================================================
-- 5. VISTAS
-- =============================================================================

-- Existencias actuales con marca de bajo umbral (RF-11). Bajo umbral: existencia < stock_minimo.
CREATE VIEW v_existencias AS
SELECT p.producto_id,
       p.sku,
       p.nombre,
       c.nombre                                       AS categoria,
       p.existencia,
       p.stock_minimo,
       CASE WHEN p.existencia < p.stock_minimo THEN 1 ELSE 0 END AS bajo_umbral,
       p.activo
  FROM producto  p
  JOIN categoria c ON c.categoria_id = p.categoria_id;

-- Conciliación: saldo almacenado contra Σ signo × cantidad del historial (RN-19, RF-15)
CREATE VIEW v_conciliacion_inventario AS
SELECT p.producto_id,
       p.sku,
       p.nombre,
       p.existencia                                    AS existencia_registrada,
       COALESCE(SUM(t.signo * m.cantidad), 0)          AS existencia_calculada,
       p.existencia - COALESCE(SUM(t.signo * m.cantidad), 0) AS diferencia
  FROM producto p
  LEFT JOIN movimiento_inventario m ON m.producto_id = p.producto_id
  LEFT JOIN tipo_movimiento       t ON t.tipo_movimiento_id = m.tipo_movimiento_id
 GROUP BY p.producto_id, p.sku, p.nombre, p.existencia;

-- Total, pagado y saldo de cada venta (RN-10, RN-13, RF-13)
CREATE VIEW v_venta_saldos AS
SELECT v.venta_id,
       v.fecha,
       v.cliente_id,
       CONCAT_WS(' ', c.nombre, c.apellido)           AS cliente,
       v.estado,
       COALESCE(d.total, 0)                           AS total,
       COALESCE(pg.pagado, 0)                         AS pagado,
       COALESCE(d.total, 0) - COALESCE(pg.pagado, 0)  AS saldo
  FROM venta   v
  JOIN cliente c ON c.cliente_id = v.cliente_id
  LEFT JOIN (SELECT venta_id, SUM(cantidad * precio_unitario) AS total
               FROM detalle_venta GROUP BY venta_id) d  ON d.venta_id  = v.venta_id
  LEFT JOIN (SELECT venta_id, SUM(monto) AS pagado
               FROM pago GROUP BY venta_id)          pg ON pg.venta_id = v.venta_id;

-- Fin de 01_ddl.sql
