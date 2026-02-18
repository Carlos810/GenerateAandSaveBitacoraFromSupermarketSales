-- =====================================================
-- PRIMERO: Crear los tipos necesarios para los parámetros
-- =====================================================

-- Tipo para recibir la colección de productos (clave-valor: id_producto - cantidad)
CREATE OR REPLACE TYPE producto_venta_type AS OBJECT (
    id_producto NUMBER(38),
    cantidad NUMBER(10)
);
/

-- Tipo TABLE para recibir múltiples productos
CREATE OR REPLACE TYPE productos_venta_table AS TABLE OF producto_venta_type;
/

-- =====================================================
-- SP PRINCIPAL: Procesar Venta con Validaciones
-- =====================================================
create PROCEDURE sp_registrar_venta (
    p_id_cliente IN NUMBER,
    p_productos IN productos_venta_table,
    p_usuario_registro IN VARCHAR2,
    p_mensaje OUT VARCHAR2,
    p_codigo_resultado OUT NUMBER  -- 0 = éxito, 1 = error
)
IS
    -- Variables para control
    v_id_venta NUMBER(38);
    v_cliente_existe NUMBER;
    v_error_detalle VARCHAR2(4000);
    v_producto_no_disponible EXCEPTION;
    v_cliente_no_existe EXCEPTION;
    v_sin_productos EXCEPTION;
    v_error_msg VARCHAR2(200);

    -- Cursor para validar y procesar productos
    CURSOR c_productos IS
        SELECT pv.id_producto, pv.cantidad, p.stock, p.precio, p.nombre_producto
        FROM TABLE(p_productos) pv
        INNER JOIN producto p ON p.id_producto = pv.id_producto
        FOR UPDATE OF p.stock;  -- Bloquear filas para actualización

    -- Variable para el cursor
    v_producto c_productos%ROWTYPE;

BEGIN
    -- Inicializar valores
    p_mensaje := '';
    p_codigo_resultado := 0;
    v_error_detalle := '';

    -- =====================================================
    -- VALIDACIÓN 1: Verificar que la lista de productos no esté vacía
    -- =====================================================
    IF p_productos IS NULL OR p_productos.COUNT = 0 THEN
        RAISE v_sin_productos;
    END IF;

    -- =====================================================
    -- VALIDACIÓN 2: Verificar existencia del cliente
    -- =====================================================
    BEGIN
        SELECT COUNT(1) INTO v_cliente_existe
        FROM cliente
        WHERE id_cliente = p_id_cliente AND activo = 1;

        IF v_cliente_existe = 0 THEN
            RAISE v_cliente_no_existe;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE v_cliente_no_existe;
    END;

    -- =====================================================
    -- VALIDACIÓN 3: Verificar disponibilidad de stock para cada producto
    -- =====================================================
    FOR v_producto IN c_productos LOOP
        -- Verificar si el producto existe y tiene stock suficiente
        IF v_producto.stock < v_producto.cantidad THEN
            v_error_detalle := v_error_detalle ||
                'Producto ' || v_producto.nombre_producto ||
                ' (ID: ' || v_producto.id_producto ||
                ') - Stock disponible: ' || v_producto.stock ||
                ', Solicitado: ' || v_producto.cantidad || '. ';
        END IF;
    END LOOP;

    -- Si hay errores de stock, lanzar excepción
    IF v_error_detalle IS NOT NULL AND LENGTH(v_error_detalle) > 0 THEN
        v_error_msg := 'Stock insuficiente para los siguientes productos: ' || v_error_detalle;
        RAISE v_producto_no_disponible;
    END IF;

    -- =====================================================
    -- INICIO DE TRANSACCIÓN: Todas las validaciones pasaron
    -- =====================================================

    -- 1. Insertar cabecera de venta
    INSERT INTO venta (
        id_cliente,
        usuario_registro
    ) VALUES (
        p_id_cliente,
        p_usuario_registro
    ) RETURNING id_venta INTO v_id_venta;

    -- 2. Procesar cada producto (insertar detalle y actualizar stock)
    FOR v_producto IN c_productos LOOP

        -- Insertar detalle de venta
        INSERT INTO venta_productos (
            id_venta,
            id_producto,
            cantidad,
            precio_unitario,
            descripcion
        ) VALUES (
            v_id_venta,
            v_producto.id_producto,
            v_producto.cantidad,
            v_producto.precio,
            'Venta registrada por: ' || p_usuario_registro
        );

        -- Actualizar stock del producto
        UPDATE producto
        SET stock = stock - v_producto.cantidad,
            fecha_modificacion = SYSTIMESTAMP
        WHERE CURRENT OF c_productos;  -- Usar CURRENT OF para actualizar la fila bloqueada

    END LOOP;

    -- =====================================================
    -- Si todo salió bien, hacer COMMIT y preparar mensaje de éxito
    -- =====================================================
    COMMIT;

    p_mensaje := 'Venta registrada exitosamente. ID Venta: ' || v_id_venta ||
                 '. Productos procesados: ' || p_productos.COUNT;
    p_codigo_resultado := 0;

-- =====================================================
-- MANEJO DE EXCEPCIONES
-- =====================================================
EXCEPTION
    WHEN v_sin_productos THEN
        ROLLBACK;
        p_mensaje := 'Error: No se especificaron productos para la venta.';
        p_codigo_resultado := 1;

    WHEN v_cliente_no_existe THEN
        ROLLBACK;
        p_mensaje := 'Error: El cliente con ID ' || p_id_cliente ||
                     ' no existe o no está activo.';
        p_codigo_resultado := 1;

    WHEN v_producto_no_disponible THEN
        ROLLBACK;
        p_mensaje := v_error_msg;
        p_codigo_resultado := 1;

    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        p_mensaje := 'Error: Producto duplicado en la misma venta.';
        p_codigo_resultado := 1;

    WHEN OTHERS THEN
        ROLLBACK;
        p_mensaje := 'Error inesperado: ' || SQLERRM;
        p_codigo_resultado := 1;

END sp_registrar_venta;
/

-- =====================================================
-- EJEMPLO DE USO DESDE PL/SQL
-- =====================================================
/*
DECLARE
    v_productos productos_venta_table;
    v_mensaje VARCHAR2(4000);
    v_codigo NUMBER;
BEGIN
    -- Crear la colección de productos
    v_productos := productos_venta_table(
        producto_venta_type(1, 2),  -- ID producto 1, cantidad 2
        producto_venta_type(3, 1),  -- ID producto 3, cantidad 1
        producto_venta_type(5, 3)   -- ID producto 5, cantidad 3
    );
    
    -- Ejecutar el procedimiento
    sp_registrar_venta(
        p_id_cliente => 1,
        p_productos => v_productos,
        p_usuario_registro => 'SISTEMA_VENTAS',
        p_mensaje => v_mensaje,
        p_codigo_resultado => v_codigo
    );
    
    -- Mostrar resultado
    DBMS_OUTPUT.put_line('Código: ' || v_codigo);
    DBMS_OUTPUT.put_line('Mensaje: ' || v_mensaje);
END;
/
*/