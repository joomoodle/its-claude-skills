---
name: kontrolia-theme
description: Tema Kontrolia (Brand Guide Oct 2025) en los micro-frontends de IT Strategy — paleta, tokens semánticos vs legacy, gradiente, tipografía Manrope, cómo se inyecta (styled-components, Tailwind, Alert/Toast) cómo consumir colores sin hardcodear HEX y cómo definir el tema local en proyectos que NO tienen @it-strategy/utilities (apps Vite/standalone, CSS/SCSS, Tailwind, MUI). Usar al escribir o revisar estilos, colores, fondos, bordes, gradientes o fuentes en auth-front, catalogos-suite, suite-props, ui-shared o cualquier MFE de la suite.
---
# Skill: kontrolia-theme
Trigger: `/kontrolia-theme`

Guía de uso del tema Kontrolia (colores, gradiente, tipografía) en los micro-frontends de la suite. Al invocarse, antes de escribir cualquier estilo: usar tokens del tema, nunca HEX de la paleta.

- Fuente de verdad: `suite-props/src/interface/ITheme.ts` → `defaultTheme` (paquete `@it-strategy/utilities`)
- Guía extendida: `suite-props/.claude/GUIA_TEMA_COLORES.md` (copia en `catalogos-suite/.claude/rules/GUIA_TEMA_COLORES.md`, con rutas `Interface/`/`Hooks/` desactualizadas)
- Componentes UI que ya aplican el tema: skill `/ui-kit`

---

## 0. Reglas de oro

1. **El tema es estático.** No viene de API ni cambia en runtime. `storeTheme.setTheme()` e `initTheme()` son **no-op intencionales**; no llamarlos para cambiar colores.
2. **Nunca hardcodear un HEX de la paleta** (`#0c6478`, `#09d1c7`, `#82ee99`, `#424f55`, `#EFEFEF`, `#FFFFFF`). Usar el token.
3. **Código nuevo → tokens semánticos** (`primary`, `secondary`, `dark`…). En archivos existentes, respetar la nomenclatura que ya usa el archivo. **No mezclar legacy y semánticos en el mismo componente.**
4. **No crear** constantes locales de color, CSS variables sueltas ni paletas paralelas. Si falta un token, se agrega en `ITheme.ts` (§8). Única excepción: proyectos **sin** `@it-strategy/utilities`, que tienen **un solo** archivo de tema local, copia fiel de `ITheme.ts` (§2.4).
5. **Primero detectar** si el proyecto tiene `@it-strategy/utilities` (§2.4): de eso depende de dónde sale el tema.
6. No usar colores fuera del Brand Guide sin justificación (azules MUI `#1976d2`, `#007bff`, índigos, el teal antiguo `#00B3B0`, `custom-pink`…).

---

## 1. Paleta oficial

Solo hay **6 colores**; los tokens semánticos son alias de los legacy.

| Token semántico | Token legacy | HEX | Uso |
|---|---|---|---|
| `primary` | `primaryColor` | `#0c6478` | Teal oscuro. Botones primarios / CTA, íconos, texto de marca, bordes de card |
| `secondary` | `secondColor` | `#09d1c7` | Cyan. Bordes de tabla, inputs activos, checks, separadores, acentos |
| `accent` | — | `#82ee99` | Verde del logo. Éxito, confirmación |
| `dark` | `primaryFontColor` | `#424f55` | Texto de cuerpo |
| `light` | `secondBackgroundColor` | `#EFEFEF` | Fondos secundarios, hover |
| `white` | `primaryBackgroundColor` | `#FFFFFF` | Fondo principal |

Alias adicionales (mismo valor):

| Token | = | Uso |
|---|---|---|
| `success` | `accent` `#82ee99` | Estados de éxito |
| `info` | `secondary` `#09d1c7` | Información |
| `textPrimary` / `textBody` | `dark` `#424f55` | Texto |
| `textSecondary` | `primary` `#0c6478` | Texto con énfasis de marca |
| `background` | `white` `#FFFFFF` | Fondo de página |
| `surface` | `light` `#EFEFEF` | Cards, paneles, sidebars, filas alternas |
| `mapPinStore` / `mapPinRecord` | `#09d1c7` / `#0c6478` | Pines de mapa |
| `linetable` | `#09d1c7` | Línea de tabla (legacy teams) |

Otros tokens:

| Token | Valor |
|---|---|
| `gradients.primary` | `linear-gradient(180deg, #82ee99 19.23%, #0c6478 84.94%)` |
| `fontFamily` | `Manrope, sans-serif` |
| `fontSize` | `14px` (único token tipográfico) |
| `isKontrolia` | `true` |
| Legacy de layout (teams) | `margintoptable`, `bordericon`, `iconSize`, `tableOverFlow`, `marginswithLeft`, `visibility`, `icon` |

**No existen tokens** de error/warning/danger, grises intermedios, espaciado, breakpoints, sombras ni radios (ver §6).

### Equivalencias legacy ↔ semántico
```
primaryColor            ↔ primary
secondColor             ↔ secondary
primaryFontColor        ↔ dark / textPrimary / textBody
primaryBackgroundColor  ↔ white / background
secondBackgroundColor   ↔ light / surface
```

---

## 2. Cómo llega el tema a cada proyecto

| Proyecto | Mecanismo | Código |
|---|---|---|
| **suite-props** (`@it-strategy/utilities`) | `ThemeProvider` con `defaultTheme` + `GlobalStyle` (solo `font-family`). Tipado vía `src/styled.d.ts` (`DefaultTheme extends ITheme`) | `src/root.component.tsx` |
| **catalogos-suite** | Se suscribe a `storeTheme.storeTheme$` y lo pasa a `ThemeProvider` | `src/root.component.js` |
| **auth-front** | **No usa styled-components.** Tailwind con colores `k-*` en `tailwind.config.js` + clases CSS en `src/styles.css` | `tailwind.config.js` |
| **ui-shared** (`@it-strategy/ui-kit`) | Solo consume `theme` del `ThemeProvider` del consumidor. `Alert`/`Toast` usan su paleta propia (`src/utils/alertTheme.ts`) salvo `configureAlerts(theme)` | `src/styled.d.ts`, `src/utils/alertTheme.ts` |
| **MUI** | **Ningún proyecto tiene `createTheme`.** Componentes MUI sin envolver usan el azul por defecto `#1976d2` → preferir componentes de ui-kit o pasar colores del tema vía `sx` | — |

### 2.1 styled-components (suite-props, catalogos-suite, nuevos MFE)

```tsx
// suite-props (TS)
import { ThemeProvider } from 'styled-components'
import { defaultTheme } from './interface/ITheme'
<ThemeProvider theme={defaultTheme}><GlobalStyle /><AppShell /></ThemeProvider>
```

```jsx
// catalogos-suite (JS) — tema desde el store compartido
const [theme, setTheme] = useState({})
useEffect(() => {
  const sub = storeTheme.storeTheme$.subscribe(setTheme)
  return () => sub.unsubscribe()
}, [])
<ThemeProvider theme={theme}>…</ThemeProvider>
```

> ⚠️ En un MFE externo, `defaultTheme` **no se exporta en runtime** desde `@it-strategy/utilities` (el entry solo exporta stores/componentes; la ruta `@it-strategy/utilities/interface/ITheme` que muestra la guía no funciona vía SystemJS). Obtener el tema con `storeTheme.storeTheme$` (o `storeTheme.getSnapshot()`) como hace catalogos-suite. Los tipos se declaran con un `.d.ts` local.

### 2.2 Tailwind (auth-front)

```js
// tailwind.config.js
colors: {
  'k-primary': '#0c6478', 'k-secondary': '#09d1c7', 'k-accent': '#82ee99',
  'k-dark': '#424f55', 'k-light': '#EFEFEF',
  'custom-pink': '#f45cec', 'custom-green': '#00B3B0', // ❌ fuera de marca, no usar en código nuevo
}
```
Usar `text-k-primary`, `bg-k-primary`, `border-k-secondary`, `text-k-dark`, `bg-k-light`. No usar `custom-*` ni escribir HEX en `styles.css`.

### 2.3 Alert / Toast

- ui-kit: `configureAlerts(theme)` una vez al iniciar para que `Alert`/`Toast` tomen los colores del tema (por defecto ya usan Kontrolia).
- catalogos-suite usa todavía su `src/utils/Alert.js` local (lee `storeTheme`; el botón cancelar usa `primaryColor` mientras ui-kit usa `dark`). Al migrar, reemplazar por `Alert` de ui-kit (requiere ui-kit 2.x).

### 2.4 Proyectos SIN `@it-strategy/utilities` (sin props)

No todos los proyectos corren dentro del container single-spa ni tienen `@it-strategy/utilities` (p. ej. apps Vite independientes como `front-expedientes-cliente`, PWAs, apps standalone). En esos proyectos **no existe `storeTheme`** ni `defaultTheme`: el tema se define **localmente** como copia fiel de la fuente de verdad.

**Detectar** si el proyecto tiene utilities:
```bash
grep -rln "@it-strategy/utilities" src | head        # sin resultados → no tiene props
grep -n "@it-strategy/utilities" webpack.config.* 2>/dev/null
grep -n "<nombre-del-mfe>" ../container-suite/src/index.ejs   # ¿está en el import map?
```

**Reglas para estos proyectos:**
- Un **único** archivo de tema: `src/theme/kontrolia.ts` (o `.js`). Es copia de `suite-props/src/interface/ITheme.ts` → mismos nombres de token y mismos valores. No inventar nombres (`brandColor`, `mainColor`…) ni subconjuntos con otros nombres.
- Encabezado obligatorio en el archivo: `// Copia de suite-props/src/interface/ITheme.ts — mantener sincronizado`.
- **No** importar `storeTheme`, `defaultTheme` ni nada de `@it-strategy/utilities` (rompe en runtime: el módulo no existe).
- Todo el proyecto consume colores de ese archivo (o de lo que se genere desde él: CSS vars, Tailwind, SCSS). Ningún HEX de la paleta fuera de él.

#### Opción A — styled-components (recomendada si usa `@it-strategy/ui-kit`)
```ts
// src/theme/kontrolia.ts
// Copia de suite-props/src/interface/ITheme.ts — mantener sincronizado
export const kontroliaTheme = {
  fontFamily: 'Manrope, sans-serif',
  fontSize: '14px',
  // legacy (los usa ui-kit)
  primaryColor: '#0c6478', secondColor: '#09d1c7', primaryFontColor: '#424f55',
  primaryBackgroundColor: '#FFFFFF', secondBackgroundColor: '#EFEFEF',
  // semánticos
  primary: '#0c6478', secondary: '#09d1c7', accent: '#82ee99', dark: '#424f55',
  light: '#EFEFEF', white: '#FFFFFF', background: '#FFFFFF', surface: '#EFEFEF',
  textPrimary: '#424f55', textSecondary: '#0c6478', textBody: '#424f55',
  success: '#82ee99', info: '#09d1c7',
  gradients: { primary: 'linear-gradient(180deg, #82ee99 19.23%, #0c6478 84.94%)' },
  isKontrolia: true,
} as const
export type KontroliaTheme = typeof kontroliaTheme
```
```ts
// src/styled.d.ts
import 'styled-components'
import type { KontroliaTheme } from './theme/kontrolia'
declare module 'styled-components' { export interface DefaultTheme extends KontroliaTheme {} }
```
```tsx
// root / main.tsx
import { ThemeProvider } from 'styled-components'
import { configureAlerts } from '@it-strategy/ui-kit'   // solo si usa ui-kit ≥ 2
import { kontroliaTheme } from './theme/kontrolia'

configureAlerts(kontroliaTheme)
<ThemeProvider theme={kontroliaTheme}><App /></ThemeProvider>
```
> Con ui-kit, incluir **también los tokens legacy**: varios componentes de la librería leen `primaryColor`, `secondColor`, `primaryFontColor`.

#### Opción B — CSS / SCSS (sin styled-components)
Generar variables CSS una sola vez y usarlas en todo el proyecto:
```scss
// src/styles/_kontrolia.scss — Copia de suite-props/src/interface/ITheme.ts — mantener sincronizado
:root {
  --k-primary: #0c6478;  --k-secondary: #09d1c7; --k-accent: #82ee99;
  --k-dark: #424f55;     --k-light: #EFEFEF;     --k-white: #FFFFFF;
  --k-gradient-primary: linear-gradient(180deg, #82ee99 19.23%, #0c6478 84.94%);
  --k-font-family: 'Manrope', sans-serif;
}
```
```scss
.card { background: var(--k-light); border: 1px solid var(--k-secondary); color: var(--k-dark); }
.title { color: var(--k-primary); font-family: var(--k-font-family); }
// transparencias: color-mix(in srgb, var(--k-primary) 10%, transparent)
```
Si el proyecto ya tiene `_variables.scss`, definir ahí `$k-primary: var(--k-primary);` etc. en vez de HEX sueltos. Prefijo de variables: `--k-*` (igual que Tailwind de auth-front).

#### Opción C — Tailwind
```js
// tailwind.config.js — importar del archivo de tema, no copiar HEX
const { kontroliaTheme: t } = require('./src/theme/kontrolia')
module.exports = { theme: { extend: {
  colors: { 'k-primary': t.primary, 'k-secondary': t.secondary, 'k-accent': t.accent, 'k-dark': t.dark, 'k-light': t.light },
  fontFamily: { sans: ['Manrope', 'sans-serif'] },
  backgroundImage: { 'k-gradient': t.gradients.primary },
} } }
```

#### MUI sin utilities
Si el proyecto usa MUI directo, crear su tema desde el mismo archivo:
```ts
import { createTheme } from '@mui/material/styles'
import { kontroliaTheme as t } from './kontrolia'
export const muiTheme = createTheme({
  palette: { primary: { main: t.primary }, secondary: { main: t.secondary }, success: { main: t.success }, text: { primary: t.dark } },
  typography: { fontFamily: t.fontFamily },
})
// <MuiThemeProvider theme={muiTheme}><ThemeProvider theme={kontroliaTheme}>…</ThemeProvider></MuiThemeProvider>
```

#### Fuente
Sin el container no hay `index.ejs` compartido: cargar Manrope en el `index.html` propio del proyecto:
```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700&display=swap" rel="stylesheet" />
```

---

## 3. Cómo consumir colores

### En styled-components
```tsx
export const Card = styled.div`
  background-color: ${({ theme }) => theme.surface};
  border: 1px solid ${({ theme }) => theme.secondary};
  color: ${({ theme }) => theme.dark};
  font-family: ${({ theme }) => theme.fontFamily};
`

export const Badge = styled.span<{ active: boolean }>`
  background-color: ${({ theme, active }) => (active ? theme.primary : theme.light)};
  color: ${({ theme, active }) => (active ? theme.white : theme.dark)};
`

export const Banner = styled.section`
  background: ${({ theme }) => theme.gradients.primary};   // ✅ no reescribir el gradiente
`
```

### Fuera de styled (props de librerías, `sx`, `style`)
```tsx
import { useTheme } from 'styled-components'          // MFE dentro de ThemeProvider
// en suite-props: import { useTheme } from '../../hooks/useTheme'
const theme = useTheme()
<Checkbox sx={{ color: theme.secondary, '&.Mui-checked': { color: theme.secondary } }} />
<Icon style={{ color: theme.primary }} />
```

### Transparencias (sufijo hex sobre el token)
```tsx
background-color: ${p => `${p.theme.primary}1A`};   // 10%
```
| 5% | 10% | 20% | 30% | 50% |
|---|---|---|---|---|
| `0D` | `1A` | `33` | `4D` | `80` |

> ⚠️ Los tokens son HEX: no envolverlos en `rgb(...)`. Bug real: `catalogos-suite/src/components/UI/button/styled.components.jsx:22` genera `rgb(#09d1c7 / 1)` (CSS inválido).

### Gradientes custom con tokens
```tsx
background: linear-gradient(90deg, ${p => p.theme.accent}, ${p => p.theme.secondary}, ${p => p.theme.primary});
```
Hoy hay 3 variantes hardcodeadas del gradiente de marca (auth-front `styles.css`, `pages/auth/index.jsx`; suite-props `header`/`menu` styled). Al tocarlas, pasar a `theme.gradients.primary` o a tokens.

### Fallbacks
Solo cuando el valor puede ser `undefined` (p. ej. componentes de ui-kit que pueden renderizarse sin `ThemeProvider`): `theme.primary ?? theme.primaryColor`. Evitar `theme.x ?? '#0c6478'` en MFEs: el `ThemeProvider` siempre está.

---

## 4. Tipografía

- Token: `theme.fontFamily` = `Manrope, sans-serif`. Usar el token, **no** escribir `'Manrope', sans-serif` a mano (hoy hay ~76 literales en suite-props).
- ⚠️ **Manrope no se carga en ningún lado**: `container-suite/src/index.ejs` carga Open Sans y Roboto; auth-front no carga fuentes (Tailwind `font-sans` por defecto). En la práctica se ve la `sans-serif` del sistema. Corrección recomendada: cargar Manrope una vez en `container-suite/src/index.ejs` (Google Fonts, `display=swap`) y en auth-front extender `fontFamily.sans: ['Manrope', ...]` + link en `public/index.html` para standalone.

---

## 5. Grises y neutros permitidos sin token

| Valor | Uso |
|---|---|
| `#f0f0f0` | Filas alternas de tabla |
| `#fcfcfc` | Filas alternas claras |
| `#a0a0a0` | Texto terciario (timestamps, metadatos) |
| `red` | Badges de error / alerta crítica |

Cualquier otro gris o color de estado necesita token (§8).

---

## 6. Deuda conocida (no replicar)

| Problema | Dónde | Qué hacer al tocar el archivo |
|---|---|---|
| HEX de la paleta hardcodeados (~300 en catalogos, ~300 en suite-props, ~40 en auth-front) | `suite-props` `components/dashboard/BannerDefault.tsx`, `components/menu/styled.components.tsx`, `widgets/w-notificaciones`; `catalogos-suite` `components/StandaloneNav`, `pages/usuarios/components/CreateUsuario`; `auth-front` `src/styles.css`, `pages/auth/index.jsx` | Reemplazar por token |
| Colores fuera de marca | `#00B3B0` (teal antiguo, auth-front `utilities/loader.js`, catalogos `regiones`), `#007bff`/`#0056b3` (catalogos `file-input`), `#4caf50`/`#f44336` (catalogos `brands-apps` Switch), índigos (catalogos `Profile/styles.password.css`) | Pasar a token equivalente |
| 5+ rojos distintos para error | `#e74c3c`, `#e53e3e`, `#e05555`, `#e53935`, `#c0392b`, `#d32f2f`, `#d30000` | Usar `red` o proponer token `error` |
| Breakpoints, radios y sombras sin escala | cada proyecto tiene la suya (Tailwind, Bootstrap, ad hoc) | Reusar los valores ya presentes en el archivo; proponer escala en `ITheme` |
| Llamadas a `storeTheme.setTheme/initTheme` | auth-front `components/Login/hooks/useSelectOperation.js` | Código muerto; no agregar más |
| Tema duplicado en mocks | `catalogos-suite/src/mockups/it-strategy-utilities.js`, `public/standalone-mocks/it-strategy-utilities.js` (sin `textBody` / `isKontrolia`) | Si se agrega un token, actualizar también los mocks |
| `ErrorBoundaryFallback` / `Alert.js` locales | catalogos-suite | Usar los de ui-kit |
| Playground de ui-shared con tema no Kontrolia (`#1976d2`) | `ui-shared/playground/main.tsx` | No tomarlo como referencia visual |
| `ui-shared/src/styled.d.ts` tipa solo 15 tokens | ui-shared | Al usar `success`/`info`/`textBody` en ui-shared, ampliar el tipo |

### Detectar deuda
```bash
# HEX de la paleta hardcodeados
grep -rnEi "#0c6478|#09d1c7|#82ee99|#424f55|#efefef" src --include=*.{js,jsx,ts,tsx,css}
# Colores fuera de marca frecuentes
grep -rnEi "#00b3b0|#1976d2|#007bff|#0056b3|#4caf50|#f44336|#6366f1|#4f46e5|#f45cec" src
# Fuente escrita a mano
grep -rn "Manrope" src | grep -v "theme.fontFamily"
# rgb() envolviendo tokens
grep -rnE "rgb\(\\\$\{" src
```

---

## 7. Ejemplos ✅ / ❌

```tsx
const Header = styled.header`
  background: ${p => p.theme.gradients.primary};   // ✅
  background: linear-gradient(135deg, #82ee99, #0c6478); // ❌
  color: ${p => p.theme.white};                     // ✅
  color: #fff;                                      // ❌
  border-bottom: 2px solid ${p => p.theme.secondary}; // ✅
  font-family: ${p => p.theme.fontFamily};          // ✅
  font-family: 'Manrope', sans-serif;               // ❌
`
```
```jsx
// auth-front (Tailwind)
<button className="bg-k-primary text-white">Entrar</button>   // ✅
<button style={{ background: '#0c6478' }}>Entrar</button>     // ❌
<span className="text-custom-green">…</span>                  // ❌ fuera de marca
```
```ts
storeTheme.setTheme({ primaryColor: 'red' })  // ❌ no-op, no tiene efecto
```

---

## 8. Si falta un token

1. Confirmar que no existe un alias (§1) que sirva.
2. Agregarlo en `suite-props/src/interface/ITheme.ts` (interfaz `ITheme` **y** `defaultTheme`). Cambio en `@it-strategy/utilities` → impacta a todos los MFE: revisar consumidores antes de publicar.
3. Actualizar los `.d.ts` locales de los MFE que lo usen, los mocks de standalone/jest (catalogos-suite) y las **copias locales** (`src/theme/kontrolia.*`, `_kontrolia.scss`) de los proyectos sin utilities (§2.4).
4. Si lo usa ui-kit: ampliar `ui-shared/src/styled.d.ts` y, si aplica, `alertTheme.ts`.
5. En auth-front: agregar la clase `k-*` correspondiente en `tailwind.config.js`.
6. Documentar en `GUIA_TEMA_COLORES.md` y en esta skill.

---

## 9. Checklist de revisión (estilos en un MR)

- [ ] Tema tomado de la fuente correcta: `storeTheme$` / `defaultTheme` si hay `@it-strategy/utilities`; si no, del **único** archivo local `src/theme/kontrolia.*` (copia fiel, con encabezado de sincronía)
- [ ] Sin HEX de la paleta Kontrolia hardcodeados (styled, `sx`, `style`, CSS, Tailwind arbitrario `bg-[#0c6478]`)
- [ ] Sin colores fuera del Brand Guide (`#00B3B0`, azules MUI, índigos, `custom-*`)
- [ ] Código nuevo con tokens semánticos; sin mezclar legacy y semánticos en el mismo componente
- [ ] Gradiente de marca vía `theme.gradients.primary`
- [ ] `font-family` vía `theme.fontFamily` (o `font-sans` configurado en Tailwind)
- [ ] Transparencias con sufijo hex sobre el token, sin `rgb(${token})`
- [ ] Sin llamadas nuevas a `storeTheme.setTheme` / `initTheme`
- [ ] Componentes MUI sin envolver reciben colores del tema (o se usa el equivalente de ui-kit)
- [ ] Si se agregó un token: `ITheme.ts` + `defaultTheme` + mocks + `.d.ts` + guía actualizados
