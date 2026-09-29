# expo-brownfield: autolinked libraries always published at `1.0`

Minimal reproducer: default `create-expo-app` SDK 57 template, plus `expo-brownfield` and
`react-native-keyboard-controller`, with the brownfield plugin publishing to a local directory
(`./maven-repo`). No other changes.

```bash
bun install
./repro.sh
```

`repro.sh` publishes two brownfield releases and changes only the keyboard-controller version
between them:

| Brownfield release | keyboard-controller installed | Published as |
|---|---|---|
| `1.0.0` | `1.21.9` | `com.reactnativekeyboardcontroller:1.0` |
| `2.0.0` | `1.22.6` | `com.reactnativekeyboardcontroller:1.0` (same coordinates, different AAR) |

Output:

```text
=== brownfield 1.0.0 (react-native-keyboard-controller 1.21.9 installed) depends on:
      <artifactId>com.reactnativekeyboardcontroller</artifactId>
      <version>1.0</version>
=== keyboard-controller versions in maven-repo:
1.0
77f8d44992016a918c7a821125483becb5c7ea6d  maven-repo/expo-brownfield-version-repro/com.reactnativekeyboardcontroller/1.0/com.reactnativekeyboardcontroller-1.0.aar

=== brownfield 2.0.0 (react-native-keyboard-controller 1.22.6 installed) depends on:
      <artifactId>com.reactnativekeyboardcontroller</artifactId>
      <version>1.0</version>
=== keyboard-controller versions in maven-repo:
1.0
b24b75d39ba1b1377b4a3e2dcc9a29efa2ba4aec  maven-repo/expo-brownfield-version-repro/com.reactnativekeyboardcontroller/1.0/com.reactnativekeyboardcontroller-1.0.aar
```

The second release overwrites the first release's `1.0` AAR in place, so brownfield `1.0.0` now
resolves to keyboard-controller 1.22.6 native code. On an immutable registry (GitHub Packages,
Maven Central) the second publish fails with a 409 instead, or, if existing coordinates are
skipped, the host keeps getting the first `1.0` binary ever uploaded.

See [ISSUE.md](ISSUE.md) for the cause and a suggested fix.
