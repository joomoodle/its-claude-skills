# Skill: sql-standard
Trigger: `/sql-standard`

Estándar de desarrollo de objetos SQL para IT Strategy. Aplica a T-SQL (SQL Server) y PL/pgSQL (PostgreSQL).
Al invocarse, usar estas reglas como checklist al crear o revisar stored procedures, funciones, vistas y tablas.

---

## 1. Convención de Nomenclatura

### T-SQL

| Tipo | Prefijo/Sufijo | Ejemplo |
|------|---------------|---------|
| Stored Procedure | `Spp_` | `dbo.Spp_ProcesaPago` |
| Función | `Fn_` | `dbo.Fn_ValidaUsuario` |
| Parámetro numérico | `@Pn` | `@PnIdRelLab` |
| Parámetro cadena | `@Ps` | `@PsCodigoEmpleado` |
| Parámetro salida | `@Pn` / `@Ps` | `@PnEstatus`, `@PsMensaje` |
| Variable interna | `@w_` | `@w_etapaProceso` |
| Tabla temporal | `#` | `#Tmp_Detalle` |

### PL/pgSQL (PostgreSQL)

Todo en **snake_case minúsculas**.

| Tipo | Prefijo/Sufijo | Ejemplo |
|------|---------------|---------|
| Stored Procedure | `spp_` | `public.spp_procesa_pago` |
| Función | `fn_` | `public.fn_valida_usuario` |
| Parámetro numérico | `p_n_` | `p_n_id_rel_lab` |
| Parámetro cadena | `p_s_` | `p_s_codigo_empleado` |
| Parámetro INOUT salida | `pn_` / `ps_` | `pn_estatus`, `ps_mensaje` |
| Variable interna | `w_` | `w_etapa_proceso` |
| Tabla temporal | sin prefijo | creadas con `CREATE TEMP TABLE` |

---

## 2. Reglas de Manejo Transaccional y Errores

### Regla 1 — Directivas de sesión

**T-SQL**: `SET NOCOUNT ON; SET XACT_ABORT ON;` al inicio del cuerpo.

**PL/pgSQL**: No existen equivalentes directos.
- `SET NOCOUNT ON` → innecesario (PG no envía row counts en procedures).
- `SET XACT_ABORT ON` → innecesario: el bloque `EXCEPTION` de PL/pgSQL hace rollback al savepoint automático ante cualquier error no capturado.

---

### Regla 2 — Declaración de variables fuera del bloque de manejo de errores

**T-SQL**: `DECLARE` fuera del `BEGIN TRY`.

**PL/pgSQL**: `DECLARE` va en la sección de declaración del bloque, antes del `BEGIN`. Visible en toda la función/procedure incluyendo `EXCEPTION`.

```sql
CREATE OR REPLACE PROCEDURE public.spp_ejemplo(...)
LANGUAGE plpgsql AS $$
DECLARE
    w_error         INTEGER      := 0;
    w_desc_error    VARCHAR(250) := '';
    w_etapa_proceso VARCHAR(250) := '';
BEGIN
    ...
EXCEPTION ...
END;
$$;
```

---

### Regla 3 — Ámbito restringido de transacciones

Lecturas y validaciones **fuera** de `BEGIN TRANSACTION`. La transacción se abre inmediatamente antes del primer DML (INSERT/UPDATE/DELETE).

**PL/pgSQL en FUNCTION**: La función hereda la transacción del llamador. No puede hacer `COMMIT`/`ROLLBACK`. El bloque `EXCEPTION` hace rollback automático al savepoint implícito del bloque.

**PL/pgSQL en PROCEDURE**: Puede hacer `COMMIT`/`ROLLBACK` explícito (PG 11+).

---

### Regla 4 — Bloque único de manejo de errores

**T-SQL**: `BEGIN TRY ... END TRY / BEGIN CATCH ... END CATCH`

**PL/pgSQL**:
```sql
BEGIN
    -- lógica
EXCEPTION
    WHEN SQLSTATE 'P0001' THEN   -- error controlado de negocio
        ...
    WHEN OTHERS THEN              -- error no controlado del motor
        ...
END;
```

---

### Regla 5 — Lanzar excepciones de negocio

**T-SQL**: `;THROW 50000, @w_desc_error, 1;`

**PL/pgSQL**:
```sql
RAISE EXCEPTION '%', w_desc_error USING ERRCODE = 'P0001';
-- P0001 es el SQLSTATE estándar para excepciones de usuario en PG
```

---

### Regla 6 — Discriminación de tipo de error en el CATCH

**T-SQL**: `IF ERROR_NUMBER() = 50000` → negocio; else → motor.

**PL/pgSQL**:
```sql
EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
        -- Error controlado de negocio
        pn_estatus := w_error;
        ps_mensaje := LEFT(CONCAT(w_desc_error, ' [Etapa: ', w_etapa_proceso, ']'), 250);
    WHEN OTHERS THEN
        -- Error del motor: usar SQLSTATE y SQLERRM
        pn_estatus := -1;
        ps_mensaje := LEFT(CONCAT('Error [', SQLSTATE, ']: ', SQLERRM,
                           ' [Etapa: ', w_etapa_proceso, ']'), 250);
```

| T-SQL | PL/pgSQL |
|-------|----------|
| `ERROR_NUMBER()` | `SQLSTATE` (código 5 chars) |
| `ERROR_MESSAGE()` | `SQLERRM` |
| `ERROR_LINE()` | `GET STACKED DIAGNOSTICS v = PG_EXCEPTION_CONTEXT` |

---

### Regla 7 — Reversión segura (equivalente a XACT_STATE)

**T-SQL**: `IF XACT_STATE() <> 0 ROLLBACK TRANSACTION`

**PL/pgSQL en FUNCTION**: No aplica. El bloque `EXCEPTION` hace rollback automático al savepoint implícito. No es posible ni necesario llamar `ROLLBACK` manualmente dentro de una función.

**PL/pgSQL en PROCEDURE** (cuando maneja su propia transacción):
```sql
EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
        ROLLBACK;
        pn_estatus := w_error;
        ps_mensaje := LEFT(CONCAT(w_desc_error, ' [Etapa: ', w_etapa_proceso, ']'), 250);
    WHEN OTHERS THEN
        ROLLBACK;
        pn_estatus := -1;
        ps_mensaje := LEFT(CONCAT('Error [', SQLSTATE, ']: ', SQLERRM,
                           ' [Etapa: ', w_etapa_proceso, ']'), 250);
```

---

### Regla 7.1 — Procedimientos anidados

**Patrón A — Todo o nada (predeterminado)**

El procedimiento Hijo NO maneja transacciones. Solo lanza excepción con `RAISE`; el Padre hace el `ROLLBACK`.

```sql
-- Hijo: solo lógica + RAISE en error
CREATE OR REPLACE PROCEDURE public.spp_hijo(p_n_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.detalle_tbl (id_rel_lab) VALUES (p_n_id);
EXCEPTION
    WHEN OTHERS THEN
        RAISE; -- propaga al padre
END;
$$;

-- Padre: dueño de la transacción
CREATE OR REPLACE PROCEDURE public.spp_padre(
    p_n_registro_id INTEGER,
    INOUT pn_estatus INTEGER DEFAULT 0,
    INOUT ps_mensaje VARCHAR(250) DEFAULT ''
)
LANGUAGE plpgsql AS $$
DECLARE
    w_etapa_proceso VARCHAR(250) := '';
BEGIN
    w_etapa_proceso := 'Actualización de cabecera.';
    UPDATE public.cabeceras_tbl SET estado = 'PROCESANDO'
    WHERE id_cabecera = p_n_registro_id;

    w_etapa_proceso := 'Llamada a spp_hijo.';
    CALL public.spp_hijo(p_n_id => p_n_registro_id);

    COMMIT;
    pn_estatus := 0;
    ps_mensaje := 'Proceso ejecutado exitosamente.';
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        pn_estatus := -1;
        ps_mensaje := LEFT(CONCAT('Error [', SQLSTATE, ']: ', SQLERRM,
                           ' [Etapa: ', w_etapa_proceso, ']'), 250);
END;
$$;
```

**Patrón B — Autónomo con Savepoint**

Cuando el Hijo debe revertir solo su trabajo sin afectar al Padre:

```sql
CREATE OR REPLACE PROCEDURE public.spp_hijo_autonomo(p_n_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    SAVEPOINT spp_hijo_sp;
    INSERT INTO public.detalle_tbl (id_rel_lab) VALUES (p_n_id);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT spp_hijo_sp;
        RAISE; -- el padre decide si continúa o no
END;
$$;
```

---

### Regla 8 — Trazabilidad con w_etapa_proceso

Actualizar `w_etapa_proceso` antes de cada bloque crítico. Aplica igual en T-SQL y PL/pgSQL.

```sql
w_etapa_proceso := 'Validación de permisos.';
-- operación...
w_etapa_proceso := 'Inserción en tabla_ejemplo_tbl.';
-- operación...
```

---

### Regla 9 — Concatenación y recorte seguro

| T-SQL | PL/pgSQL |
|-------|----------|
| `CONCAT(a, b)` | `CONCAT(a, b)` (igual) |
| `SUBSTRING(x, 1, 250)` | `LEFT(x, 250)` |
| `ISNULL(x, y)` | `COALESCE(x, y)` |

---

### Regla 10 — Firma estándar de parámetros de salida

**T-SQL**: `@PnEstatus INT OUTPUT`, `@PsMensaje VARCHAR(250) OUTPUT`

**PL/pgSQL**:
```sql
INOUT pn_estatus  INTEGER      DEFAULT 0,
INOUT ps_mensaje  VARCHAR(250) DEFAULT ''
```

---

## 3. Reglas de Rendimiento y Seguridad

### Regla 11 — Prohibición de SELECT *

Aplica igual en T-SQL y PL/pgSQL. Siempre listar columnas explícitas.

### Regla 12 — Búsquedas indexables (SARGable)

Aplica igual en ambos motores. No aplicar funciones a columnas en WHERE/JOIN.

| Incorrecto | Correcto |
|-----------|---------|
| `WHERE EXTRACT(YEAR FROM fecha) = 2026` | `WHERE fecha >= '2026-01-01' AND fecha < '2027-01-01'` |
| `WHERE UPPER(codigo) = @p` | `WHERE codigo = UPPER(p_s_codigo)` |
| `WHERE codigo LIKE '%123'` | `WHERE codigo LIKE '123%'` |
| `WHERE LEFT(rfc, 4) = 'GARC'` | `WHERE rfc LIKE 'GARC%'` |
| `WHERE saldo - 100 > 500` | `WHERE saldo > 600` |
| `WHERE COALESCE(estatus, 0) = 0` | `WHERE estatus = 0 OR estatus IS NULL` |
| `WHERE id_empleado::VARCHAR = p_s_id` | `WHERE id_empleado = p_s_id::INTEGER` |

### Regla 13 — SQL Dinámico seguro

**T-SQL**: `sp_executesql` con parámetros.

**PL/pgSQL**:
```sql
-- Con parámetros (evita inyección)
EXECUTE 'SELECT * FROM public.tabla_tbl WHERE id = $1' USING p_n_id;

-- Con nombre de tabla dinámico (usar format + %I)
EXECUTE format('INSERT INTO %I (col) VALUES ($1)', p_s_tabla) USING p_s_valor;
-- %I = identificador escapado (equivalente a QUOTENAME en T-SQL)
-- %L = literal escapado
-- %s = texto sin escape (NO usar con input externo)
```

Prohibido: `EXECUTE 'SELECT ... WHERE id = ' || p_n_id` (inyección SQL).

### Regla 14 — Set-Based: sin CURSOR ni bucles por fila

Aplica igual en ambos motores.

| Imperativo (evitar) | Set-Based (preferir) |
|--------------------|---------------------|
| `LOOP ... FOR r IN SELECT ...` (cursor) | `UPDATE ... FROM JOIN` |
| Bucle con acumulador | `SUM() OVER (ORDER BY ...)` |
| Bucle para numeración | `ROW_NUMBER() OVER (ORDER BY ...)` |
| Bucle con IF EXISTS | `INSERT INTO ... SELECT ... WHERE NOT EXISTS` |

### Regla 15 — Tablas temporales vs variables

| Motor | > 100 filas | < 100 filas |
|-------|------------|------------|
| T-SQL | `#Tmp_tabla` | `@tabla TABLE(...)` |
| PL/pgSQL | `CREATE TEMP TABLE tmp_tabla (...)` | Array o CTE |

---

## 4. Plantilla Canónica PL/pgSQL

```sql
/*****************************************************************************
Nombre Objeto: public.spp_ejemplo_estandar
Propósito:     Plantilla estándar PL/pgSQL para IT Strategy.
Autor:         <nombre>
Fecha:         <fecha>
------------------------------------------------------------------------------
Historial de Cambios:
Fecha         Autor          Descripción
------------------------------------------------------------------------------
<fecha>       <autor>        Creación inicial
*****************************************************************************/
CREATE OR REPLACE PROCEDURE public.spp_ejemplo_estandar(
    -- Parámetros de entrada
    p_n_id_rel_lab       INTEGER,
    p_s_codigo_empleado  VARCHAR(100),
    p_n_id_usuario_act   SMALLINT,
    p_s_ip_act           VARCHAR(30)   DEFAULT NULL,
    p_s_mac_address_act  VARCHAR(30)   DEFAULT NULL,
    -- Parámetros de salida obligatorios (Regla 10)
    INOUT pn_estatus     INTEGER       DEFAULT 0,
    INOUT ps_mensaje     VARCHAR(250)  DEFAULT ''
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Variables de trabajo (Regla 2)
    w_resultado      INTEGER      := 0;
    w_error          INTEGER      := 0;
    w_desc_error     VARCHAR(250) := '';
    w_etapa_proceso  VARCHAR(250) := '';
BEGIN
    -- -------------------------------------------------------------------------
    -- Etapa 1: Validaciones de lectura / negocio (fuera de transacción - Regla 3)
    -- -------------------------------------------------------------------------
    w_etapa_proceso := 'Validación de datos de entrada.';

    IF p_n_id_rel_lab IS NULL THEN
        w_error      := 123;
        w_desc_error := 'La relación laboral no puede ser NULL.';
        RAISE EXCEPTION '%', w_desc_error USING ERRCODE = 'P0001'; -- Regla 5
    END IF;

    -- -------------------------------------------------------------------------
    -- Etapa 2: Persistencia DML (Regla 3)
    -- -------------------------------------------------------------------------
    w_etapa_proceso := 'Inserción en tabla_ejemplo_tbl.';

    INSERT INTO public.tabla_ejemplo_tbl (id_rel_lab, fecha_alta)
    VALUES (p_n_id_rel_lab, NOW());

    -- -------------------------------------------------------------------------
    -- Etapa 3: Llamada a sub-procedimiento (Regla 7.1, Regla 8)
    -- -------------------------------------------------------------------------
    w_etapa_proceso := 'Llamada a spp_valida_rel_lab.';

    CALL public.spp_valida_rel_lab(
        p_n_id_rel_lab     => p_n_id_rel_lab,
        p_n_id_usuario_act => p_n_id_usuario_act,
        pn_estatus         => w_error,
        ps_mensaje         => w_desc_error
    );

    IF COALESCE(w_error, 0) <> 0 THEN
        RAISE EXCEPTION '%', w_desc_error USING ERRCODE = 'P0001';
    END IF;

    COMMIT;

    -- Respuesta de éxito
    pn_estatus := 0;
    ps_mensaje := 'Proceso ejecutado exitosamente.';

EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
        -- Error controlado de negocio (Regla 6)
        ROLLBACK;
        pn_estatus := w_error;
        ps_mensaje := LEFT(                              -- Regla 9
            CONCAT(w_desc_error, ' [Etapa: ', w_etapa_proceso, ']'), 250);

    WHEN OTHERS THEN
        -- Error no controlado del motor (Regla 6)
        ROLLBACK;
        pn_estatus := -1;
        ps_mensaje := LEFT(
            CONCAT('Error [', SQLSTATE, ']: ', SQLERRM,
                   ' [Etapa: ', w_etapa_proceso, ']'), 250);
END;
$$;

-- GRANT EXECUTE obligatorio (ver skill migrate-sqlserver-pg, Regla 8)
GRANT EXECUTE ON PROCEDURE public.spp_ejemplo_estandar(
    INTEGER, VARCHAR, SMALLINT, VARCHAR, VARCHAR, INTEGER, VARCHAR
) TO usr_app_role;
```

---

## 5. Diseño de Tablas y Objetos

### Regla 16 — Clave primaria

**T-SQL**: `INT IDENTITY(1,1)` o `BIGINT IDENTITY(1,1)`. Evitar `UNIQUEIDENTIFIER` como PK.

**PL/pgSQL**:
```sql
id_cliente INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
-- O para tablas de alto volumen:
id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
-- Evitar UUID como PK (fragmenta índices)
```

### Regla 17 — Integridad referencial

FK obligatoria + índice en la columna FK:
```sql
CONSTRAINT fk_facturas_clientes
    FOREIGN KEY (id_cliente) REFERENCES public.clientes_tbl (id_cliente),

-- Índice en la columna FK (Regla 17)
CREATE INDEX ix_facturas_id_cliente ON public.facturas_tbl (id_cliente);
```

### Regla 18 — Columnas de auditoría

**T-SQL**: `fechaAlta`, `idUsuarioAlta`, `fechaModificacion`, `idUsuarioAct`

**PL/pgSQL** (snake_case):
```sql
fecha_alta           TIMESTAMP WITHOUT TIME ZONE NOT NULL,
id_usuario_alta      INTEGER                     NOT NULL,
fecha_modificacion   TIMESTAMP WITHOUT TIME ZONE NOT NULL,
id_usuario_act       INTEGER                     NOT NULL
```

### Regla 19 — Índices con INCLUDE

**T-SQL** y **PL/pgSQL** (PG 11+):
```sql
-- PG 11+: cláusula INCLUDE disponible
CREATE INDEX ix_clientes_rfc
    ON public.clientes_tbl (rfc)
    INCLUDE (nombre, apellido, email);
```

### Regla 20 — Sobre-indexación

Máximo 5–7 índices por tabla sin autorización de Arquitectura de Datos. Aplica igual en ambos motores.

---

## 6. Vistas

### Regla 21 — Sin ORDER BY ni vistas anidadas

Aplica igual en PL/pgSQL. No usar `ORDER BY` dentro de la definición de la vista (salvo `LIMIT`/`OFFSET`).

### Regla 22 — SCHEMABINDING

**T-SQL**: `WITH SCHEMABINDING`

**PL/pgSQL**: No existe equivalente directo. Para vistas críticas, documentar las dependencias y usar `SECURITY DEFINER` si aplica. Las vistas materializadas (`MATERIALIZED VIEW`) ofrecen protección similar para queries costosas.

---

## 7. Plantilla DDL Canónico PL/pgSQL

```sql
-- Tabla
CREATE TABLE public.clientes_tbl (
    id_cliente           INTEGER                     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_cliente       VARCHAR(20)                 NOT NULL,
    nombre               VARCHAR(100)                NOT NULL,
    rfc                  VARCHAR(13)                 NOT NULL,
    id_estatus_cliente   INTEGER                     NOT NULL,
    fecha_alta           TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    id_usuario_alta      INTEGER                     NOT NULL,
    fecha_modificacion   TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    id_usuario_act       INTEGER                     NOT NULL,

    CONSTRAINT uq_clientes_rfc UNIQUE (rfc),
    CONSTRAINT fk_clientes_cat_estatus
        FOREIGN KEY (id_estatus_cliente)
        REFERENCES public.cat_estatus_cliente_tbl (id_estatus)
);

-- Índice en FK (Regla 17)
CREATE INDEX ix_clientes_id_estatus_cliente
    ON public.clientes_tbl (id_estatus_cliente)
    INCLUDE (codigo_cliente, nombre, rfc);

-- Vista estándar (Regla 21)
CREATE VIEW public.clientes_activos_vw AS
SELECT
    c.id_cliente,
    c.codigo_cliente,
    c.nombre,
    c.rfc,
    e.descripcion AS estatus
FROM public.clientes_tbl c
INNER JOIN public.cat_estatus_cliente_tbl e
    ON c.id_estatus_cliente = e.id_estatus
WHERE c.id_estatus_cliente = 1;
```

---

## 8. Checklist de Revisión

### Manejo de Errores y Transacciones

- [ ] Variables declaradas en sección `DECLARE`, antes del `BEGIN`
- [ ] Parámetros de salida: `INOUT pn_estatus INTEGER`, `INOUT ps_mensaje VARCHAR(250)`
- [ ] Validaciones de negocio **fuera** del bloque transaccional
- [ ] Estructura `BEGIN ... EXCEPTION WHEN SQLSTATE 'P0001' THEN ... WHEN OTHERS THEN ... END`
- [ ] Excepciones de negocio con `RAISE EXCEPTION '%', msg USING ERRCODE = 'P0001'`
- [ ] `ROLLBACK` en cada rama del `EXCEPTION` (solo en PROCEDURE con transacción propia)
- [ ] Discriminación: `SQLSTATE = 'P0001'` para negocio, `OTHERS` para motor
- [ ] `SQLERRM` y `SQLSTATE` en mensaje de error de motor
- [ ] `w_etapa_proceso` actualizado antes de cada bloque crítico
- [ ] Mensajes recortados con `LEFT(..., 250)` y construidos con `CONCAT()`

### Rendimiento

- [ ] Sin `SELECT *`
- [ ] Sin funciones aplicadas a columnas en `WHERE`/`JOIN`
- [ ] Sin `LIKE '%texto'`
- [ ] SQL dinámico usa `EXECUTE ... USING` o `format('%I', ...)` — nunca concatenación directa
- [ ] Sin CURSOR o bucles por fila (usar set-based)
- [ ] Para > 100 filas: `CREATE TEMP TABLE` en lugar de array/CTE

### Diseño

- [ ] PK con `GENERATED ALWAYS AS IDENTITY` (no UUID como PK)
- [ ] FK declarada + índice en columna FK
- [ ] Columnas de auditoría: `fecha_alta`, `id_usuario_alta`, `fecha_modificacion`, `id_usuario_act`
- [ ] Índices con `INCLUDE` para queries recurrentes
- [ ] Máximo 7 índices por tabla

### Seguridad y Mantenibilidad

- [ ] Encabezado con Autor, Fecha, Propósito, Historial
- [ ] Nomenclatura snake_case con prefijos `spp_`, `fn_`, `p_n_`, `p_s_`, `w_`
- [ ] `CREATE OR REPLACE PROCEDURE/FUNCTION`
- [ ] Archivos `.sql` en UTF-8
- [ ] Sin código comentado ni `RAISE NOTICE` de depuración residual
- [ ] `IF EXISTS` / `IF NOT EXISTS` antes de ALTER o INSERT semilla
- [ ] Sin `DELETE`/`TRUNCATE` sin filtro estricto en tablas operativas
- [ ] `GRANT EXECUTE ON PROCEDURE/FUNCTION ... TO usr_app_role` al final de cada `R__*.sql`
