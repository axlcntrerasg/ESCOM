-- =============================================
-- Proyecto: Sistema Gestor de Clínica (SQL Server)
-- Archivo: 04_vistas.sql
-- Descripción: Vistas (consultas guardadas).
-- Orden: 4 (después de 03_funciones.sql)
-- =============================================

USE clinica;
GO

-- =============================================
-- Vista: vw_Citas
-- Descripción: Todas las citas con paciente, médico, especialidad, consultorio y pago.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_Citas
AS
SELECT Cita.Folio_Cita,
       Cita.Fecha_Cita,
       Cita.Hora_Cita,
       Cita.Hora_Fin,
       Cita.ID_Paciente,
       Usuario.CURP AS CURP_Paciente,
       CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M) AS Paciente,
       Cita.ID_Medico,
       Empleado.CURP AS CURP_Medico,
       -- nombre del médico (subconsulta porque Usuario ya se usa para el paciente)
       (SELECT CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M)
          FROM dbo.Usuario WHERE Usuario.CURP = Empleado.CURP) AS Medico,
       Especialidad.ID_Especialidad,
       Especialidad.Nombre AS Especialidad,
       Consultorio.Numero AS Consultorio,
       Cita.ID_EstatusCita,
       EstatusCita.EstatusCita,
       Cita.Fecha_Reservacion,
       Cita.Linea_Pago,
       Cita.Fecha_Limite_Pago,
       Cita.Fecha_Cancelacion,
       Especialidad.Costo_Consulta,
       Pago_Cita.Monto AS Monto_Pagado,
       Pago_Cita.Monto_Devuelto,
       Pago_Cita.Estatus_Pago,
       Receta.Folio_Receta
  FROM dbo.Cita
  JOIN dbo.Paciente      ON Paciente.ID_Paciente = Cita.ID_Paciente
  JOIN dbo.Usuario       ON Usuario.CURP = Paciente.CURP
  JOIN dbo.Medico        ON Medico.ID_Medico = Cita.ID_Medico
  JOIN dbo.Empleado      ON Empleado.ID_Empleado = Medico.ID_Empleado
  JOIN dbo.Especialidad  ON Especialidad.ID_Especialidad = Medico.ID_Especialidad
  JOIN dbo.Consultorio   ON Consultorio.ID_Consultorio = Cita.ID_Consultorio
  JOIN dbo.EstatusCita   ON EstatusCita.ID_EstatusCita = Cita.ID_EstatusCita
  LEFT JOIN dbo.Pago_Cita ON Pago_Cita.Folio_Cita = Cita.Folio_Cita
  LEFT JOIN dbo.Receta    ON Receta.Folio_Cita = Cita.Folio_Cita;
GO

-- =============================================
-- Vista: vw_MisCitas
-- Descripción: Citas del paciente que inició sesión.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_MisCitas
AS
SELECT Folio_Cita, Fecha_Cita, Hora_Cita, Hora_Fin, Medico, Especialidad, Consultorio,
       ID_EstatusCita, EstatusCita, Linea_Pago, Fecha_Limite_Pago, Costo_Consulta,
       Monto_Pagado, Monto_Devuelto, Estatus_Pago, Fecha_Cancelacion
  FROM dbo.vw_Citas
 WHERE CURP_Paciente = CAST(SESSION_CONTEXT(N'curp') AS CHAR(18));
GO

-- =============================================
-- Vista: vw_AgendaMedico
-- Descripción: Citas del médico que inició sesión.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_AgendaMedico
AS
SELECT Folio_Cita, Fecha_Cita, Hora_Cita, Hora_Fin, ID_Paciente, Paciente, Consultorio,
       ID_EstatusCita, EstatusCita, Folio_Receta
  FROM dbo.vw_Citas
 WHERE CURP_Medico = CAST(SESSION_CONTEXT(N'curp') AS CHAR(18));
GO

-- =============================================
-- Vista: vw_ComprobanteCita
-- Descripción: Comprobante de cita con línea de pago y leyendas.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_ComprobanteCita
AS
SELECT Cita.Folio_Cita,
       CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M) AS Nombre_Paciente,
       Cita.Fecha_Cita AS Fecha,
       CONCAT(CONVERT(VARCHAR(5), Cita.Hora_Cita, 108), N' - ', CONVERT(VARCHAR(5), Cita.Hora_Fin, 108)) AS Horario,
       Consultorio.Numero AS Consultorio,
       Especialidad.Nombre AS Especialidad,
       CONCAT(N'Dr(a). ', (SELECT CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M)
          FROM dbo.Usuario WHERE Usuario.CURP = Empleado.CURP)) AS Doctor,
       Especialidad.Costo_Consulta AS Costo,
       Cita.Linea_Pago,
       Cita.Fecha_Reservacion,
       Cita.Fecha_Limite_Pago,
       EstatusCita.EstatusCita,
       N'Tienes 8 horas para realizar tu pago con esta línea de pago. Si no pagas antes de la fecha límite, la cita se cancela y el horario se libera.' AS Leyenda_Pago,
       N'Política de cancelación: con 48 h o más de anticipación se devuelve el 100 %; entre 24 y 48 h, el 50 %; con menos de 24 h, 0 %.' AS Leyenda_Cancelacion
  FROM dbo.Cita
  JOIN dbo.Paciente     ON Paciente.ID_Paciente = Cita.ID_Paciente
  JOIN dbo.Usuario      ON Usuario.CURP = Paciente.CURP
  JOIN dbo.Medico       ON Medico.ID_Medico = Cita.ID_Medico
  JOIN dbo.Empleado     ON Empleado.ID_Empleado = Medico.ID_Empleado
  JOIN dbo.Especialidad ON Especialidad.ID_Especialidad = Medico.ID_Especialidad
  JOIN dbo.Consultorio  ON Consultorio.ID_Consultorio = Cita.ID_Consultorio
  JOIN dbo.EstatusCita  ON EstatusCita.ID_EstatusCita = Cita.ID_EstatusCita;
GO

-- =============================================
-- Vista: vw_Medicos
-- Descripción: Médicos activos con especialidad, costo y consultorio.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_Medicos
AS
SELECT Medico.ID_Medico,
       CONCAT(N'Dr(a). ', Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M) AS Doctor,
       Especialidad.ID_Especialidad,
       Especialidad.Nombre AS Especialidad,
       Especialidad.Costo_Consulta,
       Consultorio.Numero AS Consultorio,
       Consultorio.Piso
  FROM dbo.Medico
  JOIN dbo.Empleado      ON Empleado.ID_Empleado = Medico.ID_Empleado
  JOIN dbo.Usuario       ON Usuario.CURP = Empleado.CURP
  JOIN dbo.Especialidad ON Especialidad.ID_Especialidad = Medico.ID_Especialidad
  JOIN dbo.Consultorio  ON Consultorio.ID_Consultorio = Medico.ID_Consultorio
 WHERE Usuario.Estatus = N'Activo';
GO

-- =============================================
-- Vista: vw_HorarioMedicos
-- Descripción: Horario de trabajo de cada médico activo.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_HorarioMedicos
AS
SELECT Medico.ID_Medico,
       Medico.ID_Empleado,
       CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P) AS Medico,
       Especialidad.Nombre AS Especialidad,
       Medico.ID_Consultorio,
       Consultorio.Numero AS Consultorio,
       Jornada.Dia_Semana,
       CASE Jornada.Dia_Semana WHEN 1 THEN N'Lunes' WHEN 2 THEN N'Martes' WHEN 3 THEN N'Miércoles'
                         WHEN 4 THEN N'Jueves' WHEN 5 THEN N'Viernes' WHEN 6 THEN N'Sábado'
                         ELSE N'Domingo' END AS Dia,
       Jornada.Hora_Inicio,
       Jornada.Hora_Fin
  FROM dbo.Medico
  JOIN dbo.Empleado      ON Empleado.ID_Empleado = Medico.ID_Empleado
  JOIN dbo.Usuario       ON Usuario.CURP = Empleado.CURP AND Usuario.Estatus = N'Activo'
  JOIN dbo.Especialidad ON Especialidad.ID_Especialidad = Medico.ID_Especialidad
  JOIN dbo.Consultorio  ON Consultorio.ID_Consultorio = Medico.ID_Consultorio
  JOIN dbo.Jornada       ON Jornada.ID_Empleado = Medico.ID_Empleado;
GO

-- =============================================
-- Vista: vw_Inventario
-- Descripción: Inventario de farmacia: stock disponible, caducado y por caducar.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_Inventario
AS
SELECT Medicamento.ID_Medicamento,
       Medicamento.Nombre,
       Medicamento.Precio,
       Medicamento.Requiere_Receta,
       ISNULL(SUM(CASE WHEN Lote.Caducidad >= CAST(GETDATE() AS DATE) THEN Lote.Stock END), 0) AS Stock_Disponible,
       ISNULL(SUM(CASE WHEN Lote.Caducidad <  CAST(GETDATE() AS DATE) THEN Lote.Stock END), 0) AS Stock_Caducado,
       MIN(CASE WHEN Lote.Stock > 0 AND Lote.Caducidad >= CAST(GETDATE() AS DATE) THEN Lote.Caducidad END) AS Proxima_Caducidad,
       ISNULL(SUM(CASE WHEN Lote.Caducidad >= CAST(GETDATE() AS DATE)
                        AND Lote.Caducidad <  DATEADD(DAY, 60, CAST(GETDATE() AS DATE)) THEN Lote.Stock END), 0) AS Piezas_Caducan_60_Dias
  FROM dbo.Medicamento
  LEFT JOIN dbo.Lote ON Lote.ID_Medicamento = Medicamento.ID_Medicamento
 GROUP BY Medicamento.ID_Medicamento, Medicamento.Nombre, Medicamento.Precio, Medicamento.Requiere_Receta;
GO

-- =============================================
-- Vista: vw_TicketCombinado
-- Descripción: Ticket por cliente y día: pagos de citas, servicios y medicamentos con total.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_TicketCombinado
AS
WITH Pagos AS (
    -- Pagos de citas (el neto descuenta lo devuelto)
    SELECT Cita.ID_Paciente, CAST(NULL AS NVARCHAR(150)) AS Nombre_Cliente,
           CAST(Pago_Cita.Fecha_Pago AS DATE) AS Fecha, 1 AS Orden, N'Cita' AS Concepto,
           Cita.Folio_Cita AS Folio,
           CONCAT(N'Consulta de ', Especialidad.Nombre, N' (', EstatusCita.EstatusCita, N')') AS Detalle,
           Pago_Cita.Monto, Pago_Cita.Monto_Devuelto AS Devuelto,
           Pago_Cita.Monto - Pago_Cita.Monto_Devuelto AS Neto, Pago_Cita.Metodo_Pago
      FROM dbo.Pago_Cita
      JOIN dbo.Cita         ON Cita.Folio_Cita = Pago_Cita.Folio_Cita
      JOIN dbo.Medico       ON Medico.ID_Medico = Cita.ID_Medico
      JOIN dbo.Especialidad ON Especialidad.ID_Especialidad = Medico.ID_Especialidad
      JOIN dbo.EstatusCita  ON EstatusCita.ID_EstatusCita = Cita.ID_EstatusCita
    UNION ALL
    -- Pagos de servicios
    SELECT Venta_Servicio.ID_Paciente, Venta_Servicio.Nombre_Cliente,
           CAST(Pago_Servicio.Fecha_Pago AS DATE), 2, N'Servicio', Venta_Servicio.ID_Venta_Serv,
           (SELECT STRING_AGG(CONCAT(Servicio.Nombre, N' x', Detalle_Venta_Serv.Cantidad), N', ')
              FROM dbo.Detalle_Venta_Serv
              JOIN dbo.Servicio ON Servicio.ID_Servicio = Detalle_Venta_Serv.ID_Servicio
             WHERE Detalle_Venta_Serv.ID_Venta_Serv = Venta_Servicio.ID_Venta_Serv),
           Pago_Servicio.Total, 0, Pago_Servicio.Total, Pago_Servicio.Metodo_Pago
      FROM dbo.Pago_Servicio
      JOIN dbo.Venta_Servicio ON Venta_Servicio.ID_Venta_Serv = Pago_Servicio.ID_Venta_Serv
    UNION ALL
    -- Pagos de medicamentos
    SELECT Venta_Medicamento.ID_Paciente, Venta_Medicamento.Nombre_Cliente,
           CAST(Pago_Medicamento.Fecha_Pago AS DATE), 3, N'Medicamento', Venta_Medicamento.ID_Venta_Med,
           (SELECT STRING_AGG(CONCAT(Medicamento.Nombre, N' x', Detalle_Venta_Med.Cantidad), N', ')
              FROM dbo.Detalle_Venta_Med
              JOIN dbo.Lote        ON Lote.ID_Lote = Detalle_Venta_Med.ID_Lote
              JOIN dbo.Medicamento ON Medicamento.ID_Medicamento = Lote.ID_Medicamento
             WHERE Detalle_Venta_Med.ID_Venta_Med = Venta_Medicamento.ID_Venta_Med),
           Pago_Medicamento.Total, 0, Pago_Medicamento.Total, Pago_Medicamento.Metodo_Pago
      FROM dbo.Pago_Medicamento
      JOIN dbo.Venta_Medicamento ON Venta_Medicamento.ID_Venta_Med = Pago_Medicamento.ID_Venta_Med
)
SELECT CASE WHEN Pagos.ID_Paciente IS NOT NULL THEN N'Paciente' ELSE N'Externo' END AS Tipo_Cliente,
       Pagos.ID_Paciente,
       CASE WHEN Usuario.CURP IS NOT NULL THEN CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M)
            ELSE Pagos.Nombre_Cliente END AS Cliente,
       Pagos.Fecha, Pagos.Orden, Pagos.Concepto, Pagos.Folio, Pagos.Detalle, Pagos.Metodo_Pago,
       Pagos.Monto, Pagos.Devuelto, Pagos.Neto,
       -- total del cliente en ese día
       SUM(Pagos.Neto) OVER (PARTITION BY COALESCE(CAST(Pagos.ID_Paciente AS NVARCHAR(20)), N'EXT:' + Pagos.Nombre_Cliente),
                                          Pagos.Fecha) AS Total_Del_Dia
  FROM Pagos
  LEFT JOIN dbo.Paciente ON Paciente.ID_Paciente = Pagos.ID_Paciente
  LEFT JOIN dbo.Usuario  ON Usuario.CURP = Paciente.CURP;
GO

-- =============================================
-- Vista: vw_IngresosPorDia
-- Descripción: Ingresos por día y por tipo.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_IngresosPorDia
AS
WITH Movimientos AS (
    SELECT CAST(Fecha_Pago AS DATE) AS Dia, N'Citas' AS Tipo, Monto - Monto_Devuelto AS Neto FROM dbo.Pago_Cita
    UNION ALL
    SELECT CAST(Fecha_Pago AS DATE), N'Medicamentos', Total FROM dbo.Pago_Medicamento
    UNION ALL
    SELECT CAST(Fecha_Pago AS DATE), N'Servicios', Total FROM dbo.Pago_Servicio
)
SELECT Dia, Tipo, COUNT(*) AS Operaciones, SUM(Neto) AS Ingreso_Neto
  FROM Movimientos
 GROUP BY Dia, Tipo;
GO

-- =============================================
-- Vista: vw_RecetaCompleta
-- Descripción: Receta con doctor, cédula, paciente, edad y medicamentos.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_RecetaCompleta
AS
SELECT Receta.Folio_Receta,
       Receta.Fecha,
       CONCAT(N'Dr(a). ', (SELECT CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M)
          FROM dbo.Usuario WHERE Usuario.CURP = Empleado.CURP)) AS Nombre_Doctor,
       Medico.Cedula_Pro AS Cedula_Profesional,
       CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M) AS Nombre_Paciente,
       Usuario.Edad,
       Receta.Diagnostico,
       -- lista de medicamentos de la receta
       (SELECT STRING_AGG(CONCAT(Medicamento.Nombre, N': ', Receta_Medicamento.Dosis, N' (', Receta_Medicamento.Cantidad, N' pza.)',
                                 CASE WHEN Receta_Medicamento.Indicaciones IS NOT NULL
                                      THEN N' - ' + Receta_Medicamento.Indicaciones ELSE N'' END), N'; ')
          FROM dbo.Receta_Medicamento
          JOIN dbo.Medicamento ON Medicamento.ID_Medicamento = Receta_Medicamento.ID_Medicamento
         WHERE Receta_Medicamento.Folio_Receta = Receta.Folio_Receta) AS Medicamentos,
       Receta.Tratamiento,
       Receta.Observaciones,
       Cita.ID_Medico,
       Cita.ID_Paciente
  FROM dbo.Receta
  JOIN dbo.Cita     ON Cita.Folio_Cita = Receta.Folio_Cita
  JOIN dbo.Medico   ON Medico.ID_Medico = Cita.ID_Medico
  JOIN dbo.Empleado ON Empleado.ID_Empleado = Medico.ID_Empleado
  JOIN dbo.Paciente ON Paciente.ID_Paciente = Cita.ID_Paciente
  JOIN dbo.Usuario  ON Usuario.CURP = Paciente.CURP;
GO

-- =============================================
-- Vista: vw_HistorialMedicoPaciente
-- Descripción: Historial médico de cada paciente.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_HistorialMedicoPaciente
AS
SELECT Historial_Medico.ID_Historial_Medico,
       Historial_Medico.ID_Paciente,
       CONCAT(Usuario.Nombre, N' ', Usuario.Apellido_P, N' ', Usuario.Apellido_M) AS Nombre_Paciente,
       Usuario.Edad,
       Historial_Medico.Alergias,
       Historial_Medico.Tipo_Sangre,
       Historial_Medico.Padecimientos_Previos,
       Historial_Medico.Peso,
       Historial_Medico.Estatura
  FROM dbo.Historial_Medico
  JOIN dbo.Paciente ON Paciente.ID_Paciente = Historial_Medico.ID_Paciente
  JOIN dbo.Usuario  ON Usuario.CURP = Paciente.CURP;
GO

-- =============================================
-- Vista: vw_SolicitudesCancelacion
-- Descripción: Solicitudes de cancelación de los médicos.
-- =============================================
CREATE OR ALTER VIEW dbo.vw_SolicitudesCancelacion
AS
SELECT Solicitud_Cancelacion.ID_Solicitud,
       Solicitud_Cancelacion.Estatus,
       Solicitud_Cancelacion.Fecha_Solicitud,
       Solicitud_Cancelacion.Motivo,
       Cita.Folio_Cita,
       Cita.Fecha_Cita,
       Cita.Hora_Cita,
       Solicitud_Cancelacion.ID_Medico,
       vw_Citas.Medico,
       vw_Citas.Especialidad,
       vw_Citas.Paciente,
       vw_Citas.EstatusCita,
       dbo.fn_CancelacionesDoctorMes(Solicitud_Cancelacion.ID_Medico) AS Cancelaciones_Del_Mes,
       Solicitud_Cancelacion.ID_Recepcionista,
       Solicitud_Cancelacion.Fecha_Respuesta,
       Solicitud_Cancelacion.Comentario
  FROM dbo.Solicitud_Cancelacion
  JOIN dbo.Cita     ON Cita.Folio_Cita = Solicitud_Cancelacion.Folio_Cita
  JOIN dbo.vw_Citas ON vw_Citas.Folio_Cita = Solicitud_Cancelacion.Folio_Cita;
GO

-- =============================================
-- Vista: vw_MisDatos
-- Descripción: Datos del usuario que inició sesión (sin contraseña).
-- =============================================
CREATE OR ALTER VIEW dbo.vw_MisDatos
AS
SELECT Usuario.CURP, Usuario.Nombre, Usuario.Apellido_P, Usuario.Apellido_M, Usuario.Fecha_Nac, Usuario.Edad, Usuario.Email,
       Usuario.Tel_Personal, Usuario.Tel_Casa, Usuario.Tel_Emergencia,
       Usuario.Calle, Usuario.Numero, Usuario.Colonia, Usuario.Ciudad, Usuario.Estado, Usuario.Codigo_P,
       Paciente.ID_Paciente, Empleado.ID_Empleado, Medico.ID_Medico, Medico.Cedula_Pro, Especialidad.Nombre AS Especialidad,
       Consultorio.Numero AS Consultorio
  FROM dbo.Usuario
  LEFT JOIN dbo.Paciente      ON Paciente.CURP = Usuario.CURP
  LEFT JOIN dbo.Empleado      ON Empleado.CURP = Usuario.CURP
  LEFT JOIN dbo.Medico        ON Medico.ID_Empleado = Empleado.ID_Empleado
  LEFT JOIN dbo.Especialidad ON Especialidad.ID_Especialidad = Medico.ID_Especialidad
  LEFT JOIN dbo.Consultorio  ON Consultorio.ID_Consultorio = Medico.ID_Consultorio
 WHERE Usuario.CURP = CAST(SESSION_CONTEXT(N'curp') AS CHAR(18));
GO

