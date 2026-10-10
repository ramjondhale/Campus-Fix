# CampusFix — Windows Setup Guide (for complete beginners)

This guide takes a brand-new Windows machine and gets it to the point where you can
**run the CampusFix apps and all the tests**. No prior Flutter/Dart experience assumed —
every tool, every click, every command is spelled out.

> **Est. time:** 60–90 minutes (most of it is downloads/installs that run on their own).
> The optional Firebase emulator section (Section 8) adds about 20 minutes.

> 🌐 **Just want to look at it first?** There is a **live hosted demo** — nothing to install:
> **<https://campus-fix-a8e09.web.app>** (the admin web console). Sign in as `ADM-01` or `VER-01`
> with the password `campusfix-demo`. Come back to this guide when you want to run it yourself.

---

## 0. Read this first — what you can and can't run on Windows

CampusFix is a **Flutter** project with two apps, three shared packages and a Firebase `backend/` folder:

| Part | What it is | How you run it on Windows |
|------|------------|---------------------------|
| `apps/admin` | The **admin web portal** | ✅ **Google Chrome** (`flutter run -d chrome`) |
| `apps/mobile` | The **mobile app** (reporter / maintenance / verifier) | ✅ **Android emulator** (via Android Studio) |
| `packages/campusfix_core` | Pure-Dart models + logic (+ mock data) | ✅ runs as tests |
| `packages/campusfix_design` | The shared UI design system | ✅ runs as tests |
| `packages/campusfix_firebase` | **Firebase backend implementation** (Phase 2 MVP) — used by the apps' Firebase entrypoint | ✅ fetched with `pub get`; only exercised in Firebase mode |
| `backend/` | **Firebase config**, Security Rules, Firestore indexes and the seed script | ✅ optional — used only by the [emulator section](#8-advanced-optional-run-against-the-firebase-emulator) |

> ⚠️ **iOS cannot run on Windows.** Apple's iOS Simulator and iOS builds require a Mac with
> Xcode. On Windows you use the **Android emulator** for the mobile app and **Chrome** for the
> admin app. This is a hard Apple limitation, not a project limitation — everything else works
> fully on Windows.

### Two ways to run each app (two entrypoints)

Since the Firebase backend (Phase 2 MVP) was added, **each app has two entrypoints**:

| Entrypoint | Mode | Needs | When to use it |
|------------|------|-------|----------------|
| `lib/main.dart` | **Mock / offline** — in-memory seed data (29 complaints, 25 users) | Nothing extra | ✅ **The simplest way to see it run, and the recommended first run.** This is what plain `flutter run` uses. |
| `lib/main_firebase.dart` | **Firebase** — Firebase Auth + Firestore | The Firebase emulator (Section 8) or a real Firebase project | Advanced / optional. |

**Do Sections 1–7 first (mock mode).** Only do Section 8 if you specifically want to try the Firebase
backend locally.

**Where does your data go?**
- **Mock mode (Sections 1–7)** is fully local: all data is in-memory seed data, there is no database,
  no cloud and no login to any external account. Running it touches nothing but your own PC.
- **Firebase emulator mode (Section 8)** is also local: the Firebase *emulators* run on your PC
  (`demo-*` project ids never touch a real Firebase project) and need **no Firebase account**.
- The **live hosted demo** above runs on a real (free-tier) Firebase project with demo data only — you
  don't need it, or any Firebase account, for anything in this guide.

---

## 1. System requirements

- **Windows 10 (64-bit, version 2004 / build 19041 or newer) or Windows 11**
- **8 GB RAM minimum** — 16 GB strongly recommended if you'll run the Android emulator
- **~20 GB free disk space** (Flutter + Android Studio + one emulator image add up; the optional
  Firebase emulator tools add a few hundred MB more)
- An **administrator** account on the PC
- A **stable internet connection** (the first Android build downloads a lot)
- **Hardware virtualization enabled** (needed for a fast Android emulator — see Step 1b)

---

## 2. What we'll install (the shopping list)

You'll install these, in this order. Don't worry about what each one is yet — the steps explain it.

1. **Git for Windows** — downloads/updates the project and is used by Flutter
2. **Google Chrome** — runs the admin web app
3. **Flutter SDK 3.41.x** — the framework (it bundles **Dart**, so you don't install Dart separately)
4. **Android Studio** — gives you the Android SDK **and** the phone emulator
5. **Visual Studio Code** (recommended editor) + the **Flutter** extension

**Optional — only for the Firebase emulator (Section 8):**

6. **Node.js 18 or newer** (LTS) — runs the Firebase CLI and the seed script
7. **A JDK (Java)** — the Firestore emulator is a Java program, so it needs Java installed
8. **firebase-tools** — the Firebase command-line tool (installed with `npm`)

---

## 3. Step-by-step installation

### Step 1a — Turn on Windows Developer Mode (required)

Flutter needs **symlink support**, which Developer Mode enables.

1. Press `Win` → type **"Developer settings"** → open it.
2. Turn **Developer Mode** → **On**. (Accept the prompt.)

### Step 1b — Enable virtualization (for the Android emulator)

The emulator is painfully slow without it.

1. In Windows: press `Win` → type **"Turn Windows features on or off"** → open it.
2. Tick **Virtual Machine Platform** and **Windows Hypervisor Platform** → **OK** → reboot if asked.
3. If the emulator still complains later, virtualization may be **off in your BIOS/UEFI**. Reboot,
   enter BIOS (usually `F2`/`F10`/`Del` at startup), and enable **Intel VT-x** or **AMD-V / SVM**.

### Step 2 — Install Git for Windows

1. Go to **https://git-scm.com/download/win** → the download starts automatically.
2. Run the installer. **Accept all the defaults** (just keep clicking *Next* → *Install*).
3. Verify: open **a new** `PowerShell` or `Command Prompt` window and run:

   ```powershell
   git --version
   ```

   You should see something like `git version 2.4x.x`.

### Step 3 — Install Google Chrome

1. Get it from **https://www.google.com/chrome/** and install it (defaults are fine).
2. This is what the **admin web app** opens in. If you already have Chrome, skip this.

### Step 4 — Install the Flutter SDK

1. Go to **https://docs.flutter.dev/get-started/install/windows** and download the **Flutter SDK
   (stable) zip**.
2. **Extract it to `C:\src\flutter`.**
   - Create `C:\src` first if needed.
   - ❌ Do **not** put it in `C:\Program Files` (needs admin rights) or any path **with spaces**.
3. Add Flutter to your **PATH** so the `flutter` command works everywhere:
   1. Press `Win` → type **"environment variables"** → open **"Edit the system environment variables"**.
   2. Click **Environment Variables…**
   3. Under **User variables**, select **Path** → **Edit** → **New** → paste:
      ```
      C:\src\flutter\bin
      ```
   4. **OK** out of all three dialogs.
4. **Close every terminal window and open a new one** (PATH changes only apply to new terminals), then:

   ```powershell
   flutter --version
   ```

   ✅ You need **Flutter 3.41.x** with **Dart 3.11.1 or newer**. If it shows an older Dart, run:

   ```powershell
   flutter channel stable
   flutter upgrade
   ```

### Step 5 — Install Android Studio (Android SDK + emulator)

Even if you prefer VS Code for editing, you still need Android Studio for the **Android SDK** and
the **emulator**.

1. Download from **https://developer.android.com/studio** and run the installer (defaults are fine —
   this installs the Android SDK, platform-tools, and the emulator).
2. Launch Android Studio once and let the **Setup Wizard** finish downloading components.
3. Open **More Actions → SDK Manager** (or *Settings → Languages & Frameworks → Android SDK*) and make
   sure these are ticked/installed:
   - **Android SDK Platform** (the latest, e.g. Android 15 / API 35)
   - **Android SDK Command-line Tools (latest)**  ← easy to miss, Flutter needs it
   - **Android SDK Build-Tools**
   - **Android Emulator**
   - **Android SDK Platform-Tools**
4. **Accept the Android licenses** from a terminal:

   ```powershell
   flutter doctor --android-licenses
   ```

   Press `y` at each prompt until it says all accepted.

### Step 6 — Create an Android emulator (a virtual phone)

1. In Android Studio open **More Actions → Virtual Device Manager**.
2. **Create Device** → pick e.g. **Pixel 7** → **Next**.
3. Choose a **system image** (e.g. API 35, "Google Play", `x86_64`). Click the download icon if it
   isn't downloaded yet → **Next** → **Finish**.
4. Press the ▶ **Play** button to boot the virtual phone once, to confirm it works.

### Step 7 — Install VS Code + the Flutter extension (recommended editor)

1. Install **Visual Studio Code** from **https://code.visualstudio.com/**.
2. Open VS Code → **Extensions** (the squares icon, or `Ctrl+Shift+X`) → search **"Flutter"** →
   install the one by **Dart Code** (it auto-installs the Dart extension too).

### Step 8 — Run the doctor

`flutter doctor` checks your whole setup. Run:

```powershell
flutter doctor -v
```

You want **check marks** for:
- ✅ Flutter
- ✅ Android toolchain (if it complains about licenses, re-run `flutter doctor --android-licenses`)
- ✅ Chrome
- ✅ VS Code (or Android Studio)

> ℹ️ A ❌ on the **"Xcode – develop for iOS"** line is **expected and fine on Windows** — you don't
> need it. Ignore it.

---

## 4. Get the CampusFix project onto your PC

The project lives in a folder called `campusfix`. Get it one of two ways:

**Option A — clone from GitHub** (recommended)
```powershell
cd C:\dev
git clone https://github.com/ramjondhale/Campus-Fix.git campusfix
```
(The trailing `campusfix` renames the folder so the paths in this guide match. Create `C:\dev` first
if it doesn't exist.)

**Option B — a shared zip file**
1. Unzip the `campusfix` folder to a **short path with no spaces**, e.g. `C:\dev\campusfix`.
2. Keep the folder structure exactly as-is — the apps reference the packages by relative path
   (`..\..\packages\...`), so `apps\`, `packages\` and `backend\` must stay siblings.

> 📌 **Note:** the repository is at **https://github.com/ramjondhale/Campus-Fix**. If it is ever private
> and the clone asks you to sign in, ask the project owner (Ram) for access, or for a **zip** of the
> `campusfix` folder.

---

## 5. Install the project's dependencies

CampusFix is a small monorepo with **no workspace tool**, so you fetch dependencies in **each of the
five folders once**. (Dependencies aren't included in the project files — they're downloaded here.)
The apps now depend on the new `campusfix_firebase` package, so it needs its own `pub get` too.

Open a terminal and run these **one line at a time** (in PowerShell 5.1, `&&` chaining isn't supported,
so run each line on its own):

```powershell
cd C:\dev\campusfix\packages\campusfix_core
dart pub get

cd ..\campusfix_design
flutter pub get

cd ..\campusfix_firebase
flutter pub get

cd ..\..\apps\mobile
flutter pub get

cd ..\admin
flutter pub get
```

> `campusfix_core` is **pure Dart**, so it uses `dart pub get` / `dart test`. The other four are
> Flutter, so they use `flutter pub get` / `flutter test`. (The `backend\` folder is not a Dart
> project — its one dependency step is `npm install`, and only in Section 8.)

---

## 6. Verify everything works — run the tests

If the tests pass, your environment is correct. Run each (one line at a time):

```powershell
cd C:\dev\campusfix\packages\campusfix_core
dart test

cd ..\campusfix_design
flutter test

cd ..\..\apps\mobile
flutter test

cd ..\admin
flutter test
```

✅ You should see **all tests pass** (about **1,400+** tests total across the four suites: core 651,
design 232, mobile 199, admin 344). If so — you're done setting up. 🎉

---

## 7. Run the apps

These steps use the **mock / offline entrypoint** (`lib/main.dart`) — plain `flutter run` picks it by
default. No backend, no accounts. (To run against Firebase instead, see
[Section 8](#8-advanced-optional-run-against-the-firebase-emulator).)

### 7a. Admin web portal (in Chrome)

```powershell
cd C:\dev\campusfix\apps\admin
flutter run -d chrome
```

- A Chrome window opens with the admin portal.
- On the login screen, click the **Admin** demo button (fills in `ADM-01`), then **Sign in**.
- Demo password (if asked): `campusfix-demo`.
- You'll land on the dashboard. See [WALKTHROUGH.md](WALKTHROUGH.md) for a guided tour.

### 7b. Mobile app (on the Android emulator)

1. Start your emulator (Android Studio → **Virtual Device Manager** → ▶), **or** let the next command
   offer it.
2. Run:

   ```powershell
   cd C:\dev\campusfix\apps\mobile
   flutter run
   ```

3. If asked which device, pick the **emulator** (e.g. *sdk gphone64 ...*).
4. Log in with a demo account (reporter / maintenance / verifier) — see [WALKTHROUGH.md](WALKTHROUGH.md).

> The **mobile app does not run in a web browser** (it has no `web/` folder) — use the Android
> emulator. And again: **iOS is Mac-only**.

### 7c. Easier: run from VS Code

1. **File → Open Folder** → open `apps\admin` (or `apps\mobile`).
2. Bottom-right status bar: click the **device name** → choose **Chrome** (admin) or your **emulator**
   (mobile).
3. Press **F5** (Run → Start Debugging). Use the toolbar to **hot reload** (⚡) as you edit.

VS Code runs `lib/main.dart` (mock mode) by default.

### Handy while an app is running (in the terminal)

- `r` — **hot reload** (apply code changes instantly)
- `R` — **hot restart** (full restart, resets in-memory data to the seed)
- `q` — **quit**

---

## 8. Advanced (optional): run against the Firebase emulator

> **You can skip this whole section.** Mock mode (Sections 1–7) is the easiest way to see CampusFix
> work. Do this only if you want to try the **Firebase backend (Phase 2 MVP)** on your own PC:
> real Auth sign-in, Firestore data and the Security Rules — all running locally in the **Firebase
> Emulator Suite**, with **no Firebase account and no cloud project**.

This section only covers *getting it running on Windows*. The full backend runbook (rules, indexes,
the dev project, deploying to Hosting) lives in the
[backend README](https://github.com/ramjondhale/Campus-Fix/blob/main/backend/README.md) — this guide
doesn't duplicate it.

### 8a. Install the extra tools

You need **Node.js**, a **JDK (Java)** and the **Firebase CLI**. The JDK is the one people forget — the
**Firestore emulator is a Java program and will not start without Java**.

1. **Node.js 18 or newer (LTS).** Either download the LTS installer from **https://nodejs.org/** (defaults
   are fine), or in PowerShell:

   ```powershell
   winget install OpenJS.NodeJS.LTS
   ```

2. **A JDK.** Install the Microsoft build of OpenJDK:

   ```powershell
   winget install Microsoft.OpenJDK.21
   ```

   Newer versions of the Firebase CLI require **Java 21 or newer** for the Firestore emulator; older
   ones accepted **Java 17** (`winget install Microsoft.OpenJDK.17`). If in doubt, install **21** — it
   works with both. (No `winget`? Download a JDK from https://learn.microsoft.com/java/openjdk/download.)

3. **Close every terminal and open a new one** (so the new tools are on your PATH), then install the
   Firebase CLI and verify everything:

   ```powershell
   npm install -g firebase-tools

   node --version
   npm --version
   java -version
   firebase --version
   ```

   ✅ Each command should print a version. `node` should be **v18 or newer**.

> You do **not** need to run `firebase login`. The emulators work without any account. (Only the real
> dev project needs a login — see the backend README before ever running `firebase login`.)

### 8b. Start the emulators

Open a terminal, start the emulators from the `backend` folder, and **leave this window running**:

```powershell
cd C:\dev\campusfix\backend
firebase emulators:start --project demo-campusfix
```

- The `demo-` prefix in the project id is what guarantees it never touches a real Firebase project.
- The first start **downloads the Firestore emulator** (a one-time download). If **Windows Firewall**
  asks about **Java**, click **Allow access** (private networks are enough).
- When it's ready, open the **Emulator UI** at **http://localhost:4000** to see Auth and Firestore.
- Ports used: Auth `9099`, Firestore `8080`, Storage `9199`, Hosting `5000`, UI `4000`.

### 8c. Generate and load the seed data

Open a **second terminal** (the emulators keep running in the first). This turns the project's built-in
seed data (25 users, 29 complaints, notifications) into a JSON file, then loads it into the emulators.

**Generate `seed.json`:**

```powershell
cd C:\dev\campusfix\packages\campusfix_core
dart run tool/export_seed.dart --out ..\..\backend\seed\seed.json
```

> ⚠️ **Use `--out`, not `>`.** Windows PowerShell 5.1's `>` redirect saves the file as **UTF-16**, which
> the seed script can't read. `--out` writes plain UTF-8.

**Install the seeder's dependency (first time only), then load the data:**

```powershell
cd C:\dev\campusfix\backend\seed
npm install

$env:FIRESTORE_EMULATOR_HOST = "localhost:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099"
$env:FIREBASE_PROJECT_ID = "demo-campusfix"
$env:ALIAS_DOMAIN = "id.campusfix.test"
node seed.mjs
```

- The `$env:...` lines set variables **for this PowerShell window only** (they're gone when you close
  it). They point the script at the local emulators instead of a real project.
- The seeder is **safe to re-run**. It creates the Auth users (the same demo IDs, password
  `campusfix-demo`) and all the Firestore data.
- To check the seed file without touching any emulator, run `node seed.mjs --dry-run`.
- The emulators keep data **in memory**: if you stop and restart them, run the seed step again.

### 8d. Run the apps against the emulator

Use the **Firebase entrypoint** (`-t lib/main_firebase.dart`) and tell it to use the emulator
(`--dart-define=CF_USE_EMULATOR=true`):

```powershell
# Admin web portal (Chrome)
cd C:\dev\campusfix\apps\admin
flutter run -d chrome -t lib/main_firebase.dart --dart-define=CF_USE_EMULATOR=true

# Mobile app (Android emulator) — in another terminal
cd C:\dev\campusfix\apps\mobile
flutter run -t lib/main_firebase.dart --dart-define=CF_USE_EMULATOR=true
```

- Sign in with the same **demo accounts** as before (e.g. `ADM-01` / `campusfix-demo`).
- The Android emulator reaches your PC at `10.0.2.2`; the app picks that automatically. On a
  **physical** Android phone, also pass `--dart-define=CF_EMULATOR_HOST=<your PC's LAN IP>`.
- In Firebase mode the admin portal and the mobile app read the **same** Firestore, unlike mock mode
  where each has its own private in-memory store. The read path is live; the write path is still
  landing (Phase 2, milestone C3), so some actions may be incomplete depending on the version you have.
- Stop the emulators with `Ctrl+C` in the first terminal.

### 8e. Where to go next

Rules, indexes, the dev project, and deploying the admin web to Firebase Hosting are all in the
**[backend README](https://github.com/ramjondhale/Campus-Fix/blob/main/backend/README.md)** and the
[Phase 2 MVP plan](phase-2-mvp.md).

---

## 9. Troubleshooting

<details markdown="1" open>
<summary><b><code>'flutter' is not recognized as a command</code></b></summary>

PATH isn't set, or you're in an old terminal.
- Re-check **Step 4.3** (the `C:\src\flutter\bin` entry).
- **Close and reopen** the terminal — PATH changes only apply to new windows.
- Test: `where flutter` should print the path.
</details>

<details markdown="1">
<summary><b><code>flutter doctor</code> says Android licenses not accepted</b></summary>

```powershell
flutter doctor --android-licenses
```
Press `y` until all are accepted. If it can't find the SDK, open Android Studio once (Step 5).
</details>

<details markdown="1">
<summary><b><code>cmdline-tools component is missing</code></b></summary>

Android Studio → **SDK Manager** → **SDK Tools** tab → tick **Android SDK Command-line Tools
(latest)** → **Apply**. Then re-run `flutter doctor`.
</details>

<details markdown="1">
<summary><b>"Building with plugins requires symlink support" / plugin errors</b></summary>

Developer Mode is off. Do **Step 1a** (Developer settings → Developer Mode → On), then retry.
</details>

<details markdown="1">
<summary><b>The emulator won't start, is very slow, or mentions HAXM / Hypervisor</b></summary>

Virtualization isn't enabled. Do **Step 1b**: turn on **Virtual Machine Platform** +
**Windows Hypervisor Platform** in Windows features, and enable **VT-x / AMD-V (SVM)** in your
BIOS/UEFI. Reboot and try again. On AMD CPUs, the emulator uses **WHPX** (Windows Hypervisor
Platform) — make sure that feature is ticked.
</details>

<details markdown="1">
<summary><b><code>Unable to locate Android SDK</code></b></summary>

Launch Android Studio at least once so it installs the SDK. If it's installed elsewhere, set the path:
`flutter config --android-sdk "C:\Users\<you>\AppData\Local\Android\Sdk"`.
</details>

<details markdown="1">
<summary><b><code>No devices found</code> when running the mobile app</b></summary>

Start the emulator first (Step 6), then `flutter devices` should list it. For the admin app, make sure
**Chrome** is installed and use `flutter run -d chrome`.
</details>

<details markdown="1">
<summary><b><code>Because campusfix_mobile depends on campusfix_core ... which doesn't exist</code> (path errors)</b></summary>

The folder structure was broken, or you skipped `pub get`. The `apps\`, `packages\` and `backend\`
folders must sit **side by side** under `campusfix\`. Re-extract keeping the structure, then redo
**Section 5**. (The same error mentioning `campusfix_firebase` means that package folder is missing
or its `pub get` was skipped.)
</details>

<details markdown="1">
<summary><b><code>The current Dart SDK version is X. ... requires SDK version ^3.11.1</code></b></summary>

Your Flutter is too old. Run `flutter channel stable` then `flutter upgrade`, and re-check
`flutter --version` (Dart must be ≥ 3.11.1).
</details>

<details markdown="1">
<summary><b><code>Cannot find Chrome</code> / <code>CHROME_EXECUTABLE</code></b></summary>

Install Chrome (Step 3). If it's installed in a custom location, set the env var
`CHROME_EXECUTABLE` to the full path of `chrome.exe`, then reopen the terminal.
</details>

<details markdown="1">
<summary><b>The first Android build hangs on "Running Gradle task..."</b></summary>

The first build **downloads Gradle and dependencies** — it can take several minutes. Let it finish;
you need internet. Behind a **corporate proxy/VPN**, set `HTTP_PROXY` / `HTTPS_PROXY` and consider a
`gradle.properties` proxy entry.
</details>

<details markdown="1">
<summary><b><code>pub get</code> is slow or fails behind a proxy/firewall</b></summary>

Set proxy variables in the terminal before running, e.g.:
```powershell
$env:HTTP_PROXY="http://user:pass@proxy:port"
$env:HTTPS_PROXY=$env:HTTP_PROXY
```
Allow `dart.exe`, `adb.exe` and `flutter` through Windows Firewall if prompted.
</details>

<details markdown="1">
<summary><b>Weird long-path or "file name too long" errors</b></summary>

Keep the project at a short path like `C:\dev\campusfix` (not deep under `Documents\...`). Optionally
enable Windows long paths: `Win` → "Edit group policy" → *Computer Config → Admin Templates → System →
Filesystem → Enable Win32 long paths*.
</details>

<details markdown="1">
<summary><b>Antivirus makes builds/<code>pub get</code> crawl</b></summary>

Real-time scanning on the SDK/project folders slows things a lot. Consider adding exclusions for
`C:\src\flutter`, `C:\dev\campusfix`, and `%LOCALAPPDATA%\Pub\Cache` in Windows Security.
</details>

<details markdown="1">
<summary><b>Git warns about <code>LF will be replaced by CRLF</code></b></summary>

Harmless. If you want to silence it: `git config --global core.autocrlf true`.
</details>

**Firebase emulator (Section 8) only:**

<details markdown="1">
<summary><b><code>'node'</code> / <code>'npm'</code> / <code>'firebase'</code> is not recognized</b></summary>

The tool isn't on your PATH yet, or you're in an old terminal.
- **Close and reopen** the terminal after installing Node.js (PATH changes only apply to new windows).
- Test: `where node`, `where npm`, `where firebase` should each print a path.
- `node` works but `firebase` doesn't? The global npm folder is missing from PATH. Run
  `npm config get prefix` and make sure that folder (usually `%AppData%\npm`) is in your **User
  `Path`** (same dialog as Step 4.3), then reopen the terminal. Or just re-run
  `npm install -g firebase-tools`.
</details>

<details markdown="1">
<summary><b>The emulator fails with "Java not found" / <code>Could not spawn java -version</code></b></summary>

The Firestore emulator needs **Java (a JDK)**, and it isn't installed or isn't on PATH.
- Install one: `winget install Microsoft.OpenJDK.21` (see Section 8a), then **reopen the terminal**.
- Check: `java -version` must print a version (and `where java` a path).
- If the CLI says your Java is too old (for example "requires Java 21 or higher"), install JDK **21**.
- Several JDKs installed? Make sure `JAVA_HOME` and `Path` point at the one you want.
</details>

<details markdown="1">
<summary><b>PowerShell says "running scripts is disabled on this system" (npm / firebase)</b></summary>

PowerShell is blocking the `npm.ps1` / `firebase.ps1` launcher scripts. Either run the command from
**Command Prompt** (`cmd`) instead, or allow local scripts for your user only:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```
</details>

<details markdown="1">
<summary><b>Emulator says a port is already in use (8080, 9099, 4000, 5000 ...)</b></summary>

Another program (or an emulator you forgot to stop) holds the port. Find it with
`netstat -ano | findstr :8080`, then stop that program (or close the old emulator terminal) and start
again.
</details>

<details markdown="1">
<summary><b>Firebase-mode login fails, or the app shows no data</b></summary>

- The **emulators must be running** (Section 8b) *before* you start the app.
- You must have **loaded the seed data** (Section 8c). A fresh or restarted emulator is empty.
- The app and the seed script must agree on the alias domain — both default to `id.campusfix.test`; if
  you changed `ALIAS_DOMAIN`, also pass `--dart-define=CF_ALIAS_DOMAIN=<same value>` to the app.
- On a physical phone, pass `--dart-define=CF_EMULATOR_HOST=<your PC's LAN IP>`.
- `seed.mjs` complaining about invalid JSON? `seed.json` was probably created with `>` — regenerate it
  with `--out` (Section 8c).
</details>

---

## 10. Where to get help

- **Project docs:** [the repository README](https://github.com/ramjondhale/Campus-Fix#readme),
  [WALKTHROUGH.md](WALKTHROUGH.md), [BUILDING.md](BUILDING.md),
  [ARCHITECTURE.md](ARCHITECTURE.md), the
  [backend README](https://github.com/ramjondhale/Campus-Fix/blob/main/backend/README.md) (Firebase), and
  [CLAUDE.md](https://github.com/ramjondhale/Campus-Fix/blob/main/CLAUDE.md)
- When asking for help, always paste the output of **`flutter doctor -v`** — it tells a maintainer
  almost everything about your setup. For Firebase issues, add `node --version`, `java -version` and
  `firebase --version`.
- Flutter's official Windows guide: https://docs.flutter.dev/get-started/install/windows

---

## Appendix — quick reference

**Versions**

| Tool | Version |
|------|---------|
| Flutter | **3.41.x** (stable) |
| Dart | **≥ 3.11.1** (ships with Flutter) |
| Android | API 34/35 emulator image |
| Chrome | latest |
| *Optional (Firebase emulator):* Node.js | **18 or newer** (LTS) |
| *Optional:* JDK (Java) | **21** recommended (17 works with older firebase-tools) |
| *Optional:* firebase-tools | latest (`npm install -g firebase-tools`) |

**One-time setup, in order**
1. Developer Mode on · virtualization on
2. Git · Chrome · Flutter (PATH) · Android Studio (SDK + emulator + licenses) · VS Code (+Flutter ext)
3. `flutter doctor -v` → all green (Xcode line excepted)
4. Get project → `pub get` in all **5** folders (core, design, firebase, mobile, admin) → run tests
5. *(Optional, Firebase emulator)* Node.js + JDK + `npm i -g firebase-tools`

**Run commands (mock mode, `lib/main.dart`)**
```powershell
# Admin web portal
cd C:\dev\campusfix\apps\admin
flutter run -d chrome

# Mobile app (start the Android emulator first)
cd C:\dev\campusfix\apps\mobile
flutter run
```

**Firebase emulator mode (`lib/main_firebase.dart`) — optional**
```powershell
# Terminal 1: start the emulators (leave running)
cd C:\dev\campusfix\backend
firebase emulators:start --project demo-campusfix

# Terminal 2: generate + load the seed data (once per emulator start)
cd C:\dev\campusfix\packages\campusfix_core
dart run tool/export_seed.dart --out ..\..\backend\seed\seed.json
cd ..\..\backend\seed
npm install
$env:FIRESTORE_EMULATOR_HOST = "localhost:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099"
$env:FIREBASE_PROJECT_ID = "demo-campusfix"
$env:ALIAS_DOMAIN = "id.campusfix.test"
node seed.mjs

# Terminal 3: run an app against the emulator
cd C:\dev\campusfix\apps\admin
flutter run -d chrome -t lib/main_firebase.dart --dart-define=CF_USE_EMULATOR=true
```
