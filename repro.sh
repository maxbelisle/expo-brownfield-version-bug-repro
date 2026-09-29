#!/usr/bin/env bash
# Publishes the brownfield library twice to ./maven-repo, changing only the
# react-native-keyboard-controller version between the two releases, then shows
# which keyboard-controller coordinates each brownfield release depends on.
set -euo pipefail
cd "$(dirname "$0")"

release() { # <brownfield version> <keyboard-controller version>
  node -e '
    const fs = require("fs");
    const config = JSON.parse(fs.readFileSync("app.json", "utf8"));
    config.expo.plugins.find(p => p[0] === "expo-brownfield")[1].android.version = process.argv[1];
    fs.writeFileSync("app.json", JSON.stringify(config, null, 2) + "\n");
  ' "$1"
  bunx expo install "react-native-keyboard-controller@$2"
  bunx expo prebuild --clean --platform android --no-install
  bunx expo-brownfield build:android --release --repo repro

  local kbc
  kbc=$(find maven-repo -type d -name com.reactnativekeyboardcontroller)
  echo
  echo "=== brownfield $1 (react-native-keyboard-controller $2 installed) depends on:"
  grep -A1 "<artifactId>com.reactnativekeyboardcontroller</artifactId>" \
    "$(find maven-repo -name "brownfield-$1.pom")"
  echo "=== keyboard-controller versions in maven-repo:"
  ls "$kbc" | grep -v maven-metadata
  shasum "$kbc"/*/*.aar
  echo
}

rm -rf maven-repo
release 1.0.0 1.21.9
release 2.0.0 1.22.6
