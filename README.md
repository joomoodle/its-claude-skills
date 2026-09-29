# its-claude-skills

Skills (slash commands) para Claude Code — IT Strategy.

## Instalación

```bash
# Clonar
git clone https://github.com/joomoodle/its-claude-skills.git
cd its-claude-skills

# Instalar todas las skills
bash install.sh

# O instalar solo una
bash install.sh migrate-sqlserver-pg
bash install.sh sql-standard
```

Reinicia Claude Code después de instalar.

---

## Skills disponibles

### `/migrate-sqlserver-pg`
Migración completa SQL Server → PostgreSQL (Cloud SQL) en proyectos .NET EF Core.

Cubre:
- Cambios de NuGet y configuración EF Core (Npgsql, UseSnakeCaseNamingConvention, ConfigureConventions)
- Roles y esquema Flyway (db_creator, usr_app_role, V001/V003)
- Script Python de migración de datos (to_snake, coerciones de tipos, SKIP_SQL_TABLES)
- CI/CD GitLab con Cloud SQL Auth Proxy
- Runbook operacional y checklist de 16 puntos

Ver: [skills/migrate-sqlserver-pg/SKILL.md](skills/migrate-sqlserver-pg/SKILL.md)

---

### `/sql-standard`
Estándar de desarrollo SQL para IT Strategy. Cubre T-SQL (SQL Server) y PL/pgSQL (PostgreSQL) en paralelo.

#### T-SQL vs PL/pgSQL — principales diferencias cubiertas

| Tema | T-SQL | PL/pgSQL |
|------|-------|----------|
| Objeto principal de lógica de negocio | `Stored Procedure` (`Spp_`) | `PROCEDURE` (`spp_`) cuando necesita transacción propia; `FUNCTION` (`fn_`) para cálculos y lookups |
| Manejo de errores | `BEGIN TRY / BEGIN CATCH` | `BEGIN ... EXCEPTION WHEN SQLSTATE 'P0001' THEN ... WHEN OTHERS THEN` |
| Lanzar error de negocio | `;THROW 50000, @msg, 1` | `RAISE EXCEPTION '%', msg USING ERRCODE = 'P0001'` |
| Código de error | `ERROR_NUMBER() = 50000` | `SQLSTATE = 'P0001'` |
| Mensaje de error | `ERROR_MESSAGE()` | `SQLERRM` |
| Verificar transacción activa | `XACT_STATE() <> 0` | No aplica en FUNCTION; `ROLLBACK` directo en PROCEDURE |
| Parámetros de salida | `@PnEstatus INT OUTPUT` | `INOUT pn_estatus INTEGER` |
| SQL dinámico seguro | `sp_executesql N'...', N'@p INT', @p = val` | `EXECUTE '...' USING val` / `EXECUTE format('%I', tbl) USING val` |
| Directivas de sesión | `SET NOCOUNT ON; SET XACT_ABORT ON;` | No necesarias en PL/pgSQL |
| Concatenación segura | `CONCAT()` + `SUBSTRING(x,1,250)` | `CONCAT()` + `LEFT(x, 250)` |
| Nulos | `ISNULL(x, y)` | `COALESCE(x, y)` |
| Fecha actual | `GETDATE()` | `NOW()` |
| Identity | `INT IDENTITY(1,1)` | `INTEGER GENERATED ALWAYS AS IDENTITY` |

#### FUNCTION vs PROCEDURE en PostgreSQL

En SQL Server todo es `Stored Procedure` o `Function`. En PostgreSQL la elección define las capacidades transaccionales:

- **FUNCTION**: No puede hacer COMMIT/ROLLBACK. Corre dentro de la transacción del llamador. Se invoca con `SELECT fn_nombre()`. Usar para validaciones, cálculos y lookups.
- **PROCEDURE**: Puede hacer COMMIT/ROLLBACK (PG 11+). Se invoca con `CALL spp_nombre(...)`. Usar para operaciones DML principales que necesitan gestionar su propia transacción.

Cubre además: nomenclatura, rendimiento (SARGable, set-based), diseño de tablas (PK, FK, auditoría, índices), vistas, plantilla canónica y checklist de 30 puntos.

Ver: [skills/sql-standard/SKILL.md](skills/sql-standard/SKILL.md)

---

## Agregar una nueva skill

1. Crear `skills/<nombre>/SKILL.md`
2. La primera línea del body (después del `# Skill:` y `Trigger:`) es la descripción que usa el instalador.
3. Hacer PR o push directo.
