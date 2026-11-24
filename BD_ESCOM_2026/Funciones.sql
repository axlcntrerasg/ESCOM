-- =============================================
-- Proyecto: Sistema Gestor de Clínica (SQL Server)
-- Archivo: 03_funciones.sql
-- Descripción: Funciones (cálculos que se reutilizan).
-- Orden: 3 (después de 02_datos_prueba.sql)
-- =============================================

USE clinica;
GO

-- =============================================
-- Función: fn_DiaSemana
-- Descripción: Regresa el día de la semana de una fecha (1 = lunes ... 7 = domingo).
-- =============================================
CREATE OR ALTER FUNCTION dbo.fn_DiaSemana (@Fecha DATE)
RETURNS TINYINT
AS
BEGIN
    RETURN ((DATEPART(WEEKDAY, @Fecha) + @@DATEFIRST - 2) % 7) + 1;
END
GO

-- =============================================
-- Función: fn_InicioCita
-- Descripción: Une la fecha y la hora de una cita en un solo valor.
-- =============================================
CREATE OR ALTER FUNCTION dbo.fn_InicioCita (@Fecha DATE, @Hora TIME(0))
RETURNS DATETIME2(0)
AS
BEGIN
    RETURN DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00:00' AS TIME(0)), @Hora),
                   CAST(@Fecha AS DATETIME2(0)));
END
GO

-- =============================================
-- Función: fn_CalcularReembolso
-- Descripción: Porcentaje a devolver al cancelar: 100 %, 50 % o 0 %.
-- =============================================
CREATE OR ALTER FUNCTION dbo.fn_CalcularReembolso (@InicioCita DATETIME2(0), @Momento DATETIME2(0), @Cancela CHAR(1))
RETURNS DECIMAL(3,2)
AS
BEGIN
    DECLARE @Horas DECIMAL(10,2) = DATEDIFF(MINUTE, @Momento, @InicioCita) / 60.0;
    RETURN CASE
               WHEN @Cancela = 'D' THEN 1.00
               WHEN @Horas >= 48   THEN 1.00
               WHEN @Horas >= 24   THEN 0.50
               ELSE 0.00
           END;
END
GO

-- =============================================
-- Función: fn_StockDisponible
-- Descripción: Piezas disponibles de un medicamento (sin lotes caducados).
-- =============================================
CREATE OR ALTER FUNCTION dbo.fn_StockDisponible (@ID_Medicamento INT)
RETURNS INT
AS
BEGIN
    RETURN (SELECT ISNULL(SUM(Stock), 0)
              FROM dbo.Lote
             WHERE ID_Medicamento = @ID_Medicamento
               AND Caducidad >= CAST(GETDATE() AS DATE));
END
GO

-- =============================================
-- Función: fn_CancelacionesDoctorMes
-- Descripción: Citas canceladas por un médico en el mes actual (máximo 3).
-- =============================================
CREATE OR ALTER FUNCTION dbo.fn_CancelacionesDoctorMes (@ID_Medico INT)
RETURNS INT
AS
BEGIN
    RETURN (SELECT COUNT(*)
              FROM dbo.Cita
             WHERE ID_Medico = @ID_Medico
               AND ID_EstatusCita = 5
               AND YEAR(Fecha_Cancelacion)  = YEAR(GETDATE())
               AND MONTH(Fecha_Cancelacion) = MONTH(GETDATE()));
END
GO

-- =============================================
-- Función: fn_PuedeIniciarSesion
-- Descripción: Indica si un usuario puede entrar ahora con un perfil.
-- =============================================
CREATE OR ALTER FUNCTION dbo.fn_PuedeIniciarSesion (@CURP CHAR(18), @Rol NVARCHAR(20))
RETURNS BIT
AS
BEGIN
    DECLARE @Ahora TIME(0) = CAST(GETDATE() AS TIME(0));
    DECLARE @Dia   TINYINT = dbo.fn_DiaSemana(CAST(GETDATE() AS DATE));

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE CURP = @CURP AND Estatus = N'Activo')
        RETURN 0;

    IF @Rol = N'Paciente'
        RETURN CASE WHEN EXISTS (SELECT 1 FROM dbo.Paciente WHERE CURP = @CURP) THEN 1 ELSE 0 END;

    IF @Rol = N'Administrador'
        RETURN CASE WHEN EXISTS (SELECT 1 FROM dbo.Administrador JOIN dbo.Empleado ON Empleado.ID_Empleado = Administrador.ID_Empleado
                                  WHERE Empleado.CURP = @CURP) THEN 1 ELSE 0 END;

    IF @Rol IN (N'Medico', N'Recepcionista')
        RETURN CASE WHEN EXISTS (
                   SELECT 1
                     FROM dbo.Empleado
                     JOIN dbo.Jornada ON Jornada.ID_Empleado = Empleado.ID_Empleado
                    WHERE Empleado.CURP = @CURP
                      AND Jornada.Dia_Semana = @Dia
                      AND @Ahora >= Jornada.Hora_Inicio AND @Ahora < Jornada.Hora_Fin
                      AND (   (@Rol = N'Medico'        AND EXISTS (SELECT 1 FROM dbo.Medico        WHERE Medico.ID_Empleado = Empleado.ID_Empleado))
                           OR (@Rol = N'Recepcionista' AND EXISTS (SELECT 1 FROM dbo.Recepcionista WHERE Recepcionista.ID_Empleado = Empleado.ID_Empleado))))
               THEN 1 ELSE 0 END;

    RETURN 0;
END
GO

-- =============================================
-- Función: fn_EsRol
-- Descripción: Indica si la conexión actual tiene un perfil (rol).
-- =============================================
CREATE OR ALTER FUNCTION dbo.fn_EsRol (@Rol SYSNAME)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN IS_MEMBER(@Rol) = 1 OR IS_MEMBER('db_owner') = 1 THEN 1 ELSE 0 END;
END
GO

-- =============================================
-- Función: fn_HorariosLibres
-- Descripción: Horarios libres de un médico entre dos fechas.
-- =============================================
CREATE OR ALTER FUNCTION dbo.fn_HorariosLibres (@ID_Medico INT, @Desde DATE, @Hasta DATE)
RETURNS TABLE
AS
RETURN
    -- Números del 0 al 99 (unidades + decenas)
    WITH Unidades AS (SELECT 0 AS U UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9),
         Decenas  AS (SELECT 0 AS D UNION ALL SELECT 10 UNION ALL SELECT 20 UNION ALL SELECT 30 UNION ALL SELECT 40
                      UNION ALL SELECT 50 UNION ALL SELECT 60 UNION ALL SELECT 70 UNION ALL SELECT 80 UNION ALL SELECT 90),
         Numeros  AS (SELECT Decenas.D + Unidades.U AS N FROM Decenas CROSS JOIN Unidades),
         -- Días entre @Desde y @Hasta
         Dias     AS (SELECT DATEADD(DAY, Numeros.N, @Desde) AS Fecha FROM Numeros
                       WHERE Numeros.N <= DATEDIFF(DAY, @Desde, @Hasta)),
         -- Bloques de 30 minutos de la jornada del médico en cada día
         Bloques  AS (
             SELECT Dias.Fecha,
                    CAST(DATEADD(MINUTE, 30 * Numeros.N, Jornada.Hora_Inicio) AS TIME(0)) AS Hora
               FROM Dias
               JOIN dbo.Medico   ON Medico.ID_Medico = @ID_Medico
               JOIN dbo.Empleado ON Empleado.ID_Empleado = Medico.ID_Empleado
               JOIN dbo.Usuario  ON Usuario.CURP = Empleado.CURP AND Usuario.Estatus = N'Activo'
               JOIN dbo.Jornada  ON Jornada.ID_Empleado = Medico.ID_Empleado
                                AND Jornada.Dia_Semana = dbo.fn_DiaSemana(Dias.Fecha)
               JOIN Numeros      ON 30 * Numeros.N + 30 <= DATEDIFF(MINUTE, Jornada.Hora_Inicio, Jornada.Hora_Fin))
    -- Se quitan los bloques ocupados y los que no cumplen 48 h / 3 meses
    SELECT Bloques.Fecha, Bloques.Hora
      FROM Bloques
     WHERE dbo.fn_InicioCita(Bloques.Fecha, Bloques.Hora) >= DATEADD(HOUR, 48, GETDATE())
       AND dbo.fn_InicioCita(Bloques.Fecha, Bloques.Hora) <= DATEADD(MONTH, 3, GETDATE())
       AND NOT EXISTS (SELECT 1 FROM dbo.Cita
                        WHERE Cita.ID_Medico = @ID_Medico AND Cita.Fecha_Cita = Bloques.Fecha
                          AND Cita.Hora_Cita = Bloques.Hora AND Cita.ID_EstatusCita IN (1, 2));
GO

