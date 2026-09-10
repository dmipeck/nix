---
name: nix-flake-devshell-flutter
description: >-
  Build or fix a Nix flake-parts devShell for a Flutter/Android app — pinning
  nixpkgs' flutterPackages to a specific version, composing an androidenv
  Android SDK, wiring a writable Flutter SDK overlay for Gradle 9
  includeBuild, JAVA_HOME/ANDROID_SDK_ROOT/PUB_CACHE, and proving the result
  with a real headless-emulator build-and-run. Use when the user says
  "flutter devshell", "nix flake for flutter", "flutter android nix",
  "flake-parts flutter", "flutter nix shell", "nix develop flutter build fails",
  "Gradle projectDir not writable", or asks to reproduce/pin a Flutter+Android
  toolchain with Nix so `flutter build apk` and `flutter test` work inside
  `nix develop`. Also use when troubleshooting devShell-surfaced
  Gradle/AGP/Kotlin/NDK/SDK-component errors that show up only when building a
  Flutter app from inside a Nix shell.
---

# Flutter + Android Nix devShell (flake-parts)

Build a reproducible `nix develop` shell that runs a Flutter/Android project's
full toolchain — Flutter SDK, JDK, Android SDK/NDK/emulator — pinned via Nix
instead of relying on host-installed Android Studio/SDK managers.

## 1. Decide: pin to the app's existing versions, or track latest Flutter

This is the single most important judgment call in the whole procedure. Ask
the user which they want (unless they already stated a preference) before
writing any Nix code. Do not silently modernize app files.

**Option A — pin nixpkgs to match the repo's EXISTING toolchain exactly.**
Zero app-file changes. Devshell tooling stays on an older nixpkgs snapshot.
When an SDK component or tool version is missing, fix the **devShell**; only
touch `pubspec` / `android/` when the app's own pins can't match any available
toolchain.

**Option B — use nixpkgs' latest `flutter` / `flutterPackages.stable`.**
Current tooling, but very likely forces a cascade of app-file version bumps
(pubspec `environment.sdk`, Gradle, AGP, Kotlin, per-plugin
compileSdk/JVM-target overrides) to satisfy the newer Flutter's Gradle plugin.

Before asking, read the app's current pins so the question is concrete:

```bash
grep -A2 '^environment:' pubspec.yaml
cat android/gradle/wrapper/gradle-wrapper.properties
grep -E 'kotlin_version|com.android.application|compileSdk' \
  android/settings.gradle android/build.gradle
```

Present the fork to the user, e.g.: "This app is pinned to Flutter/Dart via
pubspec `sdk: ^3.5.0`, Gradle 8.x, AGP 8.x. I can (A) pin the devShell's nixpkgs
to match that exactly — no app changes — or (B) use latest Flutter in the
devShell, which will likely require bumping pubspec/Gradle/AGP/Kotlin and
possibly per-plugin overrides. Which do you want?" Do not silently pick one.

**General principle:** when a build gap is a missing SDK component or tool
version, fix the DEVSHELL (`flake.nix`), not the app. Only touch app files
(`pubspec.yaml`/`.lock`, `android/` Gradle files) when the app's own declared
constraints don't match ANY available toolchain pin, or when the user has
explicitly chosen Option B. Always confirm with the user before editing
app-level version pins — modernizing the toolchain vs. freezing the devshell
to match it is their call, not yours.

## 2. Find a version-pinned Flutter in nixpkgs (Option A only)

nixpkgs exposes `pkgs.flutterPackages.v3_XX` attributes. Each maps to a
concrete Dart (e.g. `v3_32` → Dart 3.8.1, `v3_35` → Dart 3.9.2). Match
`pubspec.yaml` `environment.sdk` **and** the Android stack the repo already
ships (Gradle/AGP/Kotlin/compileSdk). Each channel only retains a rolling
window of recent versions — an OLDER channel (e.g.
`github:NixOS/nixpkgs/nixos-24.11`) is often needed for pins current
`nixos-unstable` no longer retains.

1. Search: `nix search nixpkgs flutter` (or nix MCP `info` /
   `flake-inputs` against the locked nixpkgs).
2. Cross-check the exact Dart version pinned to a given Flutter attribute by
   reading `pkgs/development/compilers/flutter/versions/<ver>/data.json` in
   the nixpkgs source for that channel.
3. Check multiple channels (unstable, plus one or two recent stable
   releases like `nixos-24.11`, `nixos-24.05`) — retention windows differ per
   channel, so the version you need may only exist on one of them.

## 3. Base flake-parts template

Adapt the package list and versions to the project; this is a working
starting point, not a copy-paste-and-done file. Discover available
emulator / build-tools / NDK / CMake version sets from that channel's
`androidenv/repo.json` before copying numbers — they drift per nixpkgs
commit.

```nix
{
  description = "<project> devshell";

  inputs = {
    # or nixos-unstable — see decision point above
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # androidenv's aapt etc. often only ships for x86_64-linux/aarch64-darwin
      # — verify before adding aarch64-linux
      systems = [ "x86_64-linux" ];

      perSystem = { system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              # license acceptance is a nixpkgs CONFIG option, NOT a
              # composeAndroidPackages argument
              android_sdk.accept_license = true;
              allowUnfree = true; # Android SDK license is unfree
            };
          };

          # or pkgs.flutter for latest — see decision point
          flutterPkg = pkgs.flutterPackages.v3_24;

          # pin exact versions from this channel's androidenv/repo.json
          cmdLineToolsVersion = "13.0";
          ndkVersion = "26.3.11579264"; # from FlutterExtension — section 3b

          androidComposition = pkgs.androidenv.composeAndroidPackages {
            inherit cmdLineToolsVersion;
            platformToolsVersion = "35.0.2";
            # add whatever exact version Gradle asks for at build time
            # (see troubleshooting below)
            buildToolsVersions = [ "33.0.1" ];
            platformVersions = [ "35" ];
            includeNDK = true;
            ndkVersions = [ ndkVersion ];
            # includeEmulator = true is REQUIRED if emulatorVersion is set;
            # otherwise the emulator binary is simply absent
            includeEmulator = true;
            emulatorVersion = "35.2.5";
            includeSystemImages = true;
            systemImageTypes = [ "google_apis" ];
            abiVersions = [ "x86_64" ];
            # if Gradle asks for CMake: includeCmake = true;
            # cmakeVersions = [ "3.22.1" ];
          };
          androidSdkRoot =
            "${androidComposition.androidsdk}/libexec/android-sdk";
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              flutterPkg
              pkgs.temurin-bin-17 # Flutter/Gradle Android builds want JDK 17
              androidComposition.androidsdk
              pkgs.git
              pkgs.unzip
              pkgs.which
              pkgs.xvfb-run # for headless emulator runs
            ];

            shellHook = ''
              export PUB_CACHE="$PWD/.pub-cache"
              mkdir -p "$PUB_CACHE"
              export JAVA_HOME="${pkgs.temurin-bin-17}"
              export ANDROID_SDK_ROOT="${androidSdkRoot}"
              export ANDROID_HOME="${androidSdkRoot}"
              export ANDROID_NDK_HOME="${androidSdkRoot}/ndk/${ndkVersion}"
              export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
              _sdk_bin="$ANDROID_SDK_ROOT/emulator"
              _sdk_bin="$_sdk_bin:$ANDROID_SDK_ROOT/platform-tools"
              _sdk_bin="$_sdk_bin:$ANDROID_SDK_ROOT/cmdline-tools"
              _sdk_bin="$_sdk_bin/${cmdLineToolsVersion}/bin"
              export PATH="$_sdk_bin:$PATH"
              unset _sdk_bin

              # Gradle 9 rejects includeBuild() of a non-writable projectDir.
              # nixpkgs redirects .gradle/build into ~/.cache, but still sets
              # rootProject.projectDir to the store path — so copy only
              # packages/flutter_tools/gradle into a local writable SDK overlay.
              FLUTTER_SDK_SRC="${flutterPkg}"
              FLUTTER_SDK_RW="$PWD/.flutter-sdk-rw"
              if [ ! -e "$FLUTTER_SDK_RW/.built" ]; then
                rm -rf "$FLUTTER_SDK_RW"
                mkdir -p "$FLUTTER_SDK_RW"
                ln -s "$FLUTTER_SDK_SRC"/* "$FLUTTER_SDK_RW/"
                rm -f "$FLUTTER_SDK_RW/packages"
                mkdir -p "$FLUTTER_SDK_RW/packages"
                ln -s "$FLUTTER_SDK_SRC"/packages/* \
                  "$FLUTTER_SDK_RW/packages/"
                rm -f "$FLUTTER_SDK_RW/packages/flutter_tools"
                mkdir -p "$FLUTTER_SDK_RW/packages/flutter_tools"
                ln -s "$FLUTTER_SDK_SRC"/packages/flutter_tools/* \
                  "$FLUTTER_SDK_RW/packages/flutter_tools/"
                rm -f "$FLUTTER_SDK_RW/packages/flutter_tools/gradle"
                cp -a "$FLUTTER_SDK_SRC/packages/flutter_tools/gradle" \
                  "$FLUTTER_SDK_RW/packages/flutter_tools/gradle"
                chmod -R u+w \
                  "$FLUTTER_SDK_RW/packages/flutter_tools/gradle"
                touch "$FLUTTER_SDK_RW/.built"
              fi
              export FLUTTER_ROOT="$FLUTTER_SDK_RW"
              export PATH="$FLUTTER_SDK_RW/bin:$PATH"

              flutter config --no-analytics >/dev/null 2>&1 || true
              flutter config --android-sdk "$ANDROID_HOME" >/dev/null 2>&1 \
              || true
            '';
          };
        };
    };
}
```

Ignore `.flutter-sdk-rw/` (and usually `.pub-cache/`) in `.gitignore`. Do not
commit `android/build/` or local SDK overlays.

### 3a. Writable Flutter overlay — keep it, keep it small (Gradle 9)

Modern apps (`android/settings.gradle`) do:

```groovy
includeBuild("${settings.ext.flutterSdkPath}/packages/flutter_tools/gradle")
```

`includeBuild` treats that path as a Gradle project. Gradle 9 refuses a
non-writable `projectDir` ("does not exist, can't be written to or is not a
directory") when that path is in `/nix/store`.

nixpkgs already patches `flutter_tools/gradle/settings.gradle` to redirect
`.gradle` / `build` under `~/.cache/flutter/nix-flutter-tools-gradle/<engine>/`
and passes `--project-cache-dir` / `-Pkotlin.project.persistent.dir`. It still
sets `rootProject.projectDir` to the store path — on Gradle 9 that remains
fatal. Older apps that used `apply from: .../flutter.gradle` may not need the
overlay; modern `includeBuild` apps do.

**Minimal overlay that works** (peel symlinks, copy only `gradle`):

1. `ln -s "$FLUTTER_SDK_SRC"/*` into `.flutter-sdk-rw/`.
2. `rm` + `mkdir` `packages/`, then `ln -s` each
   `$FLUTTER_SDK_SRC/packages/*`.
3. Same peel for `packages/flutter_tools/`.
4. `rm` the `gradle` symlink; `cp -a` the store `gradle` dir and
   `chmod -R u+w`.
5. Touch a `.built` sentinel so later `nix develop` entries skip the copy.
6. Export `FLUTTER_ROOT` + PATH at the overlay; `flutter config --android-sdk`.

Do **not** rewrite `HOME` or sed `android/local.properties` for mythical
"sibling contamination". Symlink paths (e.g. `driven` → `fleet-app-modular`)
look like other projects; they are the same tree. Keep shell cwd on the real
project root.

When stripping a "heavy" shellHook: prove with a clean
`rm -rf .flutter-sdk-rw` and a fresh `flutter build apk` — theory about
nixpkgs patches is not enough on Gradle 9.

### 3b. NDK pin comes from FlutterExtension, not guesswork

App `ndkVersion flutter.ndkVersion` resolves from
`packages/flutter_tools/gradle/.../FlutterExtension.kt` in the **pinned**
Flutter package (e.g. Flutter 3.35.7 → `27.0.12077973`). Web search "latest
Flutter NDK" can be wrong for that nixpkgs pin. Read the file in the store
path (or under `.flutter-sdk-rw` after overlay setup) and set
`ndkVersions` / `ANDROID_NDK_HOME` to that exact string.

## 4. Verification procedure

Run these in order. Don't declare the **toolchain** done until step 5
(`flutter build apk`) succeeds — that's where SDK-component gaps surface —
and ideally step 7 (real emulator run) too. `flutter test` green is not
required to declare the toolchain done if failures are clearly app-template
debt (placeholder tests); don't confuse those with toolchain breakage.

1. `nix flake check`
2. `nix develop --command flutter --version` — confirm Flutter/Dart version
   matches intent (Option A: matches pubspec constraint exactly; Option B:
   latest).
3. `nix develop --command flutter pub get`
4. If the project uses `json_serializable`/`build_runner` — check for
   `part '*.g.dart'` or `@JsonSerializable` under `lib/` **and** under any
   `path:` packages in `packages/`:
   ```bash
   grep -rl "part '.*\.g\.dart'\|@JsonSerializable" lib/ packages/ 2>/dev/null
   ```
   Root `flutter pub run build_runner` does **not** generate `.g.dart` for
   `path:` packages. Run codegen per package that declares
   `json_serializable` / `build_runner`, or the APK compile fails with missing
   `_$*FromJson` / `_$*ToJson`. Those package `.g.dart` files are often
   gitignored — generate after `pub get`:
   ```bash
   nix develop --command flutter pub run build_runner build \
     --delete-conflicting-outputs
   # then for each path package that needs it, e.g.:
   (cd packages/<name> && \
     nix develop --command flutter pub run build_runner build \
       --delete-conflicting-outputs)
   ```
   Confirm every expected `.g.dart` file exists next to its source.
5. `nix develop --command flutter build apk --debug`
6. `nix develop --command flutter test`
7. Run on a headless emulator (section 5 below) to prove the built APK
   actually launches, not just compiles.

## 5. Headless Android emulator run-proof procedure

Requires `includeEmulator = true` plus a system image in
`composeAndroidPackages`. Without `includeEmulator`, setting
`emulatorVersion` alone leaves the emulator binary absent.

```bash
# inside `nix develop`
avdmanager list avd
# reuse an existing AVD if present
# else create one from a system image the devShell provides:
avdmanager create avd -n test_avd \
  -k "system-images;android-34;google_apis;x86_64"

ls -la /dev/kvm
# confirms hw-accelerated emulation is possible; check group/ACL
# access too (getfacl /dev/kvm)

xvfb-run -a emulator -avd test_avd -no-window -no-audio -no-boot-anim \
  -gpu swiftshader_indirect -accel auto &
adb wait-for-device
# poll until boot completes (up to ~5 min):
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" \
  != "1" ]; do sleep 2; done

adb install -r build/app/outputs/flutter-apk/app-debug.apk
PKG=$(grep applicationId android/app/build.gradle | head -1 | \
  sed -E 's/.*"(.*)".*/\1/')
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 3
adb shell dumpsys activity activities | grep -i "$PKG"
# look for topResumedActivity / visible=true
adb logcat -d | tail -50
# confirm no FATAL EXCEPTION / AndroidRuntime crash for the package

adb emu kill                                             # clean teardown
```

Note: this can legitimately end in "emulator couldn't boot" in a sandboxed
CI/agent environment with no KVM access — that's a valid, reportable outcome,
not a failure to fix. Report it as such rather than trying to force emulation
without hardware acceleration.

## 6. Troubleshooting checklist

Work through these in the order symptoms appear; fixing one commonly reveals
the next.

1. **Symptom:** `build_runner` codegen fails:
   `FormatterException ... requires the 'null-aware-elements' language feature`

   **Cause:** Resolved code-generator package emits syntax requiring a Dart
   language version higher than pubspec's `environment.sdk` lower bound

   **Fix:** Option A: don't touch it, use a matching-version Flutter instead.
   Option B: bump `environment.sdk` lower bound to match (e.g. `^3.8.0`)

2. **Symptom:** APK compile fails with missing `_$*FromJson` / `_$*ToJson`
   for types defined under `packages/`

   **Cause:** Root `build_runner` does not generate `.g.dart` for `path:`
   packages

   **Fix:** Run `build_runner` inside each path package that declares it
   (section 4 step 4)

3. **Symptom:** `flutter build apk` fails:
   `Your project's Gradle version (X) is lower than Flutter's minimum`
   `supported version of Y`

   **Cause:** Newer Flutter's Gradle plugin has a higher minimum Gradle
   requirement

   **Fix:** Bump `android/gradle/wrapper/gradle-wrapper.properties`'s
   `distributionUrl`, and bump AGP in `android/settings.gradle` to a version
   compatible with the new Gradle (check compatibility tables; avoid jumping to
   an AGP major version needing DSL migration, e.g. AGP 9.x, unless you intend
   to migrate `build.gradle` syntax too)

4. **Symptom:** Gradle fails with projectDir "does not exist, can't be written
   to or is not a directory" under `/nix/store/.../flutter_tools/gradle`

   **Cause:** Gradle 9 `includeBuild` requires a writable Flutter tools gradle
   projectDir; nixpkgs' cache-dir patches are not enough alone

   **Fix:** Use the minimal `.flutter-sdk-rw` overlay (section 3a). Prove by
   `rm -rf .flutter-sdk-rw` then rebuilding — do not strip the overlay on
   theory alone

5. **Symptom:** Gradle tries to `sdkmanager`-install a missing SDK component
   into the nix store path and fails: `The SDK directory is not writable`

   **Cause:** The composed `androidenv` SDK doesn't include that exact
   build-tools/platform/NDK/CMake version

   **Fix:** Read the exact component id from the error and add it to the
   relevant `composeAndroidPackages` list (`buildToolsVersions` /
   `platformVersions` / `ndkVersions` / `cmakeVersions` with
   `includeCmake = true`) — iterate one at a time. Discover available attrs
   from that channel's `androidenv/repo.json` before guessing

6. **Symptom:**
   `Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks` (often
   from a plugin like `tflite_flutter`)

   **Cause:** A subproject/plugin's own `build.gradle` pins an old Java target
   while the root project's Kotlin plugin defaults to a newer JVM target

   **Fix:** Force a consistent target across all subprojects from the ROOT
   `android/build.gradle` (see snippet below) — do NOT edit the plugin's
   vendored `build.gradle` in the pub cache, it's not repo-tracked and won't
   survive `pub get`

7. **Symptom:**
   `Dependency 'androidx.X:Y:Z' requires ... compile against version 34 or`
   `later ... :plugin_name is currently compiled against android-31`

   **Cause:** A plugin's own vendored `build.gradle` hardcodes an old
   `compileSdkVersion`, conflicting with its own transitive deps

   **Fix:** Same root-`android/build.gradle` `subprojects` block as #6, add
   `compileSdkVersion 36` (or whatever's needed) alongside the JVM-target block

8. **Symptom:** `licenseAccepted` passed directly to `composeAndroidPackages`
   fails: "unexpected argument"

   **Cause:** License acceptance isn't a `composeAndroidPackages` argument

   **Fix:** Set `config.android_sdk.accept_license = true;` (plus
   `allowUnfree = true;`) when importing `nixpkgs` instead — see template in
   section 3

9. **Symptom:** Older nixpkgs channel doesn't offer `"latest"` for
   `cmdLineToolsVersion`/`platformToolsVersion`/`emulatorVersion`

   **Cause:** That channel's `androidenv` package set doesn't carry a `"latest"`
   alias

   **Fix:** Pin an exact version number available on that channel instead (find
   via `androidenv/repo.json` / `nix search` / reading nixpkgs source), same
   pattern as build-tools/platform/NDK

10. **Symptom:** `emulator` / `avdmanager` not found despite `emulatorVersion`
    in `composeAndroidPackages`

    **Cause:** `includeEmulator = true` was omitted; version alone does not
    install the binary

    **Fix:** Set `includeEmulator = true` and ensure
    `emulator`/`platform-tools`/`cmdline-tools/<ver>/bin` are on `PATH` in
    `shellHook`

Fix #6/#7 root `android/build.gradle` snippet:

```groovy
subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android {
                compileOptions {
                    sourceCompatibility JavaVersion.VERSION_17
                    targetCompatibility JavaVersion.VERSION_17
                }
            }
        }
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile)
            .configureEach {
            kotlinOptions { jvmTarget = "17" }
        }
    }
}
```

## Final checklist

- [ ] Asked the user Option A vs Option B before writing `flake.nix` (or used
      their already-stated preference); did not silently modernize app files
- [ ] `flake.nix` uses flake-parts, pins `nixpkgs` to a channel that actually
      offers the chosen Flutter version; Flutter attr Dart matches pubspec +
      existing Android stack
- [ ] `androidenv.composeAndroidPackages` versions are exact (no `"latest"`
      on channels that don't support it), discovered from that channel's
      `repo.json`; license/unfree config is set on the `nixpkgs` import
- [ ] `includeEmulator = true` if `emulatorVersion` is set; NDK version taken
      from pinned Flutter's `FlutterExtension.kt`, not web search
- [ ] `shellHook` sets `PUB_CACHE`, `JAVA_HOME`, `ANDROID_SDK_ROOT`/`HOME`,
      `ANDROID_NDK_HOME`/`ROOT`, SDK tool PATH, and a minimal `.flutter-sdk-rw`
      overlay (Gradle 9 `includeBuild`); `.flutter-sdk-rw/` gitignored
- [ ] `nix flake check` passes
- [ ] `flutter --version` inside `nix develop` matches the intended
      Option A/B target
- [ ] `flutter pub get` and (if applicable) `build_runner` succeed for root
      **and** path packages; all expected `.g.dart` files present
- [ ] `flutter build apk --debug` succeeds
- [ ] `flutter test` run; failures that are clearly app-template debt noted
      separately from toolchain status
- [ ] Headless emulator run attempted; result (booted+launched, or
      no-KVM-in-sandbox) reported to the user
- [ ] Any app-file version bumps (Option B, or genuine constraint mismatches)
      were confirmed with the user before editing, not applied unilaterally
