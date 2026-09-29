**Title:** [expo-brownfield][Android] Autolinked libraries are published at their template `versionName` ("1.0"), so every release reuses the same Maven coordinates

### Minimal reproducible example

https://github.com/maxbelisle/expo-brownfield-version-bug-repro

### Summary

`expo-brownfield` publishes each autolinked subproject at `getVersion()`, which returns the library's `defaultConfig.versionName` whenever it's set. Many React Native community libraries still carry the library template's `versionName "1.0"`, for example `react-native-keyboard-controller`, `react-native-screens`, `react-native-safe-area-context`, `@shopify/react-native-skia`, `@sentry/react-native` and `react-native-view-shot`. Each of them is published as `<group>:<artifact>:1.0` on every brownfield release, whatever its npm version and whatever React Native version it was compiled against.

What happens next depends on the repository:

- **Local directory / mavenLocal:** each release overwrites the previous `1.0`, so an older brownfield release's POM silently resolves to a newer native binary. The repro shows this.
- **Immutable registry (GitHub Packages, Maven Central):** the second release fails with `409 Conflict` on the first such library. Skipping existing coordinates avoids the 409 (and is needed anyway for Expo's prebuilt modules, which keep their SDK versions across releases), but then the host keeps resolving the **first `1.0` ever uploaded**. We shipped `react-native-keyboard-controller` 1.21.9 JS against its 1.20.x native module this way. Every React Native screen died at bundle load with `TypeError: Cannot read property 'keyboardBorderRadius' of undefined`, then `Invariant Violation: "<Component>" has not been registered`. 1.21 reads `getConstants().keyboardBorderRadius` at module init, which the old native module doesn't implement.

Setting `project.version` on the subprojects doesn't help, because `getVersion()` only falls back to it when `versionName` is empty.

### Steps to reproduce

```bash
git clone https://github.com/maxbelisle/expo-brownfield-version-bug-repro.git
cd expo-brownfield-version-bug-repro
bun install
./repro.sh
```

`repro.sh` publishes brownfield `1.0.0` with keyboard-controller `1.21.9`, then brownfield `2.0.0` with keyboard-controller `1.22.6`, both to a `localDirectory` repository:

```text
=== brownfield 1.0.0 (react-native-keyboard-controller 1.21.9 installed) depends on:
      <artifactId>com.reactnativekeyboardcontroller</artifactId>
      <version>1.0</version>
77f8d44992016a918c7a821125483becb5c7ea6d  maven-repo/expo-brownfield-version-repro/com.reactnativekeyboardcontroller/1.0/com.reactnativekeyboardcontroller-1.0.aar

=== brownfield 2.0.0 (react-native-keyboard-controller 1.22.6 installed) depends on:
      <artifactId>com.reactnativekeyboardcontroller</artifactId>
      <version>1.0</version>
b24b75d39ba1b1377b4a3e2dcc9a29efa2ba4aec  maven-repo/expo-brownfield-version-repro/com.reactnativekeyboardcontroller/1.0/com.reactnativekeyboardcontroller-1.0.aar
```

**Expected:** keyboard-controller is published at coordinates that change when its binary changes.
**Actual:** both releases publish and depend on `com.reactnativekeyboardcontroller:1.0`, and the second overwrites the first.

### Cause

`packages/expo-brownfield/gradle-plugins/publish/src/main/kotlin/expo/modules/plugin/utils.kt`:

```kotlin
internal fun getVersion(project: Project, libraryExtension: LibraryExtension): String {
  val versionName = libraryExtension.defaultConfig.versionName
  if (versionName is String && versionName.isNotEmpty()) {
    return versionName
  }

  return project.version as? String ?: "1.0.0"
}
```

A library's own version isn't a reliable identity for the published binary even when it isn't `1.0`. The AAR is compiled against the app's React Native version, the app's patches and the app's build flags. For example, `react-native-reanimated` sets `version = REANIMATED_VERSION` (npm version), so a React Native bump without a Reanimated bump republishes different native code under an unchanged version. `expo.core` is published at the `expo` package version but embeds the app's generated `ExpoModulesPackageList`, so adding an Expo module between two releases on the same SDK patch reuses its coordinates too.

### Suggested fix

Publish every subproject that's compiled as part of the brownfield build at the brownfield library's configured `version`. Expo's prebuilt modules (copied from `local-maven-repo`) keep their own versions. At minimum, prefer `project.version` over `versionName`, so users can stamp the version themselves.

### Workaround

In the root `android/build.gradle` (for example from a config plugin):

```groovy
allprojects {
  pluginManager.withPlugin('com.android.library') {
    androidComponents.finalizeDsl { android ->
      android.defaultConfig.versionName = System.getenv('BROWNFIELD_VERSION') ?: '0.0.0-local'
    }
  }
}
```

This works because `setupPublishing` reads `versionName` in an `afterEvaluate` that it registers from inside its own `finalizeDsl` callback, so it runs after every `finalizeDsl` callback, including this one.

### Environment

```text
expo 57.0.26
expo-brownfield 57.0.24
react-native 0.86.3
react-native-keyboard-controller 1.21.9 / 1.22.6
Gradle 9.3.1
macOS 26.6.2, Node 25.2.1, Bun 1.3.4
```
