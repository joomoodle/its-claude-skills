---
name: ui-kit
description: Uso obligatorio de la librería @it-strategy/ui-kit (componentes UI compartidos Kontrolia) en micro-frontends React de IT Strategy. Usar al crear o modificar pantallas, formularios, tablas, modales, alertas, toasts, exportación a Excel o carga de archivos, y al migrar código existente que usa MUI directo, SweetAlert2, xlsx o componentes locales duplicados.
---
# Skill: ui-kit
Trigger: `/ui-kit`

Guía de uso de `@it-strategy/ui-kit` (librería de componentes UI compartidos de IT Strategy / Kontrolia) para implementaciones nuevas y para migrar micro-frontends existentes.
Al invocarse, antes de escribir cualquier UI en un micro-frontend: revisar el catálogo de esta skill y usar el componente de la librería en lugar de construir uno local o usar MUI / SweetAlert2 / xlsx directamente.

- Repositorio: https://gitlab.it-strategy.mx/tecnologia-corporativa/tech-lead-1/suite-services/ui-shared
- Documentación completa (props y ejemplos): `README.md` del repositorio
- Historial de cambios: `CHANGELOG.md` del repositorio
- Demos en vivo: clonar el repo y ejecutar `npm run playground` → http://localhost:5174 (tab **Docs** con tablas de props)

---

## 0. Regla de oro

> **Si la librería tiene el componente, se usa la librería.** No se crean componentes locales equivalentes, no se estiliza MUI a mano para imitarlos y no se llama a SweetAlert2 / xlsx directamente.

| Necesitas… | Usa (de `@it-strategy/ui-kit`) | En lugar de… |
|---|---|---|
| Contenedor de página con título y botones Nuevo/Refrescar | `PageLayout` | `div` + título + botones a mano |
| Tabla con paginación, búsqueda, selección, árbol | `DataTable` | MUI `Table`, `DataGrid`, tablas HTML, tablas locales con TanStack |
| Botón | `Button` | MUI `Button`, `<button>` estilizado |
| Modal / diálogo | `Modal` | MUI `Dialog` / `Modal` directo |
| Cabecera de sección / acordeón | `SectionHeader` | MUI `Accordion`, encabezados a mano |
| Campo de texto | `InputText` (o variante específica abajo) | MUI `TextField` |
| Select simple | `SelectField` | MUI `Select` + `MenuItem` / `TextField select` |
| Select múltiple con chips | `SelectMultiple` | MUI `Select multiple` |
| Autocompletar / texto con sugerencias | `InputAutocomplete` | MUI `Autocomplete` |
| Textarea | `InputMultiline` | `TextField multiline` |
| Contraseña | `InputPassword` | input con toggle hecho a mano |
| Teléfono 10 dígitos | `InputPhone` | máscaras locales |
| Solo números / decimales | `InputNumber` | validación numérica manual |
| Validación por regex | `InputRegex` | validación manual en `onChange` |
| Input con icono / con botón limpiar | `InputWithIcon` / `InputClearable` | `InputAdornment` a mano |
| Fecha (dd/mm/aaaa) | `DateField` | `@mui/x-date-pickers` `DatePicker`, `<input type="date">` |
| Rango de fechas / fecha en calendario | `RangeDateTimePicker` | `DateRangePicker`, react-datepicker |
| Hora (HH:mm) | `TimeField` + `isValidTime` | `@mui/x-date-pickers` `TimePicker` |
| Checkbox / Switch / Radio | `Checkbox` / `Switch` / `Radio` + `RadioGroup` | MUI `Checkbox`, `Switch`, `Radio` |
| Carga de archivos (drag & drop) | `FileDropzone` | `react-dropzone`, `<input type="file">` |
| Alerta modal (ok, error, confirmación) | `Alert` | `Swal.fire(...)` directo |
| Notificación discreta | `Toast` | `Swal.mixin({ toast: true })`, notistack, `Snackbar` |
| Exportar Excel con estilos | `exportExcel` | `xlsx` / `xlsx-js-style` directo, CSV a mano |
| Pantalla de error en Error Boundary | `ErrorBoundaryFallback` | pantallas de error locales |
| Pantalla sin permisos | `AccessDenied` | pantallas 403 locales |

Si **no existe** el componente que necesitas: no lo dupliques en silencio dentro del micro-frontend. Ver [§8 Si falta algo](#8-si-falta-algo-en-la-librería).

---

## 1. Instalación en un micro-frontend

### 1.1 Peer dependencies (deben existir en el proyecto consumidor)

```json
{
  "react": ">=18",
  "react-dom": ">=18",
  "styled-components": ">=5",
  "@mui/material": ">=5",
  "@mui/icons-material": ">=5",
  "@tanstack/react-table": ">=8",
  "react-imask": ">=6"
}
```

`sweetalert2` y `xlsx-js-style` vienen como dependencias de la librería; no hace falta instalarlas.

### 1.2 Instalar / actualizar con `update-ui-kit.mjs` (pnpm)

La librería se instala desde git (no desde un registry). Cada consumidor tiene en su raíz el script `update-ui-kit.mjs` (contenido completo en la sección "Script update-ui-kit.mjs" del README del repo). Si el proyecto no lo tiene, copiarlo de ahí.

```bash
node update-ui-kit.mjs v2.0.0   # versión específica (recomendado: reproducible)
node update-ui-kit.mjs          # último commit de master (solo para probar cambios sin release)

git add pnpm-lock.yaml pnpm-workspace.yaml
git commit -m "chore(deps): actualizar @it-strategy/ui-kit a v2.0.0"
```

- Siempre commitear `pnpm-lock.yaml` **y** `pnpm-workspace.yaml` juntos.
- Ver versión instalada: `node -e "console.log(require('./node_modules/@it-strategy/ui-kit/package.json').version)"`
- Ver versiones publicadas: `git ls-remote --tags https://gitlab.it-strategy.mx/tecnologia-corporativa/tech-lead-1/suite-services/ui-shared.git`
- Antes de subir de versión **major**, revisar `CHANGELOG.md` por cambios incompatibles.

### 1.3 ThemeProvider (obligatorio)

Los componentes leen colores del `ThemeProvider` de styled-components. La app (o el root del micro-frontend) debe envolverse una vez:

```tsx
import { ThemeProvider } from 'styled-components'
import { defaultTheme } from '@it-strategy/utilities/Interface/ITheme'

export const App = () => (
  <ThemeProvider theme={defaultTheme}>
    <MyMFE />
  </ThemeProvider>
)
```

### 1.4 Tema de Alert y Toast (opcional, una vez al iniciar)

`Alert` y `Toast` son imperativos (no usan `useTheme`). Por defecto usan la paleta Kontrolia. Para inyectar el tema del proyecto:

```ts
import { configureAlerts } from '@it-strategy/ui-kit'
configureAlerts(getTheme()) // colores, fontFamily, titleFontSize, textFontSize
```

---

## 2. Importaciones

**Siempre imports nombrados** desde la raíz del paquete. La librería **no tiene export default**.

```tsx
// ✅ Correcto
import { PageLayout, DataTable, Button, Modal, Alert, Toast } from '@it-strategy/ui-kit'
import type { DataTableProps, ModalAction, SelectFieldOption } from '@it-strategy/ui-kit'

// ❌ Incorrecto (algunos ejemplos antiguos del README lo muestran así)
import DataTable from '@it-strategy/ui-kit'
import PageLayout from '@it-strategy/ui-kit'

// ❌ Incorrecto: nunca importar rutas internas
import DataTable from '@it-strategy/ui-kit/dist/...'
```

Exports disponibles:

```
Componentes: DataTable, PageLayout, ErrorBoundaryFallback, AccessDenied, Modal, Button,
             Checkbox, Switch, SectionHeader, Radio, RadioGroup, DateField, TimeField,
             RangeDateTimePicker, FileDropzone, InputText, InputModal (deprecado),
             SelectField, SelectMultiple, InputAutocomplete, InputWithIcon, InputPassword,
             InputClearable, InputMultiline, InputPhone, InputNumber, InputRegex
Utilidades:  exportExcel, Alert, Toast, configureAlerts, getAlertTheme, isValidTime
Tipos:       <Componente>Props para cada componente, ModalAction, SwitchSize, SelectFieldOption,
             ExportExcelOptions, ExcelSheet, ExcelColumn, AlertMessageParams,
             AlertConfirmParams, ToastParams, ToastOptions, ToastIcon, AlertTheme
```

---

## 3. Catálogo de componentes

Resumen de props clave. Para la tabla completa de cada uno, ver el README del repo o la tab **Docs** del playground.

### 3.1 Layout y estructura

#### `PageLayout` — contenedor estándar de página
| Prop | Tipo | Notas |
|---|---|---|
| `title`, `subtitle` | `string` | Cabecera de la página |
| `handleNew` | `() => void` | Si existe, muestra botón "Añadir nuevo" |
| `handleRefresh` | `() => void` | Si existe, muestra botón "Refrescar" |
| `handleHeadCount` / `headCount` | `() => void` / `boolean` | Botón HeadCount y su estado activo |
| `accions` | `() => void` | Botón genérico de acciones (el nombre de la prop es `accions`, así está en la API) |
| `headerActions` | `ReactNode` | Controles extra a la derecha del título |
| `toolbarActions` | `ReactNode` | Fila de herramientas bajo la cabecera (con divisor) — filtros, exportar, etc. |
| `noTitle` | `boolean` | Oculta toda la cabecera |

#### `SectionHeader` — cabecera de sección / acordeón
`title` (requerido), `subtitle`, `variant` (`default | primary | success | warning | danger | info | dark`), `icon`, `iconPosition`, `titleAlign`, `bold`, `collapsible`, `collapsed` + `onToggle` (modo controlado), `fullWidth`, `children`.

#### `Modal` — sobre MUI Modal
| Prop | Tipo | Default | Notas |
|---|---|---|---|
| `open`, `onClose` | `boolean`, `() => void` | `false` | |
| `title` | `string` | — | Sin título no hay cabecera |
| `titleAlign` | `'left' \| 'center' \| 'right'` | `'left'` | |
| `size` / `maxWidth` | `string` | `'40vw'` / `'70vw'` | |
| `actions` | `ModalAction[]` | — | Reemplaza el botón "Cerrar" por defecto |
| `footerAlign` | `'left' \| 'center' \| 'right'` | `'center'` | |
| `showFooter` | `boolean` | `true` | |
| `showCloseIcon` | `boolean` | `true` | |

`ModalAction = { label: string; onClick: () => void; bg?: string; color?: string; outlined?: boolean }`. En `bg`/`color` usar tokens del tema (`theme.primaryColor`, etc.), no HEX de la paleta.

#### `ErrorBoundaryFallback`
`err: Error | null`, `info: { componentStack?: string | null } | null`, `isDev?: boolean` (muestra stack técnico; usar `import.meta.env.DEV`), `icon?: ReactNode` (p. ej. un `<Lottie />` del consumidor; la librería no depende de lottie).

#### `AccessDenied`
`message?: string`. Usar en rutas protegidas: `hasPermission ? children : <AccessDenied />`.

### 3.2 Datos

#### `DataTable<T>` — basada en TanStack Table v8
| Prop | Tipo | Default | Notas |
|---|---|---|---|
| `data`, `columns` | `T[]`, `ColumnDef<T, any>[]` | `[]` | Columnas en formato TanStack (`accessorKey`, `header`, `cell`) |
| `loading` | `boolean` | `false` | |
| `showSearch` | `boolean` | `true` | Buscador global |
| `searchSlot` | `ReactNode` | — | Nodo a la derecha del buscador (exportar, filtros) |
| `showBorder`, `showRowDividers` | `boolean` | `true` | |
| `isPaginationAvailable` | `boolean` | `true` | |
| `pageInitialSize`, `rowPeerOptions` | `number`, `number[]` | `10`, `[10,20,30]` | |
| `totalLabel` | `string` | `'registro(s)'` | |
| `pinnedLeft` | `string[]` | — | IDs de columnas fijas (definir `id` en la columna) |
| `treeData` | `boolean` | `false` | Filas con `subRows` |
| `renderSubComponent` | `(row) => ReactNode` | — | Detalle expandible. Excluyente con `treeData` |
| `enableRowSelection` + `onRowSelectionChange` | `boolean`, `(rows: T[]) => void` | `false` | Columna de checkboxes |
| Server-side | `totalPage`, `pageIndex`, `pageSize`, `onChangePage(page, size)`, `onChangePageSize(size)`, `globalFilter`, `setGlobalFilter` | | Paginación/filtro controlados por el backend |

Celdas con acciones → usar `cell: ({ row }) => <Button square ariaLabel="Editar" icon={<EditOutlinedIcon fontSize="small" />} onClick={() => edit(row.original)} />`.

#### `exportExcel(options)` — Excel con estilos (xlsx-js-style)
```ts
exportExcel({
  fileName: 'Reporte de empleados',             // sin .xlsx
  sheets: [{
    name: 'Empleados',
    titleLines: ['REPORTE DE EMPLEADOS'],
    columns: [
      { key: 'numero', header: 'No.' },
      { key: 'nombre', header: 'Nombre', width: 28 },
      { key: 'ingreso', header: 'Fecha de ingreso', date: true }, // ISO → solo fecha
    ],
    rows: data,
  }],
  // opcionales: headerColor, borderColor, titleColor
})
```
Varias hojas = varios objetos en `sheets`.

### 3.3 Acciones

#### `Button`
`variant` (`default | primary | secondary | iron | danger | info | warning`, default `primary`), `appearance` (`solid | outline`), `size` (`small | medium | large | xlarge`), `rounded` (default `true`), `square` (solo icono → requiere `ariaLabel`), `bold`, `fullWidth`, `icon`, `iconPosition`, `loading` (spinner + bloquea clics), `disabled`, `type` (default `'button'`), `onClick`.

Patrón async: `setSaving(true); try { await save() } finally { setSaving(false) }` + `<Button loading={saving}>`.

### 3.4 Formularios

Todos los `Input*` extienden `InputText` (estilo pill con label externo en negrita; `helperText` se muestra como tooltip). Aceptan las props de MUI `TextField` excepto `variant`, `size` y `fullWidth`.

| Componente | Props propias | `onChange` / valor |
|---|---|---|
| `InputText` | `label`, `outlined` (label flotante estilo MUI), `error`, `helperText`, `notFull`, `minWidth` (170), `disabled` | Evento estándar: `e.target.value` |
| `InputMultiline` | `minRows` (3), `maxChars` (contador "X de Y") | `e.target.value` |
| `InputWithIcon` | `startIcon`, `endIcon` | `e.target.value` |
| `InputPassword` | — | `e.target.value` |
| `InputClearable` | `clearable` (true) | `e.target.value` (`''` al limpiar) |
| `InputPhone` | — | `e.target.value` = **solo dígitos** (`'5512345678'`); muestra `(551) 234-5678` |
| `InputNumber` | `allowDecimals`, `min`, `max` (bloquea al exceder) | `e.target.value` |
| `InputRegex` | `pattern` (`RegExp \| string`), `patternError` | `e.target.value`; error automático si no cumple |
| `SelectField` | `options: { value, label }[]`, `placeholder`, `outlined`, `searchable`, `searchPlaceholder`, `fullWidth`, `minWidth`, `error`, `helperText` | `e.target.value` |
| `SelectMultiple` | hijos `<MenuItem>` de MUI, `searchable`, `chipOverflow` (+N, requiere ancho acotado), `fullWidth`, `placeholder` | `e.target.value as string[]` |
| `InputAutocomplete` | `options: (string \| { value, label })[]`, `freeSolo` (default `true`), `noOptionsText`, `inputProps` | **Recibe el valor directo**: `onChange={setValor}` |
| `DateField` | `name` (requerido), `label`, `required`, `error`, `helperText`, `disabled` | `value` en **`'YYYY-MM-DD'`** (muestra dd/mm/aaaa). `onChange` recibe un pseudo-evento `{ target: { name, value } }` → compatible con handlers genéricos `handleChange(e)` |
| `TimeField` | `ampm`, `minutesStep` (5), `label`, `required`, `error`, `helperText`, `fullWidth`, `minWidth` (140) | `value` `'HH:mm'` 24 h. `onChange(value: string)` puede llegar incompleto → validar con `isValidTime(v)` |
| `RangeDateTimePicker` | `single` (una fecha), `popup` (input compacto + calendario dropdown), `maxDate: Date` | `value`: `['YYYY-MM-DD', 'YYYY-MM-DD']` (o `string` en `single`). `onChange(start, end?)` |
| `FileDropzone` | `accept` (`'.csv,.xlsx'`, `'image/*'`), `multiple`, `maxFiles`, `maxSize` (bytes), `label`, `required`, `error` + `errorText`, `placeholder`, `helperText`, `disabled` | `onFileSelected(file)` / `onFilesSelected(files)`; `onInvalidFile(msg)`. **No sube** el archivo |
| `Checkbox` | `label` (ReactNode), `labelPosition`, `variant`, `size`, `error`, `disabled`, `plain` (dentro de tablas), `onDark` | `onChange(checked: boolean)`; controlado (`checked`) o no (`defaultChecked`) |
| `Switch` | `label`, `ariaLabel`, `labelPlacement` (`start \| end`), `size` (`small \| medium`), `onDark`, `onClick` (usar `e.stopPropagation()` en filas clicables) | `onChange(checked: boolean)`; controlado |
| `RadioGroup` + `Radio` | Grupo: `direction`, `size`, `disabled`, `name`. Radio: `value` (requerido), `label`, `disabled` | `onChange(value: string)` en el grupo |

Validación: la librería **no conoce tu formulario**. `required` solo agrega el asterisco; el consumidor decide cuándo hay `error` y qué `helperText`/`errorText` mostrar (funciona igual con react-hook-form, formik o estado local).

### 3.5 Feedback

#### `Alert` — modal bloqueante (SweetAlert2 con estilo Kontrolia)
```ts
Alert.Ok({ message: 'El registro se guardó correctamente' })
Alert.Error({ message: 'Hubo un error al guardar' })
Alert.Notice({ message: 'Selecciona una marca' })

try {
  await Alert.Confirm({ title: '¿Eliminar el registro?', message: 'No se puede deshacer.', confirmText: 'Sí, eliminar' })
  await eliminar()          // confirmado
} catch {
  // cancelado: Confirm RECHAZA la promesa al cancelar
}
```
- `message` se escapa → seguro con mensajes del backend.
- `Alert.showSuccess(html)` / `Alert.showError(html)` renderizan HTML **sin escapar**: solo HTML armado en el front, nunca texto del backend.
- Todos aceptan `confirmText`, `titleFontSize`, `textFontSize`.

#### `Toast` — aviso no bloqueante (esquina superior derecha, auto-cierre)
```ts
Toast.success('Cambios guardados', { title: 'Listo' })
Toast.info('No hay información para exportar')
Toast.warning('Selecciona al menos un usuario')
Toast.error('No se pudo conectar con el servidor')
```

**Cuándo cuál:** `Toast` para avisos informativos que no requieren acción (sin datos, guardado ok en flujos rápidos, validaciones de selección). `Alert` cuando el usuario debe leer/aceptar o confirmar (errores de negocio, confirmación de eliminación, resultado de carga masiva).

---

## 4. Patrón estándar: pantalla CRUD

```tsx
import { useState } from 'react'
import type { ColumnDef } from '@tanstack/react-table'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined'
import {
  PageLayout, DataTable, Button, Modal, InputText, SelectField,
  Alert, Toast, exportExcel,
} from '@it-strategy/ui-kit'

interface Empleado { id: number; nombre: string; depto: string }

export const EmpleadosPage = () => {
  const { data = [], isLoading, refetch } = useEmpleados()
  const [open, setOpen] = useState(false)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({ nombre: '', depto: '' })

  const columns: ColumnDef<Empleado, any>[] = [
    { id: 'nombre', accessorKey: 'nombre', header: 'Nombre' },
    { accessorKey: 'depto', header: 'Departamento' },
    {
      id: 'acciones',
      header: 'Acciones',
      cell: ({ row }) => (
        <Button square size="small" ariaLabel="Editar"
          icon={<EditOutlinedIcon fontSize="small" />}
          onClick={() => editar(row.original)} />
      ),
    },
  ]

  const handleExport = () => {
    if (!data.length) return Toast.info('No hay información para exportar')
    exportExcel({
      fileName: 'Empleados',
      sheets: [{ name: 'Empleados', columns: [
        { key: 'nombre', header: 'Nombre', width: 30 },
        { key: 'depto', header: 'Departamento' },
      ], rows: data }],
    })
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      await guardarEmpleado(form)
      Toast.success('Empleado guardado')
      setOpen(false)
      refetch()
    } catch (e) {
      Alert.Error({ message: getErrorMessage(e) })
    } finally {
      setSaving(false)
    }
  }

  return (
    <PageLayout
      title="Gestión de Empleados"
      subtitle="Consulta y administración del personal."
      handleNew={() => setOpen(true)}
      handleRefresh={refetch}
    >
      <DataTable
        data={data}
        columns={columns}
        loading={isLoading}
        totalLabel="empleado(s)"
        pinnedLeft={['nombre']}
        searchSlot={
          <Button appearance="outline" icon={<FileDownloadOutlinedIcon fontSize="small" />} onClick={handleExport}>
            Exportar
          </Button>
        }
      />

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title="Nuevo empleado"
        size="50vw"
        footerAlign="right"
        actions={[
          { label: 'Cancelar', outlined: true, onClick: () => setOpen(false) },
          { label: saving ? 'Guardando…' : 'Guardar', onClick: handleSave },
        ]}
      >
        <InputText label="Nombre" value={form.nombre}
          onChange={(e) => setForm({ ...form, nombre: e.target.value })} />
        <SelectField label="Departamento" value={form.depto} fullWidth
          onChange={(e) => setForm({ ...form, depto: e.target.value as string })}
          options={[{ value: 'ti', label: 'TI' }, { value: 'rrhh', label: 'Recursos Humanos' }]} />
      </Modal>
    </PageLayout>
  )
}
```

---

## 5. Implementaciones nuevas — procedimiento

1. Verificar que el proyecto tiene `@it-strategy/ui-kit` instalado y en una versión reciente (§1.2). Si no, instalarlo.
2. Verificar `ThemeProvider` en el root (§1.3).
3. Armar la pantalla con `PageLayout` como contenedor.
4. Para cada pieza de UI, buscarla en la tabla de la §0 antes de escribirla.
5. Feedback al usuario con `Alert` / `Toast`; exportación con `exportExcel`.
6. Textos visibles al usuario en **español**; props y nombres de código en **inglés**.
7. Estilos locales adicionales (layout, grids, espaciado) con styled-components usando **tokens del tema** (§7).

---

## 6. Implementaciones existentes — migración

Aplicar cuando se toque una pantalla existente (feature, bug o refactor). Migrar **por pantalla**, de forma incremental; no hace falta migrar todo el micro-frontend en un solo MR.

### 6.1 Detectar candidatos

```bash
# Desde la raíz del micro-frontend
grep -rnE "from '@mui/material'.*(TextField|Select|Dialog|Autocomplete|Checkbox|Switch|Radio|Table|Button)" src
grep -rnE "@mui/x-date-pickers|@mui/x-data-grid|react-dropzone|notistack" src
grep -rnE "Swal\.fire|from 'sweetalert2'" src
grep -rnE "from 'xlsx(-js-style)?'" src
grep -rnE "#0c6478|#09d1c7|#82ee99|#424f55|#EFEFEF" -i src     # colores hardcodeados
grep -rnE "import \w+ from '@it-strategy/ui-kit'" src           # imports default incorrectos
# Componentes locales duplicados (DataTable, PageLayout, Modal, CustomInput, Loader de tabla…)
ls src/components src/shared 2>/dev/null
```

### 6.2 Equivalencias y cuidados al migrar

| Código existente | Reemplazo | Cuidado |
|---|---|---|
| `<TextField label=... />` | `<InputText label=... />` | `variant`, `size`, `fullWidth` no aplican (usar `notFull` para ancho auto). Para el look MUI clásico: `outlined` |
| `<TextField select>` / `<Select>` + `MenuItem` | `<SelectField options=[{value,label}] />` | Convertir hijos a arreglo `options` |
| `<Select multiple>` | `<SelectMultiple>` (mantiene hijos `MenuItem`) | |
| `<Autocomplete>` | `<InputAutocomplete>` | `onChange` recibe **el valor**, no `(event, value)` |
| `DatePicker` (mui/x) | `<DateField name=... />` | Valor `'YYYY-MM-DD'` string, no `Date`/dayjs. Convertir al leer/escribir |
| `DateRangePicker` / dos DatePicker | `<RangeDateTimePicker />` | `onChange(start, end)` con strings `'YYYY-MM-DD'` |
| `TimePicker` (mui/x) | `<TimeField />` | Valor `'HH:mm'` string; validar con `isValidTime` |
| `<Dialog>` | `<Modal>` | Botones del footer vía `actions`; contenido como `children` |
| MUI `Button` / botones estilizados | `<Button variant=...>` | `variant="contained"` → `appearance="solid"`; `"outlined"` → `appearance="outline"` |
| Tabla MUI / DataGrid / tabla local | `<DataTable>` | Definir columnas en formato TanStack `ColumnDef`; paginación server-side vía `totalPage` + callbacks |
| `Swal.fire({ icon: 'success' ... })` | `Alert.Ok({ message })` | |
| `Swal.fire({ icon: 'error' ... })` | `Alert.Error({ message })` | |
| `Swal.fire({ showCancelButton: true }).then(r => r.isConfirmed && ...)` | `try { await Alert.Confirm(...); ... } catch {}` | `Confirm` **rechaza** al cancelar; no hay `isConfirmed` |
| Toast de SweetAlert / notistack / Snackbar | `Toast.success/info/warning/error` | |
| `XLSX.utils.json_to_sheet` + `writeFile` | `exportExcel({ fileName, sheets })` | Mapear a `columns` con `key`/`header`; fechas ISO con `date: true` |
| `<input type="file">` / react-dropzone | `<FileDropzone>` | Validar extensión con `accept`; avisos con `onInvalidFile={Toast.error}` |
| Pantalla de error / 403 locales | `ErrorBoundaryFallback` / `AccessDenied` | |

### 6.3 Al terminar una migración

- Eliminar el componente local reemplazado si ya no tiene usos.
- Quitar dependencias que quedaron sin uso (`@mui/x-date-pickers`, `react-dropzone`, `xlsx`, `notistack`…) del `package.json`.
- Probar manualmente: estados vacío / cargando / error, validaciones, paginación y exportación.
- En el MR, listar qué componentes se migraron.

---

## 7. Tema y estilos locales

El tema es estático (Kontrolia Brand Guide). En estilos propios del micro-frontend **nunca hardcodear** colores de la paleta; usar tokens del tema. Guía completa (inyección por proyecto, Tailwind, gradiente, Manrope, deuda y checklist): skill `/kontrolia-theme`.

| Token semántico | Token legacy | HEX | Uso |
|---|---|---|---|
| `primary` | `primaryColor` | `#0c6478` | Botones primarios / CTA |
| `secondary` | `secondColor` | `#09d1c7` | Bordes, separadores, checks |
| `accent` | — | `#82ee99` | Acción / éxito |
| `dark` | `primaryFontColor` | `#424f55` | Texto cuerpo |
| `light` | `secondBackgroundColor` | `#EFEFEF` | Fondos de cards / paneles |
| `white` | `primaryBackgroundColor` | `#FFFFFF` | Fondo principal |

- Gradiente: `theme.gradients.primary`. Tipografía: `theme.fontFamily` (`'Manrope', sans-serif`).
- Transparencias con sufijo hex: `${p => p.theme.primaryColor}1A` (10%), `33` (20%), `80` (50%).
- Código nuevo → tokens semánticos. No mezclar legacy y semánticos en el mismo componente.
- Grises permitidos sin token: `#f0f0f0`, `#fcfcfc`, `#a0a0a0`; `red` para errores críticos.

```tsx
const Card = styled.div`
  background-color: ${p => p.theme.light};   // ✅
  border: 1px solid ${p => p.theme.secondary};
  color: #424f55;                            // ❌ usar p.theme.dark
`
```

---

## 8. Si falta algo en la librería

1. Revisar `CHANGELOG.md` (sección `[Unreleased]` y última versión): puede que ya exista y solo haga falta actualizar (§1.2).
2. Si un componente existente casi sirve pero le falta una prop: **proponer la prop en ui-shared**, no envolverlo ni copiarlo en el micro-frontend.
3. Si es un componente genérico nuevo (reutilizable por más de un MFE): agregarlo a ui-shared siguiendo sus convenciones:
   - Carpeta `src/components/<Nombre>/` con `index.tsx` + `styled.components.tsx` + `<Nombre>.test.tsx` (Vitest + Testing Library).
   - Exportar componente y tipo de props desde `src/index.ts` (`export type { XxxProps }`).
   - Tab en `playground/main.tsx` con al menos dos variantes y entrada en el array `docs`.
   - Documentar en `README.md` y en `CHANGELOG.md` (`[Unreleased]`).
   - Rama `feat/...` → MR a `master` → release con `npm run release:minor`.
4. Solo si es específico de un dominio (no reutilizable) se crea local en el micro-frontend, construido **sobre** los componentes de la librería.

---

## 9. Checklist de revisión (MR de un micro-frontend)

- [ ] `@it-strategy/ui-kit` instalado y versión fijada con `update-ui-kit.mjs` (lockfile + workspace commiteados)
- [ ] `ThemeProvider` en el root
- [ ] Imports **nombrados** desde `@it-strategy/ui-kit` (sin default, sin rutas internas)
- [ ] Pantallas dentro de `PageLayout`
- [ ] Tablas con `DataTable` (no MUI Table / DataGrid / tabla local)
- [ ] Formularios con `Input*` / `SelectField` / `SelectMultiple` / `DateField` / `TimeField` / `RangeDateTimePicker` / `FileDropzone`
- [ ] Modales con `Modal`; botones con `Button`
- [ ] Sin `Swal.fire` directo: `Alert` para bloqueantes, `Toast` para avisos
- [ ] `Alert.Confirm` envuelto en `try/catch`
- [ ] Sin `Alert.showSuccess/showError` con HTML del backend
- [ ] Exportación con `exportExcel` (sin `xlsx` directo)
- [ ] `DateField` con valores `'YYYY-MM-DD'`; `TimeField` validado con `isValidTime`
- [ ] Botones `square` con `ariaLabel`
- [ ] Sin colores de la paleta hardcodeados; tokens del tema en estilos locales
- [ ] Textos de UI en español
- [ ] Componentes locales reemplazados eliminados y dependencias sin uso removidas
