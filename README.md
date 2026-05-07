# BlacJack — Proyecto COBOL (Backend) + Python (Frontend)
Simulación de Blackjack con **motor de juego en COBOL** y **interfaz gráfica en Python**.

### Resumen rápido
- **Backend**: COBOL (GnuCOBOL) compila a un ejecutable (`backend/bin/blackjack_runtime.exe`) que procesa la lógica del juego.
- **Frontend**: Python (Tkinter + CustomTkinter) renderiza la UI, maneja eventos y orquesta el flujo de partida.
- **Comunicación**: archivo puente **`DATA/BRIDGE.DAT`** (registro de longitud fija) + ejecución del backend como proceso.

---

## Arquitectura del proyecto
### Árbol (jerárquico)
```text
BlacJack
├─ Frontend (Python) ── `Frontend/app.py`  (Tkinter/CustomTkinter)
│  ├─ UI + assets (cartas/fichas)
│  ├─ Escribe comando → `DATA/BRIDGE.DAT`
│  ├─ Ejecuta motor → `backend/bin/blackjack_runtime.exe`
│  └─ Lee estado ← `DATA/BRIDGE.DAT` (refresca la UI)
├─ Backend (COBOL) ──── `backend/blackjack.cob.cbl`
│  ├─ Lee comando ← `DATA/BRIDGE.DAT`
│  ├─ Calcula lógica del Blackjack
│  ├─ Persiste shoe ↔ `DATA/SHOE.DAT`
│  └─ Escribe estado → `DATA/BRIDGE.DAT`
└─ Datos (archivos) ─── `DATA/`
   ├─ `BRIDGE.DAT`  (puente/IPC por archivo, registro fijo)
   ├─ `SHOE.DAT`    (mazo/shoe)
   └─ `RANKING.TXT` (ranking local)
```

**Idea clave**: el frontend no “habla” por red; orquesta el juego escribiendo un comando en `BRIDGE.DAT`, ejecutando el `.exe` COBOL y leyendo el estado resultante del mismo archivo.

---

## Estructura de carpetas
- `backend/`: código fuente COBOL y binarios generados
  - `backend/blackjack.cob.cbl`: programa principal (entrada en `MAIN-PROCEDURE`)
  - `backend/bin/`: salida de compilación (`blackjack_runtime.exe`)
- `Frontend/`: aplicación Python (GUI) y recursos gráficos
  - `Frontend/app.py`: punto de entrada del frontend
  - `Frontend/assets/`, `Frontend/chips/`: imágenes
- `DATA/`: archivos usados durante la ejecución (se crean si no existen)
- `db/sql/`: script SQL de ranking (opcional / no requerido para ejecutar)
- `run_blackjack.ps1`: compila COBOL y arranca el frontend

---

## Requisitos
### En Windows
- **Python 3.10+** (recomendado 3.11 o 3.12).
- **GnuCOBOL** (necesario para el comando `cobc`).
  - El script `run_blackjack.ps1` intenta detectar una instalación típica en `C:\GnuCOBOL` y añade variables de entorno para esa sesión.

### Dependencias Python
Se instalan desde `requirements.txt` (incluye, entre otras, `customtkinter` y `Pillow`).

---

## Instalación y ejecución (Windows / PowerShell)
Desde la **raíz del proyecto**, ejecútalo **sí o sí** así (copy/paste):

```powershell (Ejecutar como administrador primero)
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_blackjack.ps1
```

### Notas importantes
- El script `run_blackjack.ps1` **requiere** que exista `.venv` (usa `.\.venv\Scripts\python.exe`).
- Debes tener **GnuCOBOL** instalado para que exista el comando `cobc`.
  - Si lo instalas en `C:\GnuCOBOL`, el script intentará configurarlo automáticamente para esa sesión.


### Qué crea/usa al arrancar
- Si no existe, se crea `DATA/`.
- Si no existe, se inicializa `DATA/BRIDGE.DAT` con **220 espacios**.
- Si no existe, se crea `DATA/RANKING.TXT`.

---

## Partes importantes (para entender el proyecto rápido)
### `DATA/BRIDGE.DAT` (archivo puente)
- Es el “contrato” entre frontend y backend.
- El frontend escribe un comando y el backend devuelve un estado actualizado.
- Si quieres depurar, este es el primer sitio para inspeccionar cuando “la UI no refleja cambios”.

### `backend/blackjack.cob.cbl` (motor del juego)
- Punto de entrada: `MAIN-PROCEDURE`.
- Maneja lectura/escritura del estado (bridge) y del shoe (`DATA/SHOE.DAT`).

### `Frontend/app.py` (UI)
- Punto de entrada: `if __name__ == "__main__": ...`
- Ejecuta el backend como proceso y refresca la UI leyendo el puente.

---

## Troubleshooting
### “No se puede cargar .ps1 porque la ejecución de scripts está deshabilitada”
Usa:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_blackjack.ps1
```

### “CMD abre el Bloc de notas al abrir el .ps1”
En CMD llama a PowerShell explícitamente:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File run_blackjack.ps1
```

### “cobc no se reconoce como un comando…"
- Instala GnuCOBOL o añade su `bin` al `PATH`.
- Verifica con:

```powershell
cobc -V
```

---

## Licencia (educativa)
Este proyecto se distribuye bajo una **licencia educativa de uso no comercial**. Lee el archivo `LICENSE` para ver los términos completos =D.
