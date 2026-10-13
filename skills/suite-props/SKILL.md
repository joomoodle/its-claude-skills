---
name: suite-props
description: Micro-frontend shell y librería compartida @it-strategy/utilities (repo suite-props) de la suite IT Strategy / Kontrolia — stores RxJS (storeUser, storeToast, storeLoader, storeTheme, storeNotificacion…), sidebar/header, dashboard y widgets, notificaciones push FCM, cliente Api y permisos por módulo. Usar al modificar suite-props o al consumir @it-strategy/utilities desde otro micro-frontend (sesión, token, toasts, loader, permisos, menú).
---
# Skill: suite-props
Trigger: `/suite-props`

Guía para trabajar en `suite-props` (paquete `@it-strategy/utilities`) y para consumir su API pública desde otros micro-frontends.

- Repositorio: https://gitlab.it-strategy.mx/tecnologia-corporativa/tech-lead-1/suite-services/suite-props
- Reglas del repo: `CLAUDE.md`, `.claude/stores.md`, `.claude/estructura.md`, `.claude/commits.md`, `.claude/GUIA_TEMA_COLORES.md`
- Tema y colores: skill `/kontrolia-theme`. Componentes UI: skill `/ui-kit`.

---

## 0. Qué es

Cumple **dos roles**:

1. **Application single-spa (shell visual)**: sidebar `Menu`, `Header` (perfil, cambiar proyecto, logout) y `Toast`. Se registra en `container-suite/src/microfrontend-layout.html` dentro de `<route default>` junto a `@it-strategy/team-utilities`.
2. **Utility module / librería**: exporta stores RxJS, componentes y utilidades que **todos los MFE** importan como external de SystemJS.

| Dato | Valor |
|---|---|
| Nombre | `@it-strategy/utilities` (`orgName: it-strategy`, `projectName: utilities`) |
| Bundle | `it-strategy-utilities.js` (nombre fijo, sin hash) |
| Import map local | `//localhost:3031/it-strategy-utilities.js` |
| Import map nube | `${BASE_URL_MF_PROPS}/it-strategy-utilities.js?v=${VERSION_SUITE}` (`container-suite/src/index.ejs`) |
| Entry / API pública | `src/it-strategy-utilities.tsx` |

> 🚨 **Regla crítica:** no modificar `src/it-strategy-utilities.tsx` (ni firmas de stores) sin revisar el impacto en todos los MFE. Un cambio roto aquí rompe toda la suite.

---

## 1. Stack

| Área | Detalle |
|---|---|
| Gestor | **pnpm** (`packageManager: pnpm@10.34.3`, corepack). Ignorar `yarn-error.log` |
| UI | React 18.2, TypeScript 4.3 (`ts-config-single-spa`, `jsx: react-jsx`) |
| Build | webpack 5 + `webpack-config-single-spa-react-ts` + `dotenv-webpack` |
| single-spa | single-spa 5.9, single-spa-react 4.3 |
| Estado | **rxjs 7** (`BehaviorSubject`) — prohibido Context/Zustand/Redux para estado cross-MFE |
| Estilos | styled-components **6.1.13**, MUI **6.2** (`CLAUDE.md` dice v5: desactualizado) |
| HTTP | apisauce 3 (clase `Api`) + `fetch` (menú, SSE) |
| Otros | firebase 11 (FCM), exceljs, @tanstack/react-table 8, date-fns 3, sweetalert2 |
| ui-kit | `@it-strategy/ui-kit` desde git (`#v0.2.0`), **bundleado** localmente (`BUNDLE_LOCAL` en `webpack.config.js`) |
| team-utilities | External SystemJS (`storeUser.deleteUserData()` en logout); tipos en `src/types/team-utilities.d.ts` |

---

## 2. API pública (`src/it-strategy-utilities.tsx`)

```ts
export const MainContainer      // styled.div { bg?, color? } — height calc(100vh-60px), margin-left 80px
export const storeUser          // sesión
export const storeTheme         // tema (estático)
export const storeToast         // toasts globales
export const storeLoader        // loader global
export const storeNotificacion  // notificaciones
export const storeMasive        // carga masiva de usuarios
export const storeExpedientes   // expedientes
export const CreateExcel        // clase export Excel
export const Table              // (props: ITable) => tabla tanstack
export const PDashboard         // dashboard (lo monta catalogos-suite en /dashboard)
export const { bootstrap, mount, unmount }
```

> ⚠️ **No se exportan en runtime** `defaultTheme`, `ITheme`, `IUser` ni hooks. Algunos MFE los importan y solo compila gracias a `.d.ts` locales. Para el tema usar `storeTheme.storeTheme$`.

### Stores

Todos: `BehaviorSubject` privado + getter `Observable`.

| Store | Observables | Métodos |
|---|---|---|
| `storeUser` | `storeUser$: Observable<IUser>` | `addUser(user)`, `deleteUser()`, `updateImagen(img)`, `getActionsByModulo(route?)`, `subscribe(listener)`, `getSnapshot()`, `getFromLocalStorage()` *(deprecated)* |
| `storeTheme` | `storeTheme$` | `getSnapshot()`; `setTheme()` / `initTheme()` son **no-op** |
| `storeToast` | `storeToast$` | `handleToast({ message, title?, severy?, timer?, visible?, action? })` — defaults `timer 3000`, `severy 'warning'`, `title 'Precaución'`; `initToast()` |
| `storeLoader` | `storeLoader$: Observable<boolean>` | `changeLoader(bool)` |
| `storeNotificacion` | `storeNotificacion$`, `handleNotification$`, `filters$` | `setNotificacion(arr)`, `changeNotification(flag)`, `setFilters(req)` |
| `storeMasive` | `storeMasive$` | `handleMasive(el)`, `initToast()` (nombre heredado) |
| `storeExpedientes` | `storeExpedientes$` | `initExpedientes()`, `setIdTipoOperacionExp(id, videoDeclaracion)` |

`IUser` (`src/store/userStore.ts`): `{ token?, userData? (claims JWT), usuario?, operation? {id, name, marca}, seguridadCorp?, canChangeOperation?, closeSesion?, segRelUsuarioAmbienteTbl?, propietario?, verificadoTelefono? }`.

### Consumo desde otro MFE

```ts
import { storeUser, storeToast, storeLoader } from '@it-strategy/utilities'

useEffect(() => {
  const sub = storeUser.storeUser$.subscribe(setUser)
  return () => sub.unsubscribe()            // obligatorio
}, [])

storeToast.handleToast({ message: 'Guardado', severy: 'success', title: '¡Listo!' })
const acciones = await storeUser.getActionsByModulo('catalogos/usuarios')
```

- `@it-strategy/*` es external en webpack de los consumidores (salvo `@it-strategy/ui-kit`, que se bundlea).
- Los tipos se declaran con un `.d.ts` local en cada consumidor (p. ej. `mf-gestion-nomina/src/types/theme-store.d.ts`). `pnpm build:types` genera `dist/it-strategy-utilities.d.ts`, pero no se publica.
- En Jest, los consumidores mapean `@it-strategy/utilities` a un mock propio.

---

## 3. Estructura de `src/`

| Ruta | Propósito |
|---|---|
| `it-strategy-utilities.tsx` | Entry: API pública + lifecycles |
| `root.component.tsx` | `BrowserRouter` + `ThemeProvider(defaultTheme)` + `GlobalStyle` + `AppShell` |
| `components/app-shell` | Menu + Header + Toast (+ Dashboard solo en standalone) |
| `components/menu` | Sidebar por agrupadores/módulos; drawer < 768px; hover-expand 150 ms |
| `components/header` | Perfil + dropdown: Cambiar Proyecto (`/login/change-project`), Ajustes de Perfil (`/profile`), Cerrar Sesión |
| `components/toast` | Snackbar MUI conectado a `storeToast` |
| `components/dashboard` | `PDashboard`, `SoporteBar`, `BannerDefault` |
| `components/widgets/w-*` | Widgets del dashboard (acceso-rapido, accesos-directos, asistencia, cumpleanos, indicador-usuarios, modulo-card, notificaciones, nuevo-usuario) |
| `components/table`, `components/export-excel` | `Table` y `CreateExcel` |
| `components/verificacion-telefono` | Modales teléfono + OTP |
| `components/notifications` | Panel legado — **no montado** |
| `firebase/firebase.ts` | FCM web push |
| `hooks/` | `useAppShell`, `useMenu`, `useMenuUI`, `useHeaderUI`, `useDashboardStream` (SSE), `useDashboardPermisos`, `useTheme`, … (`useSignalR` es un stub vacío) |
| `interface/` | `ITheme` (+`defaultTheme`), `ITable`, `IApiNotification`, `MenuAgrupador`, … |
| `services/` | `api.ts` (clase `Api`), `dashboard.ts`, `notifications.ts`, `infografia.ts`, `verificacion-telefono.ts` |
| `store/` | Los 7 stores |
| `mocks/` | `menuRoutes.ts` (menú standalone), `team-utilities.ts` |
| `config/env.ts` | `IS_STANDALONE` |

Convenciones (`.claude/estructura.md`): directorios kebab-case lowercase; componente = `index.tsx` + `styled.components.tsx`; widgets en `components/widgets/w-*`; interfaces con prefijo `I`; hooks `useX`; stores con sufijo `Store`. Renombrar mayúsculas en macOS con `git mv` en dos pasos.

---

## 4. Sesión, HTTP, menú y permisos

- **Login no vive aquí**: `@it-strategy/auth` (auth-front) llama `storeUser.addUser(...)`.
- **Persistencia** (`localStorage`, solo dentro de los stores): `suite-user` (sesión), `suite-notificacion`, `suite-fcm-token-{idUsuario}`, `suite-tokens-save`. No acceder a `localStorage` directo fuera de los stores.

### Cliente `Api` (`src/services/api.ts`)
- `baseURL = process.env.AUTH_API_URL` (gateway `/v1`). Inyecta `Authorization: Bearer` desde `storeUser.getSnapshot()` y activa `storeLoader`; el `finally` lo apaga.
- 200/201 → `data`; 204 → `true`; **401** → `deleteUser()` + toast "Tu sesión ha expirado" + redirect `/login` (no en standalone); 400/404/500 → toast (salvo `silent: true`).

### Menú (`hooks/useMenu.ts`)
`GET ${AUTH_API_URL}/authentication/tipo-operacion/{operation.id}/menu` → `MenuAgrupador[]`. 401/error → `deleteUser()` + `/login`. Al navegar, el menú pasa `state: { permisos }`.

### Permisos por módulo
`storeUser.getActionsByModulo(route)` → `GET /authentication/AccionesModuloUsuario?idTipoOperacion=..&moduloUrl=..` → `acciones`. Caché en memoria 5 min por `operationId:ruta` (se limpia en `deleteUser`).

### Logout
`storeUser.deleteUser()` + `storeTeam.deleteUserData()` + `navigate('/login')`.

---

## 5. Dashboard y notificaciones

- **SSE** `GET /catalogs/widget/stream/{operationId}` (eventos `banner`, `birthday-boys`, `limite-usuarios`, `done`) vía `fetch` + `ReadableStream` (`useDashboardStream`).
- Visibilidad de widgets por rutas del menú (`useDashboardPermisos`): p. ej. widget Usuarios si existe `catalogos/usuarios`; Alta de usuarios si además `idAccion === 2`.
- **FCM** (`firebase/firebase.ts`): `initFirebaseMessaging({ idUsuario, idAplicacion }, { force })` registra `/firebase-messaging-sw.js` (lo sirve el host, no este repo), pide permiso, obtiene token y hace `POST notifications/api/devices/register`. Foreground: `setForegroundHandler` → toast + `ServiceNotification.get(filters)`.
- **API de notificaciones nueva**: `GET notifications/api/notifications?status&channel&page&pageSize`, `PATCH notifications/api/notifications/{id}/open` (silent).
- **Widget `w-notificaciones`**: carga `{ channel: 'push-web', pageSize: 20 }` una vez, agrupa por fecha, badge de no leídas, links `~https://...~` → "Abrir enlace ↗"; banner "Activar notificaciones push" si permiso `default`; oculto si `denied`.
- SignalR: `useSignalR` es un stub; no hay websocket activo.

---

## 6. Ejecución local

| Script | Uso |
|---|---|
| `pnpm start` | `webpack serve --host 0.0.0.0 --port 3031` (integrado con container-suite en `:9000`) |
| `pnpm start:standalone` | Standalone en `:3031` con `IS_STANDALONE=true` |
| `pnpm build` | `build:webpack` + `build:types` |
| `pnpm test` / `coverage` | Jest 27 + Testing Library |
| `pnpm lint` | `eslint src --ext js,ts,tsx` |

**Standalone**: menú desde `src/mocks/menuRoutes.ts`, usuario de header falso, renderiza `<Dashboard/>`, mocks de dashboard, sin Firebase ni redirect 401. `standalone-mocks/team-utilities.js` (System.register) reemplaza `@it-strategy/team-utilities`.

**Variables de entorno** (`.env`, vía dotenv-webpack): `AUTH_API_URL` (gateway `/v1`), `URL_WEB_SOCKET` (sin uso efectivo). `IS_STANDALONE` lo inyecta `DefinePlugin`.

---

## 7. Testing

- Jest 27 + jsdom + babel-jest; `jest.config.js` transpila `apisauce`/`axios` (también en `.pnpm`), mapea `@it-strategy/*` (excepto ui-kit) a `identity-obj-proxy` y assets a `__mocks__/fileMock.js`.
- Tests junto al archivo (`*.test.tsx`). Los widgets que usan ui-kit lo mockean.
- Al cambiar un store o un export: agregar/ajustar test y revisar consumidores (`grep -rn "storeX\." ../*/src`).

---

## 8. CI/CD

Stages `test → docker-build → deploy` (`.gitlab-ci.yml`):
- `test`: `node:22-alpine` + corepack; reescribe la URL git con `UI_KIT_TOKEN_USER/PASS` para instalar ui-kit; `pnpm install --frozen-lockfile && pnpm test`.
- `docker-build`: `gcloud builds submit --config=cloudbuild.yaml` (`_AUTH_API_URL`, `_SERVICE_NAME=mf-props-front-$BRANCH`, `_URL_WEB_SOCKET`, tokens ui-kit).
- `deploy`: Cloud Run `us-central1`, puerto **8080**. Servicios `mf-props-front-{development,qa,preproduction,master}`; **master es manual**.
- `Dockerfile`: builder node 22 (usuario `node`, limpia el token del git config) → `nginxinc/nginx-unprivileged:1.21-alpine` con `default.conf`. (`nginx.conf` no se usa.)

### Caché del bundle
- `default.conf`: `*.js` → `max-age=31536000, immutable` + CORS; `/` → `no-store`.
- El bundle **no tiene hash**: el cache-busting depende de que `VERSION_SUITE` (en **container-suite**) cambie en cada deploy. Si queda fija, los navegadores siguen con el JS viejo hasta un año.

---

## 9. Reglas y gotchas

- Commits: `tipo: descripción` en español, imperativo, sin punto final (`feat|fix|refactor|docs|chore|test|style`), atómicos. **Sin `Co-Authored-By` ni referencias a IA** (regla del repo, prevalece).
- Nuevo store: `BehaviorSubject` privado + getter, instanciar y exportar en el entry, documentar en `.claude/stores.md` y en esta skill. `unsubscribe()` obligatorio en consumidores.
- `.claude/stores.md` nombra mal archivos: reales son `notificacionesStore.ts` y `usuariosMasiveStore.ts`.
- `errorBoundary` de los lifecycles devuelve `null` (errores invisibles).
- `useDashboardPermisos` crea otra instancia de `useMenu` → segundo fetch del menú.
- Dependencia circular: services/hooks importan stores desde `../it-strategy-utilities`.
- Widget de notificaciones: `idAplicacion: 73` hardcodeado y `userId` leído de `x?.idUsuario` (en `IUser` está en `usuario.idUsuario`) → posible registro FCM fallido.
- Config de Firebase y VAPID key están en el código (`firebase/firebase.ts`).
- `README.md` es la plantilla de GitLab; la documentación real está en `CLAUDE.md` y `.claude/`.

## 10. Checklist de MR

- [ ] Sin cambios incompatibles en exports/firmas de `it-strategy-utilities.tsx` (o consumidores actualizados)
- [ ] Stores nuevos siguen el patrón `BehaviorSubject` + getter y están documentados
- [ ] Sin `localStorage` fuera de los stores
- [ ] Llamadas HTTP vía `Api` (token, loader y 401 centralizados)
- [ ] Colores con tokens del tema (`/kontrolia-theme`); UI con ui-kit (`/ui-kit`)
- [ ] Probado integrado (`:3031` + container `:9000`) y en standalone
- [ ] `pnpm test` y `pnpm lint` en verde
