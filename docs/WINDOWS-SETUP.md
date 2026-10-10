# CampusFix — Windows Setup Guide (for complete beginners)

This guide takes a brand-new Windows machine and gets it to the point where you can
**run the CampusFix apps and all the tests**. No prior Flutter/Dart experience assumed —
every tool, every click, every command is spelled out.

> **Est. time:** 60–90 minutes (most of it is downloads/installs that run on their own).

---

## 0. Read this first — what you can and can't run on Windows

CampusFix is a **Flutter** project with two apps and two shared packages:

| Part | What it is | How you run it on Windows |
|------|------------|---------------------------|
| `apps/admin` | The **admin web portal** | ✅ **Google Chrome** (`flutter run -d chrome`) |
| `apps/mobile` | The **mobile app** (reporter / maintenance / verifier) | ✅ **Android emulator** (via Android Studio) |
| `packages/campusfix_core` | Pure-Dart models + logic | ✅ runs as tests |
| `packages/campusfix_design` | The shared UI design system | ✅ runs as tests |

> ⚠️ **iOS cannot run on Windows.** Apple's iOS Simulator and iOS builds require a Mac with
> Xcode. On Windows you use the **Android emulator** for the mobile app and **Chrome** for the
> admin app. This is a hard Apple limitation, not a project limitation — everything else works
> fully on Windows.

**No data leaves your machine.** This is a Phase-1 prototype: all data is in-memory seed data,
there is no database, no cloud, no Firebase, no login to any external account. Running it touches
nothing but your own PC.

---

## 1. System requirements

- **Windows 10 (64-bit, version 2004 / build 19041 or newer) or Windows 11**
- **8 GB RAM minimum** — 16 GB strongly recommended if you'll run the Android emulator
- **~20 GB free disk space** (Flutter + Android Studio + one emulator image add up)
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

**Option A — a shared zip file** (most likely for this prototype)
1. Unzip the `campusfix` folder to a **short path with no spaces**, e.g. `C:\dev\campusfix`.
2. Keep the folder structure exactly as-is — the apps reference the packages by relative path
   (`..\..\packages\...`), so `apps\` and `packages\` must stay siblings.

**Option B — clone from a git repository** (if you're given a repo URL)
```powershell
cd C:\dev
git clone <repository-url> campusfix
```

> 📌 **Note:** the current CampusFix repo is **local-only (no remote yet)**. Ask the project owner
> (Ram) for a **zip** of the `campusfix` folder, or for a git URL once one exists.

---

## 5. Install the project's dependencies

CampusFix is a small monorepo with **no workspace tool**, so you fetch dependencies in **each of the
four folders once**. (Dependencies aren't included in the project files — they're downloaded here.)

Open a terminal and run these **one line at a time** (in PowerShell 5.1, `&&` chaining isn't supported,
so run each line on its own):

```powershell
cd C:\dev\campusfix\packages\campusfix_core
dart pub get

cd ..\campusfix_design
flutter pub get

cd ..\..\apps\mobile
flutter pub get

cd ..\admin
flutter pub get
```

> `campusfix_core` is **pure Dart**, so it uses `dart pub get` / `dart test`. The other three are
> Flutter, so they use `flutter pub get` / `flutter test`.

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

✅ You should see **all tests pass** (over **1,400** tests total across the four). If so — you're done
setting up. 🎉

---

## 7. Run the apps

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

### Handy while an app is running (in the terminal)

- `r` — **hot reload** (apply code changes instantly)
- `R` — **hot restart** (full restart, resets in-memory data to the seed)
- `q` — **quit**

---

## 8. Troubleshooting

<details open>
<summary><b>`'flutter' is not recognized as a command`</b></summary>

PATH isn't set, or you're in an old terminal.
- Re-check **Step 4.3** (the `C:\src\flutter\bin` entry).
- **Close and reopen** the terminal — PATH changes only apply to new windows.
- Test: `where flutter` should print the path.
</details>

<details>
<summary><b>`flutter doctor` says Android licenses not accepted</b></summary>

```powershell
flutter doctor --android-licenses
```
Press `y` until all are accepted. If it can't find the SDK, open Android Studio once (Step 5).
</details>

<details>
<summary><b>`cmdline-tools component is missing`</b></summary>

Android Studio → **SDK Manager** → **SDK Tools** tab → tick **Android SDK Command-line Tools
(latest)** → **Apply**. Then re-run `flutter doctor`.
</details>

<details>
<summary><b>"Building with plugins requires symlink support" / plugin errors</b></summary>

Developer Mode is off. Do **Step 1a** (Developer settings → Developer Mode → On), then retry.
</details>

<details>
<summary><b>The emulator won't start, is very slow, or mentions HAXM / Hypervisor</b></summary>

Virtualization isn't enabled. Do **Step 1b**: turn on **Virtual Machine Platform** +
**Windows Hypervisor Platform** in Windows features, and enable **VT-x / AMD-V (SVM)** in your
BIOS/UEFI. Reboot and try again. On AMD CPUs, the emulator uses **WHPX** (Windows Hypervisor
Platform) — make sure that feature is ticked.
</details>

<details>
<summary><b>`Unable to locate Android SDK`</b></summary>

Launch Android Studio at least once so it installs the SDK. If it's installed elsewhere, set the path:
`flutter config --android-sdk "C:\Users\<you>\AppData\Local\Android\Sdk"`.
</details>

<details>
<summary><b>`No devices found` when running the mobile app</b></summary>

Start the emulator first (Step 6), then `flutter devices` should list it. For the admin app, make sure
**Chrome** is installed and use `flutter run -d chrome`.
</details>

<details>
<summary><b>`Because campusfix_mobile depends on campusfix_core ... which doesn't exist` (path errors)</b></summary>

The folder structure was broken, or you skipped `pub get`. The `apps\` and `packages\` folders must
sit **side by side** under `campusfix\`. Re-extract keeping the structure, then redo **Section 5**.
</details>

<details>
<summary><b>`The current Dart SDK version is X. ... requires SDK version ^3.11.1`</b></summary>

Your Flutter is too old. Run `flutter channel stable` then `flutter upgrade`, and re-check
`flutter --version` (Dart must be ≥ 3.11.1).
</details>

<details>
<summary><b>`Cannot find Chrome` / `CHROME_EXECUTABLE`</b></summary>

Install Chrome (Step 3). If it's installed in a custom location, set the env var
`CHROME_EXECUTABLE` to the full path of `chrome.exe`, then reopen the terminal.
</details>

<details>
<summary><b>The first Android build hangs on "Running Gradle task..."</b></summary>

The first build **downloads Gradle and dependencies** — it can take several minutes. Let it finish;
you need internet. Behind a **corporate proxy/VPN**, set `HTTP_PROXY` / `HTTPS_PROXY` and consider a
`gradle.properties` proxy entry.
</details>

<details>
<summary><b>`pub get` is slow or fails behind a proxy/firewall</b></summary>

Set proxy variables in the terminal before running, e.g.:
```powershell
$env:HTTP_PROXY="http://user:pass@proxy:port"
$env:HTTPS_PROXY=$env:HTTP_PROXY
```
Allow `dart.exe`, `adb.exe` and `flutter` through Windows Firewall if prompted.
</details>

<details>
<summary><b>Weird long-path or "file name too long" errors</b></summary>

Keep the project at a short path like `C:\dev\campusfix` (not deep under `Documents\...`). Optionally
enable Windows long paths: `Win` → "Edit group policy" → *Computer Config → Admin Templates → System →
Filesystem → Enable Win32 long paths*.
</details>

<details>
<summary><b>Antivirus makes builds/`pub get` crawl</b></summary>

Real-time scanning on the SDK/project folders slows things a lot. Consider adding exclusions for
`C:\src\flutter`, `C:\dev\campusfix`, and `%LOCALAPPDATA%\Pub\Cache` in Windows Security.
</details>

<details>
<summary><b>Git warns about `LF will be replaced by CRLF`</b></summary>

Harmless. If you want to silence it: `git config --global core.autocrlf true`.
</details>

---

## 9. Where to get help

- **Project docs:** [README.md](../README.md), [WALKTHROUGH.md](WALKTHROUGH.md),
  [BUILDING.md](BUILDING.md), and [CLAUDE.md](../CLAUDE.md)
- When asking for help, always paste the output of **`flutter doctor -v`** — it tells a maintainer
  almost everything about your setup.
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

**One-time setup, in order**
1. Developer Mode on · virtualization on
2. Git · Chrome · Flutter (PATH) · Android Studio (SDK + emulator + licenses) · VS Code (+Flutter ext)
3. `flutter doctor -v` → all green (Xcode line excepted)
4. Get project → `pub get` in all 4 folders → run tests

**Run commands**
```powershell
# Admin web portal
cd C:\dev\campusfix\apps\admin
flutter run -d chrome

# Mobile app (start the Android emulator first)
cd C:\dev\campusfix\apps\mobile
flutter run
```
