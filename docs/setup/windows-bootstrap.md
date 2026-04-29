# Windows Bootstrap Baseline

Last updated: April 29, 2026

This is the implemented Sprint 0 Windows path that was executed and verified on the current workstation. Commands prefer `.cmd` or `.bat` entrypoints where PowerShell execution policy would otherwise block the default shims.

## Installed and verified

- Git for Windows `2.54.0`
- Node.js LTS `24.15.0`
- npm `11.12.1`
- `pnpm` `10.0.0` at the repo layer
- Firebase CLI `15.15.0`
- Puro `1.5.0`
- Flutter stable `3.41.8`
- Android Studio `2025.3.4.6`

## Bootstrap sequence

### 1. Install the winget-managed tools

```powershell
winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements --disable-interactivity
winget install --id OpenJS.NodeJS.LTS --exact --accept-package-agreements --accept-source-agreements --disable-interactivity
winget install --id pingbird.Puro --exact --accept-package-agreements --accept-source-agreements --disable-interactivity
winget install --id Google.AndroidStudio --exact --accept-package-agreements --accept-source-agreements --disable-interactivity
```

### 2. Install the Node-based global CLIs

```powershell
npm.cmd install --global pnpm@10.0.0
npm.cmd install --global firebase-tools
```

### 3. Install Flutter through Puro

```powershell
puro create stable 3.41.8
puro use stable --global
```

The active Flutter binary on this machine is:

```powershell
C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat
```

### 4. Finish repo dependencies

```powershell
pnpm.cmd install
python -m pip install -e .[dev]
```

Run the Python install from `tools/pdf_parser/`.

## Verification commands

### Machine-level

```powershell
git --version
node --version
npm.cmd --version
pnpm.cmd --version
firebase.cmd --version
C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat --version
C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat doctor
python --version
```

### Repo-level

```powershell
pnpm.cmd run check
pnpm.cmd --dir backend/worker-api exec wrangler --version
pnpm.cmd --dir backend/worker-admin exec wrangler --version
python -m ruff check tools/pdf_parser
python -m pytest tools/pdf_parser
cd mobile\app
C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat pub get
C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat analyze
C:\Users\PC\.puro\envs\stable\flutter\bin\flutter.bat test
```

## Remaining manual step

`flutter doctor` still reports the Android SDK as missing. Android Studio is installed, but the first launch still needs to complete SDK setup and license acceptance before Android builds are clean.
