---
name: catalogos-suite
description: Micro-frontend catalogos-suite (@it-strategy/catalogos-suite) de la suite IT Strategy / Kontrolia — catálogos (marcas, usuarios, organigrama, perfiles, módulos, puestos, departamentos…), configuración, perfil y dashboard. Usar al crear o modificar páginas de catálogo, servicios con la clase Api (apisauce), permisos con usePermisos/checkPermissions, rutas en root.component.js, tests Jest o al correr el proyecto en standalone.
---
# Skill: catalogos-suite
Trigger: `/catalogos-suite`

Guía para trabajar en el micro-frontend de catálogos. Al invocarse para una pantalla nueva: seguir el patrón canónico (§3) y usar `@it-strategy/ui-kit` (`/ui-kit`) y tokens del tema (`/kontrolia-theme`).

- Repositorio: https://gitlab.it-strategy.mx/tecnologia-corporativa/tech-lead-1/suite-services/catalogos-suite
- Reglas del repo: `CLAUDE.md`, `.claude/rules/{structure,code-style,commits,nueva-pagina,GUIA_TEMA_COLORES}.md`
- Ejemplo de referencia del patrón actual: `src/pages/opcion-menu-movil/`
- `README.md` está **desactualizado** (dice React 17, axios y rutas sin prefijo): no usarlo como referencia.

---

## 0. Qué es

| Dato | Valor |
|---|---|
| App single-spa | `@it-strategy/catalogos-suite` (`orgName: it-strategy`, `projectName: catalogos-suite`) |
| Entry | `src/it-strategy-catalogos-suite.js` (`singleSpaReact`, `errorBoundary` → `ErrorBoundaryFallback` de ui-kit) |
| Se monta en | `/catalogos`, `/configuracion`, `/profile`, `/dashboard` (`container-suite/src/microfrontend-layout.html`) |
| Import map | local `//localhost:8081/it-strategy-catalogos-suite.js`; nube `BASE_URL_MF_CATALOGOS` |
| Root | `src/root.component.js`: suscribe `storeUser$` y `storeTheme$`, `ThemeProvider`, `BrowserRouter`. Si hay usuario sin `operation.id` → `window.location.href = '/login'` |

### Rutas (`src/root.component.js`)

| Ruta | Página (`src/pages/…`) |
|---|---|
| `/catalogos/marcas` · `tipos-operaciones` · `regiones` · `sectores` · `modulos` · `aplicaciones` · `direcciones-sepomex` | `marcas`, `tipos-operacion`, `regiones`, `sectores`, `modulos` (+ agrupador de menú), `aplicaciones`, `direcciones-sepomex` |
| `/catalogos/perfiles` · `usuarios` · `puestos` · `departamentos` | `perfiles`, `usuarios` (+ `organigrama/`), `puestos`, `departamentos` |
| `/catalogos/signer` · `marcas-apps` · `perfil-movil` · `modulo-mobile` · `opcion-menu-movil` | `file-input`, `brands-apps`, `perfil-movil`, `modulo-mobile`, `opcion-menu-movil` |
| `/configuracion/tipo-operacion` · `puestos-operacion` · `calendario-feriados` · `banners` | `config/*` |
| `/profile` | `Profile` |
| `/dashboard` | `PDashboard` de `@it-strategy/utilities` |
| `/` | `components/StandaloneNav` (menú solo dev) |

Algunas rutas reciben `user` / `userSession` como prop: **llega `null` en el primer render** → siempre `user?.operation?.id`.

---

## 1. Stack

| Pieza | Detalle |
|---|---|
| Lenguaje | **JavaScript** (`.js` / `.jsx`), sin TypeScript |
| React | 18.1, react-router-dom **v6** |
| Build | webpack 5 + `webpack-config-single-spa-react` + `dotenv-webpack` |
| UI | `@it-strategy/ui-kit` (git `#v0.2.0`, **bundleado**: `BUNDLED_PACKAGES` en webpack), MUI 5, styled-components 6 (rc) |
| Tablas | `@tanstack/react-table` 8 (`createColumnHelper`) |
| HTTP | **apisauce** (clase `Api`) — sin axios directo, sin react-query |
| Formularios | `useState` + esquemas `SCHEMADATA` validados con `validateData` (`src/utils/index.js`) — sin formik ni react-hook-form |
| Alertas | `src/utils/Alert.js` local (sweetalert2) + `storeToast.handleToast` |
| Gestor | **pnpm** (CI `pnpm@10.34.3`, Node 20). `yarn.lock`/`.yarnrc.yml` son heredados |

De `@it-strategy/utilities` (external SystemJS, ver `/suite-props`): `storeUser` (`storeUser$`, `getActionsByModulo`, `deleteUser`, `updateImagen`), `storeTheme.storeTheme$`, `storeLoader`, `storeToast.handleToast`, `PDashboard`.

Componentes ui-kit usados: `Modal`, `DataTable`, `Button`, `InputText`, `SelectField`, `PageLayout`, `SectionHeader`, `InputPassword`, `InputNumber`, `DateField`, `ErrorBoundaryFallback`. Actualizar ui-kit con `pnpm update:ui-kit [tag]` (`scripts/update-ui-kit.mjs`).

---

## 2. Estructura de `src/`

```
src/
  it-strategy-catalogos-suite.js   entry single-spa
  root.component.js                router + stores + ThemeProvider
  services/      api.js (clase Api), marca.js, sepomex.js, tipoOperacion.js   ← compartidos (≥2-3 features)
  hooks/         useFetch.js (legacy), usePermisos.js
  utils/         index.js (validateData, checkPermissions, onlyChangePatch…), Alert.js, constants.js (typeModal)
  constantes/    actions.js (IDs de permisos)
  components/    Container, ModalComponets/FooterBtns, InputModal, ImageUploader, StandaloneNav, shared/StatusBadge…
  schemes/       esquemas de formulario
  mockups/       it-strategy-utilities.js (mock Jest), data/ (mocks devServer)
  __mocks__/     standalone.js (login real en standalone), lottie-react.js
  pages/<feature>/
```

Reglas (`.claude/rules/structure.md`): `index.jsx` **solo renderiza**; fetch/estado/efectos en `hooks/` (una responsabilidad por hook); componente usado en ≥2 páginas → `components/shared/`; servicio usado en varias features → `src/services/`; máximo 3 niveles; componentes PascalCase, hooks `useX`, carpetas kebab-case.

Hay páginas **legacy** (`marcas`, `regiones`, `sectores`, `puestos`…: lógica en `index.jsx`, `useFetch`, `components/Create|Edit|Details.js` con `InputModal`). No replicar ese patrón; al tocarlas, migrar al canónico.

---

## 3. Patrón canónico para un catálogo nuevo

```
src/pages/<kebab>/                      (configuración → src/pages/config/<kebab>/)
  index.jsx                             PageLayout + DataTable + Modal (ui-kit)
  columns.js                            I<Feature>({ handlers }) con createColumnHelper
  service.js                            clase Service<Feature> con static async + new Api()
  components/<Feature>Form.jsx (+ styled.components.jsx)
  hooks/use<Features>.js                listado + toggle de estatus
  hooks/use<Feature>Modal.js            open/title/typeModal/handleNew/handleEdit
  hooks/use<Feature>Form.js             SCHEMADATA + validateData + submit
  *.test.js(x)                          junto a cada archivo
```

### Página
```jsx
const { opciones, getAll, handleToggleStatus } = useOpcionesMenuMovil()
const { permisos } = usePermisos()
const { open, title, componentActual, loading, selected, typeModal, handleChange, handleNew, handleEdit } = useOpcionMenuMovilModal()

if (!checkPermissions({ acciones: permisos, action: actions.CONSULTA })) return null

return (
  <PageLayout title='Opciones de menú móvil' subtitle='…'
    handleNew={checkPermissions({ acciones: permisos, action: actions.ALTA }) ? handleNew : undefined}>
    <DataTable
      columns={IOpcionesMenuMovil({
        handleEdit: checkPermissions({ acciones: permisos, action: actions.EDICION }) ? handleEdit : undefined,
      })}
      data={opciones} totalLabel='Opción(es)' />
    <Modal title={title} open={open} onClose={handleChange()} showCloseIcon={!loading} showFooter={false} size='30vw'>
      {[typeModal.NEW, typeModal.EDIT].includes(componentActual) &&
        <OpcionMenuMovilForm key={selected?.idOpcion ?? 'nuevo'} … />}
    </Modal>
  </PageLayout>
)
```

### Servicio
```js
import { Api } from '../../services/api'          // export NOMBRADO, se instancia

export default class ServiceOpcionMenuMovil {
  static async getAll({ setterFunc }) {
    const response = await new Api().get('/mobile-menu-options')
    setterFunc(response || [])
    return response
  }
  static async toggleStatus({ id }) {
    return await new Api().remove(`/mobile-menu-options/${id}`)   // DELETE = remove (no existe .delete)
  }
}
```

### Hook con confirmación
```js
Alert.Confirm({ title: `Se ${accion} la opción "${nombre}", ¿Estás seguro?` }).then(async () => {
  const response = await ServiceOpcionMenuMovil.toggleStatus({ id })
  if (!response) return                         // Api ya mostró el error
  storeToast.handleToast({ message: '…', severy: 'success', title: '¡Listo!' })
  getAll()
})
```

### Pasos
1. Crear carpeta y archivos del patrón.
2. Registrar la ruta en `src/root.component.js` con sintaxis **v6** dentro de `<Route path="catalogos">` o `<Route path="configuracion">`: `<Route path="mi-feature" element={<MiFeature />} />`. (`nueva-pagina.md` muestra sintaxis v5 e `import api from …` default: ambos incorrectos.)
3. Agregar el link en `SECTIONS` de `src/components/StandaloneNav/index.jsx`.
4. El menú lateral **no vive aquí**: dar de alta el módulo en el catálogo **Módulos** (campo `url`) y asignar acciones por perfil.
5. Tests (§6) y checklist de `.claude/rules/nueva-pagina.md`.

### Modal
Siempre `Modal` de ui-kit con `onClose={handleChange()}`, `showCloseIcon={!loading}`, `showFooter={false}`; botones dentro del form (`FooterBtns`). El modal local se eliminó.

---

## 4. Capa de datos y permisos

### `src/services/api.js` — clase `Api`
- `apisauce.create({ baseURL: process.env.BASE_URL })`; `BASE_URL` **termina en `/catalogs`**.
- `new Api({ removeCatalogs: true })` quita `/catalogs` para otros controladores (`/marca`, `/tipo-operacion`, `/user/...`, sepomex).
- Métodos: `get`, `post`, `put`, `patch`, `remove`, `postFormData`, `putFormData`.
- Token desde `storeUser.storeUser$` → `Authorization: Bearer`; activa `storeLoader`.
- `responseCode`: 200/201/204 → `data || true`; 401 → alerta de sesión expirada + `deleteUser()`; 500 → `Alert.Error`; otros → `Alert.Notice` con mensaje del backend. **En error devuelve `null` y ya alertó** → en el llamador solo `if (!response) return` (no duplicar alertas).
- PATCH en JSON Patch: `[{ op: 'replace', path: '/campo', value }]` (ver `onlyChangePatch`, `services/marca.js`).
- Excepción: `pages/usuarios/organigrama/service.js` usa su propio cliente sin alertas ni loader; devuelve `{ ok, data } | { ok: false, error }`.

### Permisos
- `usePermisos()` → `storeUser.getActionsByModulo()` → `/authentication/AccionesModuloUsuario?moduloUrl=<path sin primer segmento>` (ej. `/catalogos/usuarios` → `usuarios`), con caché.
- `src/constantes/actions.js`: `CONSULTA 1, ALTA 2, EDICION 3, DETALLE 4, HABILITACION_INHABILITACION 5, ADD_ACCIONES 6, ACCIONES 7`.
- Guard de página: `checkPermissions({ acciones: permisos, action: actions.CONSULTA })` → `return null`. Handlers de columnas y `handleNew` condicionados a su acción.

### Sesión
`user` de `storeUser$`: `token`, `usuario`, `userData` (JWT decodificado), `operation { id, name, marca, proyectoRHIN }`, `seguridadCorp`. No usar `localStorage` directo.

---

## 5. Ejecución local

| Script | Uso |
|---|---|
| `pnpm start` | `:8081`, integrado con container-suite en `:9000` |
| `pnpm start:standalone` | Standalone con login real automático |
| `pnpm build` | `webpack --mode=production` |
| `pnpm test` / `coverage` / `test:ci` | Jest |
| `pnpm update:ui-kit [tag]` | Actualiza ui-kit (ver `/ui-kit`) |

**Standalone**: import map apunta `@it-strategy/utilities` a `public/standalone-mocks/it-strategy-utilities.js`; `src/__mocks__/standalone.js` hace login real contra `STANDALONE_AUTH_URL` (auth → tipos-operacion-usuario → tipo-operacion) y emite el usuario; `getActionsByModulo` mock devuelve todos los permisos. Los mocks del devServer (`src/mockups/data`) solo aplican si `BASE_URL` es local.

### Variables de entorno (`.env`, gitignoreado)
| Variable | Uso |
|---|---|
| `BASE_URL` | Gateway `…/v1/catalogs` (**con** `/catalogs`; `.env.example` lo trae sin él) |
| `API_KEY_MAPS` | Google Maps / Geocoding (usuarios) |
| `AUTH_API_URL` | Se pasa en Docker/CI (lo usa suite-props) |
| `STANDALONE_AUTH_URL`, `STANDALONE_USUARIO`, `STANDALONE_CONTRASENA`, `STANDALONE_ID_APLICACION`, `STANDALONE_ID_AMBIENTE`, `STANDALONE_ID_ORIGEN`, `STANDALONE_ID_TIPO_OPERACION` | Login automático en standalone |

---

## 6. Testing

- Jest 27 + Testing Library 12 + jsdom; `rootDir: src`; `@it-strategy/utilities` → `src/mockups/it-strategy-utilities.js` (usuario con `operation.id 8` y todos los permisos).
- Tests **junto al archivo**, descripciones en español, `data-testid` kebab-case (`btn-nueva-opcion`, `btn-editar-${id}`).
- Hooks se prueban con un componente `Harness` (no `@testing-library/react-hooks`).
- Mocks típicos:
```js
jest.mock('@it-strategy/ui-kit', () => ({ Button: …, DataTable: …, Modal: …, PageLayout: … }))
jest.mock('../../services/api', () => ({ Api: jest.fn() }))
Api.mockImplementation(() => buildApiMock({ get: jest.fn().mockResolvedValue([...]) }))
jest.mock('../../hooks/usePermisos')
jest.mock('../../utils/Alert', () => ({ Confirm: jest.fn() }))
```
- Referencia: `src/pages/opcion-menu-movil/**/*.test.js(x)`, `pages/usuarios/components/CreateUsuario/index.test.jsx`.
- **Husky pre-commit** corre tests + `build:webpack`; si fallan, no hay commit.

---

## 7. CI/CD

Stages `build → test → docker-build → deploy`:
- `build-js` / `test-js` en todas las ramas (node 20 + pnpm); `UI_KIT_TOKEN_USER/PASS` para clonar ui-kit.
- `docker-build`: `gcloud builds submit` (`_SERVICE_NAME`, `_BASE_URL`, `_API_KEY_MAPS`, `_AUTH_API_URL`, tokens).
- Cloud Run `us-central1`, puerto 80: `mf-catalogos-front-{development,preproduction,master}`; **master manual**.
- Flujo: `feature/*` | `fix/*` → `development` → `preproduction` → `master`.
- nginx (`default.conf`): js/css 1 año `immutable` + CORS; `/` sin caché.

---

## 8. Convenciones

- UI, mensajes, dominio, tests y commits en **español**.
- Estilo (`code-style.md`): comillas simples, sin `;`, 2 espacios, componentes `const` arrow, early return, async/await, sin `console.log`, componentes < ~150 líneas. (No hay `.prettierrc`; no correr `prettier --write` masivo sobre archivos legacy.)
- Servicios: clase `Service<X>` con `static async` y parámetros por objeto (`{ setterFunc, id, data }`). Columnas: `I<Feature>({ handlers })`.
- Colores con tokens (`/kontrolia-theme`).
- Commits: `tipo(scope): descripción` imperativo (`feat|fix|refactor|test|chore|ci|docs`), atómicos. **Sin `Co-Authored-By`** (regla del repo, prevalece).

## 9. Gotchas

1. `services/marca.js#delete` y `tipoOperacion.js#delete` llaman `API.delete`, que no existe → usar `remove`.
2. `Dockerfile` escribe `AUTH_API_URL` de development hardcodeado, ignorando el ARG.
3. `update-ui-kit.mjs` reescribe `pnpm-workspace.yaml` y elimina `allowBuilds`/`core-js-pure`: revisar el diff antes de commitear.
4. `package.json` fija ui-kit `#v0.2.0` (no incluye `Alert`/`configureAlerts`); por eso existe `utils/Alert.js` local.
5. `pnpm lint` usa `--ext js` (excluye `.jsx`) y no hay `.eslintrc`.
6. Husky usa `yarn` aunque el gestor es pnpm.
7. `GUIA_TEMA_COLORES.md` cita rutas de suite-props con mayúsculas que ya no existen.
8. `ThemeProvider` arranca con `{}` hasta que emite `storeTheme$`.
9. `components/ErrorBoundaryFallback` local duplica el de ui-kit (el entry ya usa el de ui-kit).

## 10. Checklist de MR

- [ ] `index.jsx` solo compone; lógica en `hooks/`
- [ ] Servicio con `new Api()` (import nombrado) y `if (!response) return`
- [ ] Guard `CONSULTA` + handlers condicionados por permiso
- [ ] `user?.operation?.id` con optional chaining
- [ ] Ruta v6 registrada + link en `StandaloneNav`
- [ ] UI con ui-kit (`PageLayout`, `DataTable`, `Modal`, `Button`, `Input*`)
- [ ] Colores con tokens del tema
- [ ] Tests junto al archivo; `pnpm test` y `pnpm build` en verde
