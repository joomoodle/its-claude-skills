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
bash install.sh ui-kit
bash install.sh kontrolia-theme
bash install.sh suite-props
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

### `/ui-kit`
Uso de la librería de componentes UI compartidos `@it-strategy/ui-kit` (Kontrolia) en los micro-frontends React. Se activa también de forma automática al trabajar en pantallas, formularios, tablas, modales, alertas o exportaciones.

Cubre:
- Regla de oro: si la librería tiene el componente, se usa la librería (tabla "necesitas → usa → en lugar de")
- Instalación con `update-ui-kit.mjs`, peer dependencies, `ThemeProvider` y `configureAlerts`
- Imports nombrados (la librería no tiene export default)
- Catálogo de componentes con props clave: `PageLayout`, `DataTable`, `Modal`, `Button`, `SectionHeader`, `Input*`, `SelectField`, `SelectMultiple`, `InputAutocomplete`, `DateField`, `TimeField`, `RangeDateTimePicker`, `FileDropzone`, `Checkbox`, `Switch`, `Radio`, `ErrorBoundaryFallback`, `AccessDenied`
- Utilidades: `Alert`, `Toast`, `exportExcel`, `isValidTime`
- Patrón estándar de pantalla CRUD
- Migración de código existente: comandos para detectar candidatos y tabla de equivalencias (MUI, mui/x-date-pickers, SweetAlert2, xlsx, react-dropzone…)
- Tokens del tema Kontrolia, qué hacer si falta un componente y checklist de revisión de MR

Ver: [skills/ui-kit/SKILL.md](skills/ui-kit/SKILL.md)

---

### `/kontrolia-theme`
Tema Kontrolia (Brand Guide Oct 2025) en los micro-frontends: cómo se usan los colores, el gradiente y la tipografía.

Cubre:
- Paleta oficial (6 colores), tokens semánticos vs legacy y sus equivalencias, `gradients.primary`, `fontFamily`
- Cómo llega el tema a cada proyecto: `ThemeProvider` (suite-props con `defaultTheme`, catalogos-suite vía `storeTheme$`), Tailwind `k-*` (auth-front), `configureAlerts` (ui-kit), MUI sin tema
- Consumo en styled-components, `useTheme`/`sx`, transparencias con sufijo hex, fallbacks
- Manrope declarada pero no cargada; grises permitidos sin token
- Proyectos **sin** `@it-strategy/utilities`: cómo detectarlo y cómo definir el tema local (styled-components, CSS/SCSS `--k-*`, Tailwind, MUI, carga de Manrope)
- Deuda conocida (HEX hardcodeados, colores fuera de marca, rojos de error, mocks duplicados), comandos `grep` para detectarla y cómo agregar un token nuevo
- Checklist de revisión de estilos

Ver: [skills/kontrolia-theme/SKILL.md](skills/kontrolia-theme/SKILL.md)

---

### `/suite-props`
Shell y librería compartida `@it-strategy/utilities` (repo suite-props).

Cubre: doble rol (application shell + utility module), API pública exacta y firmas de los stores RxJS (`storeUser`, `storeToast`, `storeLoader`, `storeTheme`, `storeNotificacion`…), cómo consumirla desde otro MFE, cliente `Api`, menú y permisos por módulo, dashboard (SSE) y notificaciones push FCM, standalone, CI/CD y caché del bundle (`VERSION_SUITE`), reglas, gotchas y checklist.

Ver: [skills/suite-props/SKILL.md](skills/suite-props/SKILL.md)

---

## Agregar una nueva skill

1. Crear `skills/<nombre>/SKILL.md`
2. Opcional (recomendado): frontmatter YAML con `name` y `description` para que Claude Code active la skill automáticamente. El instalador usa ese `description`; si no existe, usa la primera línea del body después de `# Skill:` y `Trigger:`.
3. Hacer PR o push directo.
