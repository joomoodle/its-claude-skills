# claude-skills

Skills (slash commands) para Claude Code.

## Instalación

```bash
# Clonar
git clone https://github.com/<tu-usuario>/claude-skills.git
cd claude-skills

# Instalar todas las skills
bash install.sh

# O instalar solo una
bash install.sh migrate-sqlserver-pg
```

Reinicia Claude Code después de instalar.

## Skills disponibles

### `/migrate-sqlserver-pg`
Migración completa SQL Server → PostgreSQL (Cloud SQL) en proyectos .NET EF Core.
Incluye: cambios de NuGet/EF Core, esquema Flyway, script Python de datos, CI/CD GitLab y runbook operacional.

Ver: [skills/migrate-sqlserver-pg/SKILL.md](skills/migrate-sqlserver-pg/SKILL.md)

## Agregar una nueva skill

1. Crear `skills/<nombre>/SKILL.md`
2. La primera línea del body (después del `# Skill:` y `Trigger:`) es la descripción que usa el instalador.
3. Hacer PR o push directo.
