# Local Android Built-in Kotlin patch

Source: https://pub.dev/packages/flutter_tts/versions/4.2.5 (4.2.5), MIT license retained in LICENSE.

Android uses the consuming project’s AGP 9 plugin and Built-in Kotlin. Removed explicit Kotlin Gradle Plugin application, legacy kotlinOptions, duplicate AGP/KGP classpaths and the manifest package attribute. Java and Kotlin target JVM 17. Dart API and Apple/Windows implementations are unchanged. Web speech-boundary values use explicit JSNumber/JSString conversions rather than casting JavaScript values to Dart primitives. Requires Flutter >=3.44 and Dart >=3.12.

Remove the path override and this copy once an upstream release supports Built-in Kotlin, then rerun speech tests and platform builds. Do not patch the shared pub cache.

Imported upstream files have trailing whitespace normalized for repository checks; this does not change runtime behavior.
