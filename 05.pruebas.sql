/*INFOA Verificar:
* Creación de vistas.
* Validaciones dentro del SP.
* Control de stock.
* Uso de RETURNING INTO.
 */


--ESCENARIO A – Ver vistas
SELECT * FROM VW_PRODUCTOS_CATEGORIA;
SELECT * FROM VW_VENTAS_DETALLE;

--ESCENARIO B – Venta exitosa
BEGIN
    SP_REGISTRAR_VENTA(
        p_id_cliente  => 1,
        p_id_producto => 1,
        p_cantidad    => 2,
        p_descripcion => 'Venta exitosa prueba'
    );
END;
/



