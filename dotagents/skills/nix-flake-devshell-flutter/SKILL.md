---
name: nix-flake-devshell-flutter
description: >-
  Build or fix a Nix flake-parts devShell for a Flutter/Android app — pinning
  nixpkgs' flutterPackages to a specific version, composing an androidenv
  Android SDK, wiring JAVA_HOME/ANDROID_SDK_ROOT/PUB_CACHE, and proving the
  result with a real headless-emulator build-and-run. Use when the user says
  "flutter devshell", "nix flake for flutter", "flutter android nix",
  "flake-parts flutter", "flutter nix shell", "nix develop flutter build fails",
  or asks to reproduce/pin a Flutter+Android toolchain with Nix so `flutter
  build apk` and `flutter test` work inside `nix develop`. Also use when
  troubleshooting devShell-surfaced Gradle/AGP/Kotlin/NDK/SDK-component errors
  that show up only when building a Flutter app from inside a Nix shell.
---

# Flutter + Android Nix devShell (flake-parts)

Build a reproducible `nix develop` shell that runs a Flutter/Android project's
full toolchain — Flutter SDK, JDK, Android SDK/NDK/emulator — pinned via Nix
instead of relying on host-installed Android Studio/SDK managers.

## 1. Decide: pin to the app's existing versions, or track latest Flutter

This is the single most important judgment call in the whole procedure. Ask
the user which they want (unless they already stated a preference) before
writing any Nix code.

**Option A — pin nixpkgs to match the repo's EXISTING toolchain exactly.**
Zero app-file changes. Devshell tooling stays on an older nixpkgs snapshot.

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

nixpkgs exposes `pkgs.flutterPackages.v3_XX` attributes (e.g.
`flutterPackages.v3_24` = Flutter 3.24.4 / Dart 3.5.4 as packaged at time of
writing), but each channel only retains a rolling window of recent versions.
An OLDER channel (e.g. `github:NixOS/nixpkgs/nixos-24.11`) is often needed to
get an older pinned version than current `nixos-unstable` still retains.

1. Search: `nix search nixpkgs flutter`
2. Cross-check the exact Dart version pinned to a given Flutter attribute by
   reading `pkgs/development/compilers/flutter/versions/<ver>/data.json` in
   the nixpkgs source for that channel.
3. Check multiple channels (unstable, plus one or two recent stable
   releases like `nixos-24.11`, `nixos-24.05`) — retention windows differ per
   channel, so the version you need may only exist on one of them.

## 3. Base flake-parts template

Adapt the package list and versions to the project; this is a working
starting point, not a copy-paste-and-done file.

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

          androidComposition = pkgs.androidenv.composeAndroidPackages {
            # pin exact versions available on your chosen channel —
            # "latest" isn't always offered on older channels
            cmdLineToolsVersion = "13.0";
            platformToolsVersion = "35.0.2";
            # add whatever exact version Gradle asks for at build time
            # (see troubleshooting below)
            buildToolsVersions = [ "33.0.1" ];
            platformVersions = [ "35" ];
            includeNDK = true;
            # must match the exact version Flutter's gradle plugin requests
            # (see troubleshooting)
            ndkVersions = [ "26.3.11579264" ];
            emulatorVersion = "35.2.5";
            includeSystemImages = true;
            systemImageTypes = [ "google_apis" ];
            abiVersions = [ "x86_64" ];
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
              # flutter SDK from the nix store is read-only; pub cache
              # must be writable
              mkdir -p "$PUB_CACHE"
              export JAVA_HOME="${pkgs.temurin-bin-17}"
              export ANDROID_SDK_ROOT="${androidSdkRoot}"
              export ANDROID_HOME="${androidSdkRoot}"
              export ANDROID_NDK_HOME="${androidSdkRoot}/ndk/26.3.11579264"
              export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
              flutter config --no-analytics >/dev/null 2>&1 || true
              flutter config --android-sdk "$ANDROID_HOME" >/dev/null 2>&1 \
              || true
            '';
          };
        };
    };
}
```

## 4. Verification procedure

Run these in order. Don't declare the devShell done until step 5 (`flutter
build apk`) succeeds — that's where SDK-component gaps surface — and ideally
step 7 (real emulator run) too.

1. `nix flake check`
2. `nix develop --command flutter --version` — confirm Flutter/Dart version
   matches intent (Option A: matches pubspec constraint exactly; Option B:
   latest).
3. `nix develop --command flutter pub get`
4. If the project uses `json_serializable`/`build_runner` — check for
   `part '*.g.dart'` or `@JsonSerializable` under `lib/`:
   ```bash
   grep -rl "part '.*\.g\.dart'\|@JsonSerializable" lib/
   ```
   then run:
   ```bash
    nix develop --command flutter pub run build_runner build \
      --delete-conflicting-outputs
   ```
   and confirm every expected `.g.dart` file exists next to its source.
5. `nix develop --command flutter build apk --debug`
6. `nix develop --command flutter test`
7. Run on a headless emulator (section 5 below) to prove the built APK
   actually launches, not just compiles.

## 5. Headless Android emulator run-proof procedure

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

2. **Symptom:** `flutter build apk` fails:
   `Your project's Gradle version (X) is lower than Flutter's minimum`
   `supported version of Y`

   **Cause:** Newer Flutter's Gradle plugin has a higher minimum Gradle
   requirement

   **Fix:** Bump `android/gradle/wrapper/gradle-wrapper.properties`'s
   `distributionUrl`, and bump AGP in `android/settings.gradle` to a version
   compatible with the new Gradle (check compatibility tables; avoid jumping to
   an AGP major version needing DSL migration, e.g. AGP 9.x, unless you intend
   to migrate `build.gradle` syntax too)

3. **Symptom:** Gradle tries to `sdkmanager`-install a missing SDK component
   into the nix store path and fails: `The SDK directory is not writable`

   **Cause:** The composed `androidenv` SDK doesn't include that exact
   build-tools/platform/NDK version

   **Fix:** Read the exact requested version/id from the error and add it to the
   relevant `composeAndroidPackages` list
   (`buildToolsVersions`/`platformVersions`/`ndkVersions`) — iterate one at a
   time

4. **Symptom:**
   `Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks` (often
   from a plugin like `tflite_flutter`)

   **Cause:** A subproject/plugin's own `build.gradle` pins an old Java target
   while the root project's Kotlin plugin defaults to a newer JVM target

   **Fix:** Force a consistent target across all subprojects from the ROOT
   `android/build.gradle` (see snippet below) — do NOT edit the plugin's
   vendored `build.gradle` in the pub cache, it's not repo-tracked and won't
   survive `pub get`

5. **Symptom:**
   `Dependency 'androidx.X:Y:Z' requires ... compile against version 34 or`
   `later ... :plugin_name is currently compiled against android-31`

   **Cause:** A plugin's own vendored `build.gradle` hardcodes an old
   `compileSdkVersion`, conflicting with its own transitive deps

   **Fix:** Same root-`android/build.gradle` `subprojects` block as #4, add
   `compileSdkVersion 36` (or whatever's needed) alongside the JVM-target block

6. **Symptom:** `licenseAccepted` passed directly to `composeAndroidPackages`
   fails: "unexpected argument"

   **Cause:** License acceptance isn't a `composeAndroidPackages` argument

   **Fix:** Set `config.android_sdk.accept_license = true;` (plus
   `allowUnfree = true;`) when importing `nixpkgs` instead — see template in
   section 3

7. **Symptom:** Older nixpkgs channel doesn't offer `"latest"` for
   `cmdLineToolsVersion`/`platformToolsVersion`/`emulatorVersion`

   **Cause:** That channel's `androidenv` package set doesn't carry a `"latest"`
   alias

   **Fix:** Pin an exact version number available on that channel instead (find
   via `nix search`/reading nixpkgs source), same pattern as
   build-tools/platform/NDK

Fix #4/#5 root `android/build.gradle` snippet:

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
      their already-stated preference)
- [ ] `flake.nix` uses flake-parts, pins `nixpkgs` to a channel that actually
      offers the chosen Flutter version
- [ ] `androidenv.composeAndroidPackages` versions are exact (no `"latest"`
      on channels that don't support it) and license/unfree config is set on
      the `nixpkgs` import, not passed to `composeAndroidPackages`
- [ ] `shellHook` sets `PUB_CACHE`, `JAVA_HOME`, `ANDROID_SDK_ROOT`/`HOME`,
      `ANDROID_NDK_HOME`/`ROOT`
- [ ] `nix flake check` passes
- [ ] `flutter --version` inside `nix develop` matches the intended
      Option A/B target
- [ ] `flutter pub get` and (if applicable) `build_runner build` succeed,
      all expected `.g.dart` files present
- [ ] `flutter build apk --debug` succeeds
- [ ] `flutter test` passes
- [ ] Headless emulator run attempted; result (booted+launched, or
      no-KVM-in-sandbox) reported to the user
- [ ] Any app-file version bumps (Option B, or genuine constraint mismatches)
      were confirmed with the user before editing, not applied unilaterally
