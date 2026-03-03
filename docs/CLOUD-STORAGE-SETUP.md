# ☁️ Cloud Storage Setup — Dropbox & Google Drive

Esta guía explica cómo configurar **Dropbox** y **Google Drive** como destinos de subida para el pipeline de procesamiento de video. Los archivos `.mp4` procesados se suben directamente a una carpeta en tu cuenta de la nube usando [rclone](https://rclone.org/).

---

## Tabla de Contenidos

1. [Resumen](#resumen)
2. [Requisitos previos](#requisitos-previos)
3. [Obtener el token de Dropbox](#obtener-el-token-de-dropbox)
4. [Obtener el token de Google Drive](#obtener-el-token-de-google-drive)
5. [Agregar los secrets en GitHub](#agregar-los-secrets-en-github)
6. [Ejecutar el workflow](#ejecutar-el-workflow)
7. [Solución de problemas](#solución-de-problemas)

---

## Resumen

El workflow soporta tres destinos de subida (puedes habilitar cualquier combinación):

| Destino | Input del Workflow | Secret requerido |
|---------|-------------------|-----------------|
| **GitHub Releases** | `upload_github_release` (default: ✅) | `GITHUB_TOKEN` (automático) |
| **Dropbox** | `upload_dropbox` | `RCLONE_DROPBOX_TOKEN` |
| **Google Drive** | `upload_gdrive` | `RCLONE_GDRIVE_TOKEN` |

Los archivos se suben como `.mp4` individuales en una subcarpeta con timestamp:
```
<cloud_folder>/<YYYYMMDD-HHMMSS>/
├── video1.mp4
├── video2.mp4
└── ...
```

---

## Requisitos previos

- Una computadora con acceso a internet (para generar los tokens, solo se necesita una vez)
- Cuenta de Dropbox (para subir a Dropbox)
- Cuenta de Google (para subir a Google Drive)
- Acceso de administrador al repositorio de GitHub (para agregar los secrets)

---

## Obtener el token de Dropbox

### Paso 1 — Instalar rclone en tu computadora

Solo necesitas instalar rclone **una vez** en tu máquina local para generar el token. Después de obtenerlo, puedes desinstalar rclone si quieres.

**En macOS:**
```bash
brew install rclone
```

**En Linux:**
```bash
sudo apt install rclone
```
o
```bash
curl https://rclone.org/install.sh | sudo bash
```

**En Windows:**
1. Ve a https://rclone.org/downloads/
2. Descarga el archivo `.zip` para Windows
3. Extrae el contenido
4. Abre una terminal (CMD o PowerShell) en esa carpeta

### Paso 2 — Ejecutar el comando de autorización

Abre una terminal y ejecuta:

```bash
rclone authorize "dropbox"
```

### Paso 3 — Autorizar en el navegador

Después de ejecutar el comando anterior, rclone hará lo siguiente:

1. **Se abre tu navegador automáticamente** con la página de login de Dropbox
2. **Inicia sesión** en tu cuenta de Dropbox (si no lo estás ya)
3. Dropbox te mostrará un mensaje pidiendo permiso: **"rclone quiere acceder a tu Dropbox"**
4. **Haz clic en "Permitir"** (o "Allow")

### Paso 4 — Copiar el token de la terminal

Después de hacer clic en "Permitir", **regresa a tu terminal**. Verás algo como esto:

```
If your browser doesn't open automatically go to the following link: http://127.0.0.1:53682/auth?state=xxxxx
Log in and authorize rclone for access
Waiting for code...
Got code
Paste the following into your remote machine -->
{"access_token":"sl.B0xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","token_type":"bearer","refresh_token":"xxxxxxxxxxxxxxx","expiry":"2026-03-03T11:25:05.857Z"}
<---End paste
```

> ⚠️ **IMPORTANTE:** Copia **TODO** el texto JSON que aparece entre las flechas `-->` y `<---End paste`. Es una sola línea que empieza con `{` y termina con `}`.

El token se ve así (es una sola línea):
```json
{"access_token":"sl.B0xxxxx...","token_type":"bearer","refresh_token":"xxxxx...","expiry":"2026-03-03T11:25:05.857Z"}
```

### Paso 5 — Guardar como secret en GitHub

Guarda este token JSON como el secret **`RCLONE_DROPBOX_TOKEN`** en tu repositorio (ver [Agregar los secrets en GitHub](#agregar-los-secrets-en-github)).

---

## Obtener el token de Google Drive

Tienes dos opciones para obtener el token de Google Drive. La **Opción A** es más rápida, la **Opción B** te da un Client ID propio (recomendado si tienes muchos archivos).

### Opción A — Método rápido (usa el Client ID de rclone)

#### Paso 1 — Ejecutar rclone config

Abre una terminal y ejecuta:

```bash
rclone config
```

Verás un menú. Escribe `n` para crear un nuevo remote y presiona Enter:

```
No remotes found, make a new one?
n) New remote
s) Set configuration password
q) Quit config
n/s/q> n
```

#### Paso 2 — Configurar el remote

Sigue las instrucciones escribiendo exactamente lo que se indica:

```
Enter name for new remote.
name> gdrive
```

Después selecciona el tipo de almacenamiento. Busca **Google Drive** en la lista (generalmente es la opción `drive` o un número como `18`):

```
Storage> drive
```

Cuando te pregunte por Client ID y Client Secret, **déjalos en blanco** (solo presiona Enter):

```
Google Application Client Id - leave blank normally.
client_id>
Google Application Client Secret - leave blank normally.
client_secret>
```

Selecciona el scope de acceso completo (opción `1`):

```
Scope that rclone should use when requesting access from drive.
Choose a number from below, or type in your own value.
 1 / Full access all files, excluding Application Data Folder.
   \ (drive)
 2 / Read-only access to file metadata and file contents.
   \ (drive.readonly)
   ...
scope> 1
```

Para las siguientes preguntas, presiona Enter para dejar todo por defecto:

```
service_account_file>          (presiona Enter, déjalo en blanco)
Edit advanced config?
y) Yes
n) No (default)
y/n> n
```

#### Paso 3 — Autorizar en el navegador

Cuando te pregunte si quieres usar auto config, di que sí:

```
Use auto config?
y) Yes (default)
n) No
y/n> y
```

Se abrirá tu navegador automáticamente:

1. **Selecciona tu cuenta de Google**
2. Si ves un mensaje de "Esta app no está verificada", haz clic en **"Avanzado"** → **"Ir a rclone (no seguro)"**
3. **Haz clic en "Permitir"** para dar acceso a Google Drive
4. Haz clic en **"Permitir"** de nuevo para confirmar

Después de autorizar, regresa a la terminal. Verás:

```
Got code
Configure this as a Shared Drive (Team Drive)?
y) Yes
n) No (default)
y/n> n
```

Escribe `n` y presiona Enter. Luego confirma la configuración:

```
Configuration complete.
Keep this "gdrive" remote?
y) Yes this is OK (default)
e) Edit this remote
d) Delete this remote
y/e/d> y
```

Escribe `q` para salir:
```
q) Quit config
e/n/d/r/c/s/q> q
```

#### Paso 4 — Extraer el token

Ahora necesitas obtener el token JSON que rclone guardó. Ejecuta este comando:

```bash
cat ~/.config/rclone/rclone.conf
```

Verás algo como esto:

```ini
[gdrive]
type = drive
scope = drive
token = {"access_token":"ya29.a0ARW5m7xxxxxxxxx","token_type":"Bearer","refresh_token":"1//0exxxxxxxxxxxxxxx","expiry":"2026-03-03T12:25:05.857123Z"}
```

> ⚠️ **IMPORTANTE:** Copia **SOLO** el valor de `token =` — es decir, todo el JSON que empieza con `{` y termina con `}`. **NO** copies el `token = ` del inicio.

El token se ve así (es una sola línea):
```json
{"access_token":"ya29.a0ARW5m7xxxxxxxxx","token_type":"Bearer","refresh_token":"1//0exxxxxxxxxxxxxxx","expiry":"2026-03-03T12:25:05.857123Z"}
```

**Comando alternativo** para extraer solo el token directamente:
```bash
rclone config dump | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['gdrive']['token'])"
```

#### Paso 5 — Guardar como secret en GitHub

Guarda este token JSON como el secret **`RCLONE_GDRIVE_TOKEN`** en tu repositorio (ver [Agregar los secrets en GitHub](#agregar-los-secrets-en-github)).

---

### Opción B — Con Client ID propio (más control)

Este método crea tu propia "app" de Google, lo que te da límites de API más altos y más control.

#### Paso 1 — Crear un proyecto en Google Cloud

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Haz clic en el menú de proyectos (arriba a la izquierda) → **"Nuevo proyecto"**
3. Nombre: `rclone-videos` (o el que quieras) → **Crear**
4. Selecciona el proyecto que acabas de crear

#### Paso 2 — Habilitar la API de Google Drive

1. En el menú lateral: **APIs & Services** → **Library**
2. Busca **"Google Drive API"**
3. Haz clic en **"Enable"** (Habilitar)

#### Paso 3 — Configurar la pantalla de consentimiento

1. Ve a **APIs & Services** → **OAuth consent screen**
2. Selecciona **"External"** → **"Create"**
3. Llena solo los campos obligatorios:
   - App name: `rclone-videos`
   - User support email: tu email
   - Developer contact: tu email
4. Haz clic en **"Save and Continue"** en las siguientes pantallas
5. En la página "Test users", haz clic en **"Add users"** y agrega tu propio email de Google
6. Haz clic en **"Save and Continue"** → **"Back to Dashboard"**

#### Paso 4 — Crear credenciales OAuth

1. Ve a **APIs & Services** → **Credentials**
2. Haz clic en **"+ Create Credentials"** → **"OAuth client ID"**
3. Application type: **"Desktop app"**
4. Nombre: `rclone`
5. Haz clic en **"Create"**
6. Aparece una ventana con tu **Client ID** y **Client Secret** — **cópialos**

> Tu Client ID se ve como: `123456789-xxxxxxxxxx.apps.googleusercontent.com`
> Tu Client Secret se ve como: `GOCSPX-xxxxxxxxxxxxxxxxxx`

#### Paso 5 — Configurar rclone con tu Client ID

Sigue los mismos pasos de la [Opción A](#paso-1--ejecutar-rclone-config), pero cuando te pregunte por el Client ID y Client Secret, **escribe los tuyos**:

```
client_id> 123456789-xxxxxxxxxx.apps.googleusercontent.com
client_secret> GOCSPX-xxxxxxxxxxxxxxxxxx
```

El resto de los pasos es igual que en la Opción A (pasos 3, 4 y 5).

---

## Agregar los secrets en GitHub

### Paso 1 — Ir a Settings del repositorio

1. Ve a tu repositorio en GitHub: `https://github.com/Uaemextop/realsuperlandiaxxx-online-11`
2. Haz clic en la pestaña **"Settings"** (⚙️ Configuración)

### Paso 2 — Navegar a Secrets

1. En el menú lateral izquierdo, haz clic en **"Secrets and variables"**
2. Luego haz clic en **"Actions"**

### Paso 3 — Crear el secret para Dropbox

1. Haz clic en el botón verde **"New repository secret"**
2. En **Name**, escribe exactamente: `RCLONE_DROPBOX_TOKEN`
3. En **Secret**, pega el token JSON completo que copiaste de la terminal (el que empieza con `{` y termina con `}`)
4. Haz clic en **"Add secret"**

### Paso 4 — Crear el secret para Google Drive

1. Haz clic en **"New repository secret"** de nuevo
2. En **Name**, escribe exactamente: `RCLONE_GDRIVE_TOKEN`
3. En **Secret**, pega el token JSON completo de Google Drive
4. Haz clic en **"Add secret"**

> ⚠️ **Seguridad:** Los tokens solo se usan durante la ejecución del workflow. El archivo de configuración de rclone se elimina inmediatamente después de subir los archivos. Los tokens nunca se muestran en los logs ni se guardan en el repositorio.

---

## Ejecutar el workflow

1. Ve a la pestaña **"Actions"** en tu repositorio
2. Haz clic en **"Process Videos"** en el menú lateral
3. Haz clic en el botón **"Run workflow"**
4. Configura las opciones de subida:

| Input | Descripción | Default |
|-------|------------|---------|
| **Upload to GitHub Releases** | Crear un GitHub Release con archivos zip | `true` |
| **Upload to Dropbox** | Subir archivos `.mp4` a Dropbox | `false` |
| **Upload to Google Drive** | Subir archivos `.mp4` a Google Drive | `false` |
| **Folder name in Dropbox/Google Drive** | Nombre de la carpeta destino | `ProcessedVideos` |

5. Haz clic en **"Run workflow"**

### Ejemplo: Subir solo a Dropbox

- ☑️ Upload to Dropbox: `true`
- ☐ Upload to GitHub Releases: `false`
- Folder: `MisVideos`

Los archivos aparecerán en Dropbox en: `/MisVideos/20260303-100530/`

### Ejemplo: Subir a Google Drive y GitHub Releases

- ☑️ Upload to GitHub Releases: `true`
- ☑️ Upload to Google Drive: `true`
- Folder: `ProcessedVideos`

### Ejemplo: Subir a los tres destinos

- ☑️ Upload to GitHub Releases: `true`
- ☑️ Upload to Dropbox: `true`
- ☑️ Upload to Google Drive: `true`
- Folder: `VideosProcesados`

---

## Solución de problemas

### Token expirado

Los tokens de rclone incluyen un `refresh_token` que se renueva automáticamente. Si las subidas fallan con errores de autenticación, regenera el token:

```bash
# Para Dropbox — ejecuta de nuevo:
rclone authorize "dropbox"

# Para Google Drive — ejecuta:
rclone config reconnect gdrive:
```

Después actualiza el secret correspondiente en GitHub.

### Error "Secret is not set"

Si ves este warning en los logs del workflow:
```
Dropbox upload selected but RCLONE_DROPBOX_TOKEN secret is not set — skipping
```

Verifica que:
1. El nombre del secret sea **exactamente** `RCLONE_DROPBOX_TOKEN` o `RCLONE_GDRIVE_TOKEN` (sin espacios extra)
2. El valor del secret sea el JSON completo (empieza con `{` y termina con `}`)
3. El secret esté en **Repository secrets**, no en Environment secrets

### "Esta app no está verificada" (Google Drive)

Cuando autorizas Google Drive, puede aparecer una advertencia diciendo que la app no está verificada. Esto es normal:
1. Haz clic en **"Avanzado"** (o "Advanced")
2. Haz clic en **"Ir a rclone (no seguro)"** (o "Go to rclone (unsafe)")
3. Haz clic en **"Permitir"**

### La subida es muy lenta

El workflow usa 8 transferencias en paralelo por defecto. Los proveedores de nube tienen límites de velocidad de API. Verifica tu cuota si las subidas fallan a mitad del proceso.

### Cuota de almacenamiento de Google Drive

Las cuentas gratuitas de Google tienen 15 GB de almacenamiento. Para lotes grandes de video, considera usar Google Workspace con más almacenamiento.

### Cuota de almacenamiento de Dropbox

Las cuentas gratuitas de Dropbox tienen 2 GB de almacenamiento. Dropbox Plus ofrece 2 TB. Asegúrate de tener espacio suficiente para todos los videos procesados.
