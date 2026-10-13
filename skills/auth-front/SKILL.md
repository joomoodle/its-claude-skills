---
name: auth-front
description: Micro-frontend de autenticación auth-front (@it-strategy/auth) de la suite IT Strategy / Kontrolia — login por usuario/correo, OTP por WhatsApp, recuperación de contraseña, selección y cambio de tipo de operación, sesión en sessionStorage (auth_session) y storeUser compartido. Usar al modificar el login o el flujo de sesión, al consumir auth_session desde otro MFE, o al escribir tests Jest/Playwright (E2E mocked y smoke).
---
# Skill: auth-front
Trigger: `/auth-front`

Guía para trabajar en el micro-frontend de login y para entender el contrato de sesión que consumen los demás MFE.

- Repositorio: https://gitlab.it-strategy.mx/tecnologia-corporativa/tech-lead-1/suite-services/auth-front
- Reglas del repo: `CLAUDE.md`, `.claude/rules/{structure,code-style,commits,code-review}.md`
- Guía E2E para otros MFE: `E2E_GUIDE_MFE.md`
- Tema (clases Tailwind `k-*`): skill `/kontrolia-theme`. Store de sesión: skill `/suite-props`.

---

## 0. Qué es

| Dato | Valor |
|---|---|
| Nombre en import map / layout | **`@it-strategy/auth`** |
| Nombre en webpack / package | `auth-suite` (`orgName: it-strategy`) → bundle `it-strategy-auth-suite.js` |
| Tipo | Application single-spa (no parcel) |
| Se monta en | `/login` (`container-suite/src/microfrontend-layout.html`) |
| Import map | local `//localhost:8080/it-strategy-auth-suite.js`; nube `BASE_URL_MF_AUTH` + `?v=VERSION_SUITE` |
| Entry | `src/it-strategy-auth-suite.js` (`singleSpaReact`, `errorBoundary` devuelve `null`) |

Rutas (`src/routes.js`, `BrowserRouter basename="/"`): `/` y `/login` → `Auth` (wizard); `/login/change-project` → `ChangeProject`.

Funcionalidades: login usuario/correo + contraseña, login por OTP de WhatsApp (6 dígitos, reenvío cada 3 min), recuperación de contraseña por correo, selección de tipo de operación (multi-operación/marca) y cambio de operación sin re-login. **No hay** MFA adicional, refresh token ni pantalla de logout.

---

## 1. Stack

| Pieza | Detalle |
|---|---|
| Lenguaje | **JavaScript + JSX**, sin TypeScript ni PropTypes |
| React | 18.2, react-router-dom 6, single-spa-react 4 |
| Estado | Redux Toolkit (`store.js` → `{ auth }`) + rxjs |
| Estilos | **Tailwind 3** (+ `tailwindcss-animated`) y `src/styles.css`. **No usa styled-components ni `@it-strategy/ui-kit`** |
| UI extra | MUI 5 (íconos/material), react-icons, react-loader-spinner, react-otp-input |
| HTTP | axios + `fetch` nativo (en `useSelectOperation`) |
| Tests | Jest 27 + Testing Library 14; Playwright 1.61 |
| Lint | ESLint 7 (`react-important-stuff` + prettier), Prettier 2 |
| Gestor | **yarn** (CI `yarn install --frozen-lockfile`, `.yarnrc.yml nodeLinker: node-modules`). Existe también `package-lock.json`: no usar npm |

Externals SystemJS: `@it-strategy/utilities` (`storeUser`, `storeTheme`) y `@it-strategy/team-utilities` (`storeUser.addUserData`).

---

## 2. Estructura de `src/`

```
it-strategy-auth-suite.js   lifecycles
root.component.js           <Provider store> + <Routes/>
routes.js, store.js, styles.css
pages/
  auth/index.jsx + hooks/useAuthSteps.js     wizard: FORM_LOGIN=0, PASSWORD=1, OPERATION=2
  change-project/index.jsx                   cambiar operación con sesión existente
components/
  Login/FormLogin.jsx, SelectOperation.jsx, ForgetPassoword.jsx (typo en el nombre)
  Login/Formularios/Login.jsx, WhatsApp.jsx
  Login/hooks/useLogin, useLoginForm, useWhatsApp, useForgetPassword, useSelectOperation
  Codes/Codes.jsx                            input OTP
redux/auth/authSlice.js, authActions.js, authRequest.js
utilities/authSession.js (sessionStorage), utils.js (getUserData: decodifica JWT), loader.js
__mocks__/ axiosMock, fileMock, itStrategyUtilities, itStrategyTeamUtilities
```

Regla objetivo (`.claude/rules/structure.md`): `pages/<pagina>/{components,hooks,index.jsx}`, `components/shared/` para lo usado en ≥2 páginas, `index.jsx` sin lógica, un hook por responsabilidad, máx. 3 niveles. El código actual no la cumple del todo (hooks de login en `components/Login/hooks`): **código nuevo sí debe seguirla**.

---

## 3. Flujo de autenticación

### Endpoints (base `process.env.URL_BASE_API`)
| Método | Endpoint | Uso |
|---|---|---|
| POST | `authentication/auth` | Login por nombre de usuario (sin `@`) |
| POST | `authentication/authOld` | Login por correo |
| POST | `authentication/generate-codigo` | Envía OTP WhatsApp `{ usuario }` |
| POST | `authentication/auth-codigo` | Valida OTP |
| POST | `user/forget-password?email=…` | Recuperar contraseña |
| GET | `authentication/tipos-operacion-usuario` | Operaciones del usuario (Bearer) |
| POST | `authentication/tipo-operacion/{id}/{idMarca}` | Nuevo JWT ligado a la operación (Bearer) |

Payload de login: `{ correo, nombreUsuario, contrasena, idAplicacion, idAmbiente, idOrigen }` (IDs desde env). Errores del backend: `ErrorInvalidUser` → "Credenciales invalidas", `ErrorUserNotExistsInEnviroment` → "Usuario no existe", `ErrorUserNotFound` (forget-password).

### Secuencia
1. **Login OK** → `getUserData(token)` decodifica el JWT → `storeUser.addUser({ ...result, closeSesion: false })` + `saveSession(...)` → paso OPERATION.
2. **`useSelectOperation`** pide operaciones:
   - 0 o error → `storeUser.deleteUser()` + `clearSession()` → vuelve a login.
   - 1 → se aplica sola (`canChangeOperation: false`).
   - Varias → el usuario elige (`canChangeOperation: true`).
3. **`applyOperation`** → `tipo-operacion/{id}/{idMarca}` reemplaza `token`/`userData` → `storeUser.addUser(payload)` + `saveSession(payload)` + `storeTeam.addUserData({...})` → `navigate('/dashboard')`.
4. Si el store ya tiene `operation` y `!closeSesion`, `useAuthSteps` redirige a dashboard.
5. **Cambiar operación** (`/login/change-project`): lee `getSession()`; sin sesión → `/login`.
6. **Logout**: lo hace el shell (suite-props). Aquí `closeSesion: true` regresa al paso de login.

### Almacenamiento (`src/utilities/authSession.js`)
```js
const SESSION_KEY = 'auth_session'          // sessionStorage + caché en memoria
saveSession(user) / getSession() / clearSession()
```
No usa cookies ni localStorage (suite-props persiste aparte en `localStorage.suite-user`).

### Contrato `auth_session` (lo consumen otros MFE y sus E2E)
`{ token, userData, operation { id, name, marca { idMarca } }, canChangeOperation, seguridadCorp, closeSesion, usuario {…}, segRelUsuarioAmbienteTbl { idUsuario } }`.
> Si cambia el contrato, actualizar `MOCK_SESSION` en los E2E de **todos** los MFE (`E2E_GUIDE_MFE.md` §10) y avisar a suite-props / catalogos-suite.

---

## 4. Ejecución local

| Script | Uso |
|---|---|
| `yarn start` | `:8080`, integrado con container-suite en `:9000` (ruta `/login`) |
| `yarn start:standalone` | Standalone con mocks `public/standalone-mocks/` (utilities y team-utilities) |
| `yarn build` | `dist/` |
| `yarn test` / `coverage` | Jest |
| `yarn test:e2e:mocked` | Playwright sin smoke |
| `yarn test:e2e:smoke` / `:ui` / `:debug` | Smoke real, UI, debug (`HEADED=true`) |
| `yarn lint` | `eslint src --ext js` (⚠️ no revisa `.jsx`) |

### Variables de entorno (`.env`, plantilla `.env.example`, inyectadas en build con dotenv-webpack → rebuild para cambiarlas)
| Variable | Uso |
|---|---|
| `URL_BASE_API` | Backend de autenticación |
| `ID_APLICACION` | ID de app (CI: 73) |
| `ID_AMBIENTE` | dev 4 · pre 2 · prod 1 |
| `ID_ORIGEN` | Origen (1) |
| `E2E_USERNAME`, `E2E_PASSWORD` | Smoke tests (`.env.e2e`, gitignoreado) |

---

## 5. Testing

### Unit (Jest)
- `rootDir: src`, jsdom; mocks por alias de `@it-strategy/utilities`, `@it-strategy/team-utilities`, `axios`, CSS e imágenes.
- Tests junto al código (`*.test.js(x)`). Patrón: `renderHook` con `Provider` (`configureStore`) + `MemoryRouter`; `jest.mock` de `react-router-dom` (`useNavigate`), `authRequest`, `utils`.
- Referencias: `useSelectOperation.test.js`, `SelectOperation.test.jsx`, `Login.test.jsx`.

### E2E (Playwright)
- `baseURL` = container de **development desplegado** (no localhost). Para probar cambios locales, cambiar `baseURL` en `playwright.config.js`.
- `playwright.mocked.config.js` hereda y excluye `smoke.spec.js`.
- Helpers `e2e/helpers.js`: `mockLoginApi`, `mockOperationsApi`, `mockTipoOperacionApi`, `fillLoginForm`, `setMockSession` (`addInitScript` sobre `sessionStorage.auth_session`), `MOCK_JWT`, `MOCK_OPERATIONS`.
- Specs mockeados con `page.route('**/authentication/...')`: `login`, `forgot-password`, `select-operation`, `change-project`. Los `describe` llevan el ID del ticket/criterio (LHW-xx, CTO-xx…).
- `smoke.spec.js`: login real con `.env.e2e`.
- Otros MFE inyectan sesión para sus E2E siguiendo `E2E_GUIDE_MFE.md`.

---

## 6. CI/CD

`test → build → docker-build → deploy → e2e` (`.gitlab-ci.yml`):
- `test-js` en todas las ramas (node 20, `yarn test --ci --coverage`); `build-js` solo en feature.
- `docker-build` (development/preproduction/master): `gcloud builds submit` con `_URL_BASE_API`, `_ID_APLICACION=73`, `_ID_AMBIENTE`, `_ID_ORIGEN=1`, `_SERVICE_NAME=mf-auth-front-<rama>`.
- Cloud Run `mf-auth-front-{development,preproduction,master}`, `us-central1`, puerto 80.
- `e2e-mocked` y `e2e-smoke` solo en development tras el deploy (imagen `mcr.microsoft.com/playwright:v1.61.1-jammy`).
- Flujo: `feature/*` → `development` → `preproduction` → `master` (qa eliminado).
- nginx `default.conf`: CORS `*` en GET (necesario para que el container cargue el bundle cross-origin).

---

## 7. Convenciones

- Estilo (`code-style.md`): comillas simples, sin `;`, 2 espacios, componentes `const` arrow con destructuring, early return, async/await, constantes con nombre, lógica en hooks. Prohibido `var`, mutaciones, `console.log`, componentes > ~150 líneas. (No hay `.prettierrc`: no reformatear archivos legacy en masa.)
- Estilos con clases Tailwind `k-*` (`k-primary`, `k-secondary`, `k-accent`, `k-dark`, `k-light`); no HEX en `styles.css` ni `custom-pink`/`custom-green` en código nuevo (ver `/kontrolia-theme`).
- Commits (`commits.md`): `tipo(scope): descripción` imperativo, ≤ 72 caracteres (`feat|fix|test|refactor|chore|docs`), atómicos, tests en commit aparte, sin "y" en el mensaje. **Sin `Co-Authored-By: Claude`** (regla del repo, prevalece).
- Agentes del repo: `.claude/agents/code-reviewer.md` (solo lectura) y `refactor-agent.md` (plan + confirmación).

## 8. Gotchas

1. **Credenciales E2E en texto plano** en `.gitlab-ci.yml` (`.e2e_base.variables`) y en `E2E_GUIDE_MFE.md`: no copiarlas; deben moverse a variables masked/protegidas y rotarse.
2. Nombre distinto según contexto: `@it-strategy/auth` (import map) vs `auth-suite` (webpack/package).
3. `catch {}` vacío en `AuthAction` (error de red sin mensaje); `AuthOTP` asume `e.response.data`; `GenerateCode` envía `usuario: ''` si se escribió un correo.
4. `console.log` en `authActions.js`; `setOperation` del slice recibe el action completo; `preselectedOption` sin uso.
5. Sin refresh token: el JWT solo se decodifica en el cliente; la sesión muere al cerrar la pestaña.
6. `storeTheme.setTheme/initTheme` en `useSelectOperation` son no-op (tema estático).
7. `useAuthSteps` navega a `'../dashboard'` (relativo) y `applyOperation` a `'/dashboard'`.
8. `Dockerfile` instala sin lockfile; `Dockerfile.dev` usa node 16 (CI usa 20).
9. `public/service-worker.js` cachea con clave fija `v1` sin invalidación.
10. `playwright.config.js` usa `dotenv` sin declararlo en `package.json`.

## 9. Checklist de MR

- [ ] Contrato `auth_session` sin cambios (o MFE consumidores y mocks E2E actualizados)
- [ ] Sesión vía `saveSession`/`clearSession` + `storeUser`; sin storage directo nuevo
- [ ] Errores del backend mapeados a mensajes en español; sin `catch {}` vacío
- [ ] Código nuevo en `pages/<pagina>/{components,hooks}`; sin `console.log`
- [ ] Colores con clases `k-*`
- [ ] `yarn test` y `yarn test:e2e:mocked` en verde
- [ ] Sin credenciales en código, CI ni docs
