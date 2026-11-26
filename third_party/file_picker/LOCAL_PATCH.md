# Local Android Built-in Kotlin patch

Source: https://pub.dev/packages/file_picker/versions/10.3.10 (10.3.10). Upstream license retained.

The rich-text editor html_editor_enhanced 2.7.1 requires file_picker ^10.2.0, so keep the compatible Dart and native implementation while migrating Android Gradle to AGP 9 Built-in Kotlin. Removed explicit KGP and obsolete classpaths, use kotlin.compilerOptions and JVM 17, and move manifest package to namespace. Existing Android dependencies and Dart/Apple/Web/Windows/Linux APIs are retained.

Remove this override when the rich-text editor supports an upstream Built-in Kotlin-compatible file_picker version. Test event CSV/XLSX import, cancellation, and the business-plan editor's file/media picker before removing it.

Imported upstream files have trailing whitespace normalized for repository checks; this does not change runtime behavior.
