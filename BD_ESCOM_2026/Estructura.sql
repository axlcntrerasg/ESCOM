-- =============================================
-- Proyecto: Sistema Gestor de Clínica (SQL Server)
-- Archivo: 01_estructura.sql
-- Descripción: Crea la base de datos, las tablas, llaves y restricciones.
-- Orden: 1 (primero)
-- =============================================

USE master;
GO

-- Si la base ya existe se borra y se crea de nuevo
IF DB_ID(N'clinica') IS NOT NULL
BEGIN
    ALTER DATABASE clinica SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE clinica;
END
GO

CREATE DATABASE clinica;
GO

USE clinica;
GO

-- ---------- USUARIOS Y PERSONAL ----------

-- =============================================
-- Tabla: Usuario
-- Descripción: Datos generales de todas las personas (pacientes y empleados).
-- =============================================
CREATE TABLE Usuario (
    CURP            CHAR(18)       NOT NULL,
    Nombre          NVARCHAR(60)   NOT NULL,
    Apellido_P      NVARCHAR(60)   NOT NULL,
    Apellido_M      NVARCHAR(60)   NULL,
    Fecha_Nac       DATE           NOT NULL,
    Edad AS (
        DATEDIFF(YEAR, Fecha_Nac, CAST(GETDATE() AS DATE))
        - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, Fecha_Nac, CAST(GETDATE() AS DATE)), Fecha_Nac)
                    > CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END
    ),
    Email           NVARCHAR(120)  NOT NULL,
    Pwd_Hash        NVARCHAR(255)  NOT NULL,      -- contraseña cifrada (bcrypt), nunca en texto plano
    Tel_Personal    VARCHAR(15)    NOT NULL,
    Tel_Casa        VARCHAR(15)    NULL,
    Tel_Emergencia  VARCHAR(15)    NULL,
    Estatus         NVARCHAR(10)   NOT NULL CONSTRAINT df_usuario_estatus DEFAULT N'Activo',
    Calle           NVARCHAR(100)  NULL,
    Numero          NVARCHAR(10)   NULL,
    Colonia         NVARCHAR(80)   NULL,
    Ciudad          NVARCHAR(80)   NULL,
    Estado          NVARCHAR(50)   NULL,
    Codigo_P        CHAR(5)        NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (CURP),
    CONSTRAINT uq_usuario_email UNIQUE (Email),
    CONSTRAINT ck_usuario_estatus CHECK (Estatus IN (N'Activo', N'Inactivo')),
    CONSTRAINT ck_usuario_fecha_nac CHECK (Fecha_Nac >= '1900-01-01')
);

-- =============================================
-- Tabla: Paciente
-- Descripción: Usuarios que son pacientes.
-- =============================================
CREATE TABLE Paciente (
    ID_Paciente     INT IDENTITY(1,1) NOT NULL,
    CURP            CHAR(18)       NOT NULL,
    CONSTRAINT pk_paciente PRIMARY KEY (ID_Paciente),
    CONSTRAINT uq_paciente_curp UNIQUE (CURP),
    CONSTRAINT fk_paciente_usuario FOREIGN KEY (CURP) REFERENCES Usuario(CURP)
);

-- =============================================
-- Tabla: Empleado
-- Descripción: Usuarios que trabajan en la clínica.
-- =============================================
CREATE TABLE Empleado (
    ID_Empleado     INT IDENTITY(1,1) NOT NULL,
    CURP            CHAR(18)       NOT NULL,
    RFC             CHAR(13)       NOT NULL,
    Sueldo          DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_empleado PRIMARY KEY (ID_Empleado),
    CONSTRAINT uq_empleado_curp UNIQUE (CURP),
    CONSTRAINT uq_empleado_rfc UNIQUE (RFC),
    CONSTRAINT fk_empleado_usuario FOREIGN KEY (CURP) REFERENCES Usuario(CURP),
    CONSTRAINT ck_empleado_sueldo CHECK (Sueldo > 0)
);

-- =============================================
-- Tabla: Especialidad
-- Descripción: Especialidades médicas y el costo de su consulta.
-- =============================================
CREATE TABLE Especialidad (
    ID_Especialidad INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(80)   NOT NULL,
    Costo_Consulta  DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_especialidad PRIMARY KEY (ID_Especialidad),
    CONSTRAINT uq_especialidad_nombre UNIQUE (Nombre),
    CONSTRAINT ck_especialidad_costo CHECK (Costo_Consulta > 0)
);

-- =============================================
-- Tabla: Consultorio
-- Descripción: Consultorios. Cada uno lo comparten un médico de mañana y uno de tarde.
-- =============================================
CREATE TABLE Consultorio (
    ID_Consultorio  INT IDENTITY(1,1) NOT NULL,
    Numero          NVARCHAR(10)   NOT NULL,
    Piso            TINYINT        NOT NULL,
    Capacidad       TINYINT        NOT NULL,
    CONSTRAINT pk_consultorio PRIMARY KEY (ID_Consultorio),
    CONSTRAINT uq_consultorio_numero UNIQUE (Numero)
);

-- =============================================
-- Tabla: Medico
-- Descripción: Empleados que son médicos. Una especialidad y un consultorio fijo.
-- =============================================
CREATE TABLE Medico (
    ID_Medico       INT IDENTITY(1,1) NOT NULL,
    ID_Empleado     INT            NOT NULL,
    Cedula_Pro      VARCHAR(10)    NOT NULL,
    ID_Especialidad INT            NOT NULL,
    ID_Consultorio  INT            NOT NULL,
    CONSTRAINT pk_medico PRIMARY KEY (ID_Medico),
    CONSTRAINT uq_medico_empleado UNIQUE (ID_Empleado),
    CONSTRAINT uq_medico_cedula UNIQUE (Cedula_Pro),
    CONSTRAINT fk_medico_empleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado(ID_Empleado),
    CONSTRAINT fk_medico_especialidad FOREIGN KEY (ID_Especialidad) REFERENCES Especialidad(ID_Especialidad),
    CONSTRAINT fk_medico_consultorio FOREIGN KEY (ID_Consultorio) REFERENCES Consultorio(ID_Consultorio)
);

-- =============================================
-- Tabla: Recepcionista
-- Descripción: Empleados que son recepcionistas.
-- =============================================
CREATE TABLE Recepcionista (
    ID_Recepcionista INT IDENTITY(1,1) NOT NULL,
    ID_Empleado      INT           NOT NULL,
    CONSTRAINT pk_recepcionista PRIMARY KEY (ID_Recepcionista),
    CONSTRAINT uq_recepcionista_empleado UNIQUE (ID_Empleado),
    CONSTRAINT fk_recepcionista_empleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado(ID_Empleado)
);

-- =============================================
-- Tabla: Administrador
-- Descripción: Empleados que administran el sistema.
-- =============================================
CREATE TABLE Administrador (
    ID_Administrador INT IDENTITY(1,1) NOT NULL,
    ID_Empleado      INT           NOT NULL,
    CONSTRAINT pk_administrador PRIMARY KEY (ID_Administrador),
    CONSTRAINT uq_administrador_empleado UNIQUE (ID_Empleado),
    CONSTRAINT fk_administrador_empleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado(ID_Empleado)
);

-- =============================================
-- Tabla: Jornada
-- Descripción: Horario de trabajo de cada empleado por día (1 = lunes ... 7 = domingo).
-- =============================================
CREATE TABLE Jornada (
    ID_Jornada      INT IDENTITY(1,1) NOT NULL,
    ID_Empleado     INT            NOT NULL,
    Dia_Semana      TINYINT        NOT NULL,
    Hora_Inicio     TIME(0)        NOT NULL,
    Hora_Fin        TIME(0)        NOT NULL,
    CONSTRAINT pk_jornada PRIMARY KEY (ID_Jornada),
    CONSTRAINT fk_jornada_empleado FOREIGN KEY (ID_Empleado) REFERENCES Empleado(ID_Empleado),
    CONSTRAINT ck_jornada_dia CHECK (Dia_Semana BETWEEN 1 AND 7),
    CONSTRAINT ck_jornada_horas CHECK (Hora_Fin > Hora_Inicio),
    -- la jornada empieza en hh:00 o hh:30 para que los bloques de cita cuadren
    CONSTRAINT ck_jornada_bloque CHECK (DATEPART(MINUTE, Hora_Inicio) IN (0, 30) AND DATEPART(SECOND, Hora_Inicio) = 0)
);

-- ---------- CITAS Y CONSULTAS ----------

-- =============================================
-- Tabla: Historial_Medico
-- Descripción: Datos médicos de cada paciente (1 a 1).
-- =============================================
CREATE TABLE Historial_Medico (
    ID_Historial_Medico   INT IDENTITY(1,1) NOT NULL,
    ID_Paciente           INT            NOT NULL,
    Tipo_Sangre           VARCHAR(3)     NULL,
    Alergias              NVARCHAR(MAX)  NULL,
    Padecimientos_Previos NVARCHAR(MAX)  NULL,
    Peso                  DECIMAL(5,2)   NULL,   -- kg
    Estatura              DECIMAL(3,2)   NULL,   -- metros
    CONSTRAINT pk_historial PRIMARY KEY (ID_Historial_Medico),
    CONSTRAINT uq_historial_paciente UNIQUE (ID_Paciente),          -- 1:1
    CONSTRAINT fk_historial_paciente FOREIGN KEY (ID_Paciente) REFERENCES Paciente(ID_Paciente),
    CONSTRAINT ck_historial_sangre CHECK (Tipo_Sangre IN ('A+','A-','B+','B-','AB+','AB-','O+','O-'))
);

-- =============================================
-- Tabla: EstatusCita
-- Descripción: Catálogo de estatus de la cita (IDs fijos del 1 al 7).
-- =============================================
CREATE TABLE EstatusCita (
    ID_EstatusCita  TINYINT        NOT NULL,
    EstatusCita     NVARCHAR(50)   NOT NULL,
    CONSTRAINT pk_estatuscita PRIMARY KEY (ID_EstatusCita),
    CONSTRAINT uq_estatuscita UNIQUE (EstatusCita)
);

-- =============================================
-- Tabla: Cita
-- Descripción: Citas de 30 minutos agendadas por los pacientes.
-- =============================================
CREATE TABLE Cita (
    Folio_Cita        INT IDENTITY(1,1) NOT NULL,
    Fecha_Reservacion DATETIME2(0)   NOT NULL CONSTRAINT df_cita_reservacion DEFAULT GETDATE(),
    Fecha_Limite_Pago AS DATEADD(HOUR, 8, Fecha_Reservacion) PERSISTED,
    Linea_Pago        AS CAST('LP' + CONVERT(CHAR(8), Fecha_Reservacion, 112)
                              + RIGHT('000000' + CAST(Folio_Cita AS VARCHAR(10)), 6) AS VARCHAR(20)) PERSISTED,
    Fecha_Cita        DATE           NOT NULL,
    Hora_Cita         TIME(0)        NOT NULL,
    Hora_Fin          AS DATEADD(MINUTE, 30, Hora_Cita) PERSISTED,
    ID_Paciente       INT            NOT NULL,
    ID_Medico         INT            NOT NULL,
    ID_Consultorio    INT            NOT NULL,
    ID_EstatusCita    TINYINT        NOT NULL CONSTRAINT df_cita_estatus DEFAULT 1,
    Agendada_Por      CHAR(18)       NOT NULL,     -- CURP de quien agendó (paciente o recepcionista)
    Fecha_Cancelacion DATETIME2(0)   NULL,
    CONSTRAINT pk_cita PRIMARY KEY (Folio_Cita),
    CONSTRAINT fk_cita_paciente    FOREIGN KEY (ID_Paciente)    REFERENCES Paciente(ID_Paciente),
    CONSTRAINT fk_cita_medico      FOREIGN KEY (ID_Medico)      REFERENCES Medico(ID_Medico),
    CONSTRAINT fk_cita_consultorio FOREIGN KEY (ID_Consultorio) REFERENCES Consultorio(ID_Consultorio),
    CONSTRAINT fk_cita_estatus     FOREIGN KEY (ID_EstatusCita) REFERENCES EstatusCita(ID_EstatusCita),
    CONSTRAINT fk_cita_agendo      FOREIGN KEY (Agendada_Por)   REFERENCES Usuario(CURP),
    CONSTRAINT ck_cita_bloque CHECK (DATEPART(MINUTE, Hora_Cita) IN (0, 30) AND DATEPART(SECOND, Hora_Cita) = 0),
    CONSTRAINT uq_cita_linea_pago UNIQUE (Linea_Pago)
);

-- =============================================
-- Índice único: uq_cita_medico_horario
-- Descripción: Un médico no puede tener dos citas pendientes a la misma hora.
-- =============================================
CREATE UNIQUE INDEX uq_cita_medico_horario
    ON Cita (ID_Medico, Fecha_Cita, Hora_Cita) WHERE ID_EstatusCita IN (1, 2);

-- =============================================
-- Índice único: uq_cita_consultorio_horario
-- Descripción: Un consultorio no puede tener dos citas pendientes a la misma hora.
-- =============================================
CREATE UNIQUE INDEX uq_cita_consultorio_horario
    ON Cita (ID_Consultorio, Fecha_Cita, Hora_Cita) WHERE ID_EstatusCita IN (1, 2);

-- =============================================
-- Índice único: uq_cita_paciente_horario
-- Descripción: Un paciente no puede tener dos citas pendientes a la misma hora.
-- =============================================
CREATE UNIQUE INDEX uq_cita_paciente_horario
    ON Cita (ID_Paciente, Fecha_Cita, Hora_Cita) WHERE ID_EstatusCita IN (1, 2);

-- =============================================
-- Índice único: uq_cita_paciente_medico
-- Descripción: Un paciente no puede tener otra cita pendiente con el mismo médico.
-- =============================================
CREATE UNIQUE INDEX uq_cita_paciente_medico
    ON Cita (ID_Paciente, ID_Medico) WHERE ID_EstatusCita IN (1, 2);

-- =============================================
-- Tabla: Pago_Cita
-- Descripción: Pago de cada cita y monto devuelto si se cancela.
-- =============================================
CREATE TABLE Pago_Cita (
    ID_Pago_Cita    INT IDENTITY(1,1) NOT NULL,
    Folio_Cita      INT            NOT NULL,
    Monto           DECIMAL(10,2)  NOT NULL,
    Fecha_Pago      DATETIME2(0)   NOT NULL CONSTRAINT df_pago_cita_fecha DEFAULT GETDATE(),
    Metodo_Pago     NVARCHAR(15)   NOT NULL,
    Referencia_Pago NVARCHAR(30)   NULL,        -- autorización de tarjeta / folio de transferencia
    Estatus_Pago    NVARCHAR(20)   NOT NULL CONSTRAINT df_pago_cita_estatus DEFAULT N'Pagado',
    Monto_Devuelto  DECIMAL(10,2)  NOT NULL CONSTRAINT df_pago_cita_devuelto DEFAULT 0,
    CONSTRAINT pk_pago_cita PRIMARY KEY (ID_Pago_Cita),
    CONSTRAINT uq_pago_cita_folio UNIQUE (Folio_Cita),                -- 1:1
    CONSTRAINT fk_pago_cita FOREIGN KEY (Folio_Cita) REFERENCES Cita(Folio_Cita),
    CONSTRAINT ck_pago_cita_metodo CHECK (Metodo_Pago IN (N'Efectivo', N'Tarjeta', N'Transferencia')),
    CONSTRAINT ck_pago_cita_estatus CHECK (Estatus_Pago IN (N'Pagado', N'Reembolso total', N'Reembolso parcial', N'Sin reembolso')),
    CONSTRAINT ck_pago_cita_monto CHECK (Monto > 0 AND Monto_Devuelto >= 0 AND Monto_Devuelto <= Monto)
);

-- =============================================
-- Tabla: Receta
-- Descripción: Receta que genera cada cita atendida.
-- =============================================
CREATE TABLE Receta (
    Folio_Receta    INT IDENTITY(1,1) NOT NULL,
    Folio_Cita      INT            NOT NULL,
    Fecha           DATETIME2(0)   NOT NULL CONSTRAINT df_receta_fecha DEFAULT GETDATE(),
    Diagnostico     NVARCHAR(MAX)  NOT NULL,
    Tratamiento     NVARCHAR(MAX)  NOT NULL,
    Observaciones   NVARCHAR(MAX)  NULL,
    CONSTRAINT pk_receta PRIMARY KEY (Folio_Receta),
    CONSTRAINT uq_receta_cita UNIQUE (Folio_Cita),                    -- 1:1
    CONSTRAINT fk_receta_cita FOREIGN KEY (Folio_Cita) REFERENCES Cita(Folio_Cita)
);

-- =============================================
-- Tabla: Solicitud_Cancelacion
-- Descripción: Solicitudes del médico para cancelar una cita (las aprueba recepción).
-- =============================================
CREATE TABLE Solicitud_Cancelacion (
    ID_Solicitud     INT IDENTITY(1,1) NOT NULL,
    Folio_Cita       INT            NOT NULL,
    ID_Medico        INT            NOT NULL,
    Motivo           NVARCHAR(500)  NOT NULL,     -- escrito del médico
    Fecha_Solicitud  DATETIME2(0)   NOT NULL CONSTRAINT df_solicitud_fecha DEFAULT GETDATE(),
    Estatus          NVARCHAR(10)   NOT NULL CONSTRAINT df_solicitud_estatus DEFAULT N'Pendiente',
    ID_Recepcionista INT            NULL,         -- quién la resolvió
    Fecha_Respuesta  DATETIME2(0)   NULL,
    Comentario       NVARCHAR(255)  NULL,
    CONSTRAINT pk_solicitud PRIMARY KEY (ID_Solicitud),
    CONSTRAINT fk_solicitud_cita          FOREIGN KEY (Folio_Cita)       REFERENCES Cita(Folio_Cita),
    CONSTRAINT fk_solicitud_medico        FOREIGN KEY (ID_Medico)        REFERENCES Medico(ID_Medico),
    CONSTRAINT fk_solicitud_recepcionista FOREIGN KEY (ID_Recepcionista) REFERENCES Recepcionista(ID_Recepcionista),
    CONSTRAINT ck_solicitud_estatus CHECK (Estatus IN (N'Pendiente', N'Aprobada', N'Rechazada')),
    CONSTRAINT ck_solicitud_motivo  CHECK (LEN(Motivo) >= 10),
    CONSTRAINT ck_solicitud_resuelta CHECK (
        (Estatus = N'Pendiente' AND ID_Recepcionista IS NULL AND Fecha_Respuesta IS NULL)
     OR (Estatus <> N'Pendiente' AND ID_Recepcionista IS NOT NULL AND Fecha_Respuesta IS NOT NULL))
);

-- =============================================
-- Índice único: uq_solicitud_pendiente
-- Descripción: Solo una solicitud pendiente por cita.
-- =============================================
CREATE UNIQUE INDEX uq_solicitud_pendiente
    ON Solicitud_Cancelacion (Folio_Cita) WHERE Estatus = N'Pendiente';

-- ---------- FARMACIA ----------

-- =============================================
-- Tabla: Medicamento
-- Descripción: Medicamentos de la farmacia. Requiere_Receta = 1 para antibióticos.
-- =============================================
CREATE TABLE Medicamento (
    ID_Medicamento  INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(100)  NOT NULL,
    Costo           DECIMAL(10,2)  NOT NULL,     -- lo que le cuesta a la clínica
    Precio          DECIMAL(10,2)  NOT NULL,     -- precio de venta
    Requiere_Receta BIT            NOT NULL CONSTRAINT df_medicamento_receta DEFAULT 0,  -- ej. antibióticos
    CONSTRAINT pk_medicamento PRIMARY KEY (ID_Medicamento),
    CONSTRAINT uq_medicamento_nombre UNIQUE (Nombre),
    CONSTRAINT ck_medicamento_precios CHECK (Costo > 0 AND Precio > 0)
);

-- =============================================
-- Tabla: Receta_Medicamento
-- Descripción: Medicamentos de cada receta (relación N:M).
-- =============================================
CREATE TABLE Receta_Medicamento (
    Folio_Receta    INT            NOT NULL,
    ID_Medicamento  INT            NOT NULL,
    Dosis           NVARCHAR(100)  NOT NULL,
    Cantidad        SMALLINT       NOT NULL,
    Indicaciones    NVARCHAR(255)  NULL,
    CONSTRAINT pk_receta_medicamento PRIMARY KEY (Folio_Receta, ID_Medicamento),
    CONSTRAINT fk_rm_receta      FOREIGN KEY (Folio_Receta)   REFERENCES Receta(Folio_Receta),
    CONSTRAINT fk_rm_medicamento FOREIGN KEY (ID_Medicamento) REFERENCES Medicamento(ID_Medicamento),
    CONSTRAINT ck_rm_cantidad CHECK (Cantidad > 0)
);

-- =============================================
-- Tabla: Lote
-- Descripción: Lotes de cada medicamento con su caducidad y stock.
-- =============================================
CREATE TABLE Lote (
    ID_Lote         INT IDENTITY(1,1) NOT NULL,
    ID_Medicamento  INT            NOT NULL,
    Num_Lote        NVARCHAR(30)   NOT NULL,
    Caducidad       DATE           NOT NULL,
    Stock           INT            NOT NULL CONSTRAINT df_lote_stock DEFAULT 0,
    CONSTRAINT pk_lote PRIMARY KEY (ID_Lote),
    CONSTRAINT uq_lote UNIQUE (ID_Medicamento, Num_Lote),
    CONSTRAINT fk_lote_medicamento FOREIGN KEY (ID_Medicamento) REFERENCES Medicamento(ID_Medicamento),
    CONSTRAINT ck_lote_stock CHECK (Stock >= 0)
);

-- =============================================
-- Tabla: Venta_Medicamento
-- Descripción: Ventas de farmacia (a pacientes o clientes externos).
-- =============================================
CREATE TABLE Venta_Medicamento (
    ID_Venta_Med     INT IDENTITY(1,1) NOT NULL,
    Fecha_Venta      DATETIME2(0)  NOT NULL CONSTRAINT df_vm_fecha DEFAULT GETDATE(),
    Total            DECIMAL(10,2) NOT NULL CONSTRAINT df_vm_total DEFAULT 0,
    ID_Recepcionista INT           NOT NULL,
    ID_Paciente      INT           NULL,
    Nombre_Cliente   NVARCHAR(150) NULL,
    Folio_Receta     INT           NULL,
    Medico_Receta    NVARCHAR(150) NULL,
    Cedula_Receta    VARCHAR(10)   NULL,
    CONSTRAINT pk_venta_med PRIMARY KEY (ID_Venta_Med),
    CONSTRAINT fk_vm_recepcionista FOREIGN KEY (ID_Recepcionista) REFERENCES Recepcionista(ID_Recepcionista),
    CONSTRAINT fk_vm_paciente      FOREIGN KEY (ID_Paciente)      REFERENCES Paciente(ID_Paciente),
    CONSTRAINT fk_vm_receta        FOREIGN KEY (Folio_Receta)     REFERENCES Receta(Folio_Receta),
    CONSTRAINT ck_vm_cliente CHECK (ID_Paciente IS NOT NULL OR Nombre_Cliente IS NOT NULL)
);

-- =============================================
-- Tabla: Detalle_Venta_Med
-- Descripción: Medicamentos (por lote) de cada venta.
-- =============================================
CREATE TABLE Detalle_Venta_Med (
    ID_Venta_Med    INT            NOT NULL,
    ID_Lote         INT            NOT NULL,
    Cantidad        SMALLINT       NOT NULL,
    Precio_Unitario DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_detalle_vm PRIMARY KEY (ID_Venta_Med, ID_Lote),
    CONSTRAINT fk_dvm_venta FOREIGN KEY (ID_Venta_Med) REFERENCES Venta_Medicamento(ID_Venta_Med),
    CONSTRAINT fk_dvm_lote  FOREIGN KEY (ID_Lote)      REFERENCES Lote(ID_Lote),
    CONSTRAINT ck_dvm CHECK (Cantidad > 0 AND Precio_Unitario > 0)
);

-- =============================================
-- Tabla: Pago_Medicamento
-- Descripción: Pago de cada venta de medicamentos.
-- =============================================
CREATE TABLE Pago_Medicamento (
    ID_Pago_Med     INT IDENTITY(1,1) NOT NULL,
    ID_Venta_Med    INT            NOT NULL,
    Fecha_Pago      DATETIME2(0)   NOT NULL CONSTRAINT df_pago_med_fecha DEFAULT GETDATE(),
    Metodo_Pago     NVARCHAR(15)   NOT NULL,
    Total           DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_pago_med PRIMARY KEY (ID_Pago_Med),
    CONSTRAINT uq_pago_med_venta UNIQUE (ID_Venta_Med),               -- 1:1
    CONSTRAINT fk_pago_med_venta FOREIGN KEY (ID_Venta_Med) REFERENCES Venta_Medicamento(ID_Venta_Med),
    CONSTRAINT ck_pago_med_metodo CHECK (Metodo_Pago IN (N'Efectivo', N'Tarjeta', N'Transferencia')),
    CONSTRAINT ck_pago_med_total CHECK (Total > 0)
);

-- ---------- SERVICIOS ----------

-- =============================================
-- Tabla: Servicio
-- Descripción: Servicios extras (inyección, vacuna, curación...).
-- =============================================
CREATE TABLE Servicio (
    ID_Servicio     INT IDENTITY(1,1) NOT NULL,
    Nombre          NVARCHAR(100)  NOT NULL,
    Descripcion     NVARCHAR(255)  NULL,
    Costo           DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_servicio PRIMARY KEY (ID_Servicio),
    CONSTRAINT uq_servicio_nombre UNIQUE (Nombre),
    CONSTRAINT ck_servicio_costo CHECK (Costo > 0)
);

-- =============================================
-- Tabla: Venta_Servicio
-- Descripción: Ventas de servicios (a pacientes o clientes externos).
-- =============================================
CREATE TABLE Venta_Servicio (
    ID_Venta_Serv    INT IDENTITY(1,1) NOT NULL,
    Fecha_Venta      DATETIME2(0)  NOT NULL CONSTRAINT df_vs_fecha DEFAULT GETDATE(),
    Total            DECIMAL(10,2) NOT NULL CONSTRAINT df_vs_total DEFAULT 0,
    ID_Recepcionista INT           NOT NULL,
    ID_Paciente      INT           NULL,
    Nombre_Cliente   NVARCHAR(150) NULL,
    CONSTRAINT pk_venta_serv PRIMARY KEY (ID_Venta_Serv),
    CONSTRAINT fk_vs_recepcionista FOREIGN KEY (ID_Recepcionista) REFERENCES Recepcionista(ID_Recepcionista),
    CONSTRAINT fk_vs_paciente      FOREIGN KEY (ID_Paciente)      REFERENCES Paciente(ID_Paciente),
    CONSTRAINT ck_vs_cliente CHECK (ID_Paciente IS NOT NULL OR Nombre_Cliente IS NOT NULL)
);

-- =============================================
-- Tabla: Detalle_Venta_Serv
-- Descripción: Servicios de cada venta.
-- =============================================
CREATE TABLE Detalle_Venta_Serv (
    ID_Venta_Serv   INT            NOT NULL,
    ID_Servicio     INT            NOT NULL,
    Cantidad        SMALLINT       NOT NULL CONSTRAINT df_dvs_cantidad DEFAULT 1,
    Precio_Unitario DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_detalle_vs PRIMARY KEY (ID_Venta_Serv, ID_Servicio),
    CONSTRAINT fk_dvs_venta    FOREIGN KEY (ID_Venta_Serv) REFERENCES Venta_Servicio(ID_Venta_Serv),
    CONSTRAINT fk_dvs_servicio FOREIGN KEY (ID_Servicio)   REFERENCES Servicio(ID_Servicio),
    CONSTRAINT ck_dvs CHECK (Cantidad > 0 AND Precio_Unitario > 0)
);

-- =============================================
-- Tabla: Pago_Servicio
-- Descripción: Pago de cada venta de servicios.
-- =============================================
CREATE TABLE Pago_Servicio (
    ID_Pago_Serv    INT IDENTITY(1,1) NOT NULL,
    ID_Venta_Serv   INT            NOT NULL,
    Fecha_Pago      DATETIME2(0)   NOT NULL CONSTRAINT df_pago_serv_fecha DEFAULT GETDATE(),
    Metodo_Pago     NVARCHAR(15)   NOT NULL,
    Total           DECIMAL(10,2)  NOT NULL,
    CONSTRAINT pk_pago_serv PRIMARY KEY (ID_Pago_Serv),
    CONSTRAINT uq_pago_serv_venta UNIQUE (ID_Venta_Serv),             -- 1:1
    CONSTRAINT fk_pago_serv_venta FOREIGN KEY (ID_Venta_Serv) REFERENCES Venta_Servicio(ID_Venta_Serv),
    CONSTRAINT ck_pago_serv_metodo CHECK (Metodo_Pago IN (N'Efectivo', N'Tarjeta', N'Transferencia')),
    CONSTRAINT ck_pago_serv_total CHECK (Total > 0)
);

-- ---------- BITÁCORAS ----------

-- =============================================
-- Tabla: Bitacora_Historial_Cita
-- Descripción: Historial de consultas: citas Atendidas o No acudió.
-- =============================================
CREATE TABLE Bitacora_Historial_Cita (
    ID_Historial     INT IDENTITY(1,1) NOT NULL,
    Fecha_Mov        DATETIME2(0)   NOT NULL CONSTRAINT df_bhc_fecha DEFAULT GETDATE(),
    CURP_Usuario     CHAR(18)       NULL,        -- quién hizo el movimiento
    Maquina_IP       VARCHAR(45)    NULL,
    Folio_Cita       INT            NOT NULL,
    Fecha_Cita       DATE           NOT NULL,
    Hora_Cita        TIME(0)        NOT NULL,
    Folio_Receta     INT            NULL,
    Estatus_Consulta NVARCHAR(50)   NOT NULL,
    Especialidad     NVARCHAR(80)   NOT NULL,
    Consultorio      NVARCHAR(10)   NOT NULL,
    ID_Medico        INT            NOT NULL,
    ID_Paciente      INT            NOT NULL,
    CONSTRAINT pk_bitacora_historial PRIMARY KEY (ID_Historial),
    -- Bitacora_Historial_Cita "registra" Cita (N:1)
    CONSTRAINT fk_bhc_cita    FOREIGN KEY (Folio_Cita)   REFERENCES Cita(Folio_Cita),
    -- Usuario "realiza" Bitacora_Historial_Cita (1:N)
    CONSTRAINT fk_bhc_usuario FOREIGN KEY (CURP_Usuario) REFERENCES Usuario(CURP)
);

-- =============================================
-- Tabla: Bitacora_Estatus_Cita
-- Descripción: Cada cambio de estatus de una cita.
-- =============================================
CREATE TABLE Bitacora_Estatus_Cita (
    ID_Bitacora      INT IDENTITY(1,1) NOT NULL,
    Fecha_Mov        DATETIME2(0)   NOT NULL CONSTRAINT df_bec_fecha DEFAULT GETDATE(),
    Folio_Cita       INT            NOT NULL,
    Estatus_Anterior NVARCHAR(50)   NULL,
    Estatus_Cita     NVARCHAR(50)   NOT NULL,
    Fecha_Cita       DATE           NOT NULL,
    ID_Especialidad  INT            NOT NULL,
    Costo            DECIMAL(10,2)  NOT NULL,
    Politica_Cancela NVARCHAR(60)   NULL,        -- ej. '48 h o más: 100 %'
    Monto_Devuelto   DECIMAL(10,2)  NOT NULL CONSTRAINT df_bec_devuelto DEFAULT 0,
    CONSTRAINT pk_bitacora_estatus PRIMARY KEY (ID_Bitacora),
    -- Bitacora_Estatus_Cita "registra" Cita (N:1)
    CONSTRAINT fk_bec_cita FOREIGN KEY (Folio_Cita) REFERENCES Cita(Folio_Cita)
);
GO

