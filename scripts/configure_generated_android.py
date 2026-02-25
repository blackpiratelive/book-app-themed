from __future__ import annotations

import re
from pathlib import Path


TARGET_PACKAGE = "com.blackpiratex.book"
TARGET_APP_LABEL = "BlackPirateX Book tracker"
TEMPLATES_DIR = Path(__file__).resolve().parent / "android_widget_templates"


def main() -> None:
    patch_manifest()
    patch_android_settings_gradle()
    patch_android_root_gradle()
    patch_gradle()
    patch_main_activity()
    install_android_home_widget_templates()


def patch_manifest() -> None:
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if not manifest.exists():
        return
    text = manifest.read_text()

    if "android.permission.INTERNET" not in text:
        permission = '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        text = text.replace("<application", f"{permission}<application", 1)

    text = re.sub(
        r'android:label="[^"]*"',
        f'android:label="{TARGET_APP_LABEL}"',
        text,
        count=1,
    )
    text = re.sub(
        r'(<manifest\b[^>]*\bpackage=")([^"]+)(")',
        rf"\1{TARGET_PACKAGE}\3",
        text,
        count=1,
    )

    text = _inject_widget_manifest_entries(text)
    manifest.write_text(text)


def _inject_widget_manifest_entries(text: str) -> str:
    if "ReadingBooksWidgetProvider" in text and "ReadingBooksWidgetRemoteViewsService" in text:
        return text

    widget_block = f"""
        <receiver
            android:name=\"{TARGET_PACKAGE}.ReadingBooksWidgetProvider\"
            android:exported=\"true\">
            <intent-filter>
                <action android:name=\"android.appwidget.action.APPWIDGET_UPDATE\" />
            </intent-filter>
            <meta-data
                android:name=\"android.appwidget.provider\"
                android:resource=\"@xml/reading_books_widget_info\" />
        </receiver>

        <service
            android:name=\"{TARGET_PACKAGE}.ReadingBooksWidgetRemoteViewsService\"
            android:exported=\"false\"
            android:permission=\"android.permission.BIND_REMOTEVIEWS\" />
"""
    return text.replace("</application>", widget_block + "    </application>", 1)


def patch_gradle() -> None:
    for path in (
        Path("android/app/build.gradle.kts"),
        Path("android/app/build.gradle"),
    ):
        if not path.exists():
            continue
        text = path.read_text()
        text = re.sub(
            r'(namespace\s*(?:=)?\s*")([^"]+)(")',
            rf"\1{TARGET_PACKAGE}\3",
            text,
        )
        text = re.sub(
            r'(applicationId\s*(?:=)?\s*")([^"]+)(")',
            rf"\1{TARGET_PACKAGE}\3",
            text,
        )
        if path.suffix == ".kts":
            text = patch_kotlin_gradle_google_services_plugin(text)
            text = patch_kotlin_gradle_signing(text)
        else:
            text = patch_groovy_gradle_google_services_plugin(text)
            text = patch_groovy_gradle_signing(text)
        path.write_text(text)


def patch_android_settings_gradle() -> None:
    for path in (Path("android/settings.gradle.kts"), Path("android/settings.gradle")):
        if not path.exists():
            continue
        text = path.read_text()
        if "com.google.gms.google-services" in text:
            return
        if path.suffix == ".kts":
            plugin_line = '    id("com.google.gms.google-services") version "4.4.2" apply false\n'
            text = _inject_plugin_line_into_plugins_block(text, plugin_line)
        else:
            plugin_line = '    id "com.google.gms.google-services" version "4.4.2" apply false\n'
            text = _inject_plugin_line_into_plugins_block(text, plugin_line)
        path.write_text(text)
        return


def patch_android_root_gradle() -> None:
    for path in (Path("android/build.gradle.kts"), Path("android/build.gradle")):
        if not path.exists():
            continue
        text = path.read_text()
        if "com.google.gms:google-services" in text:
            return
        marker = "dependencies {"
        if marker in text:
            if path.suffix == ".kts":
                text = text.replace(
                    marker,
                    marker + '\n        classpath("com.google.gms:google-services:4.4.2")',
                    1,
                )
            else:
                text = text.replace(
                    marker,
                    marker + "\n        classpath 'com.google.gms:google-services:4.4.2'",
                    1,
                )
        path.write_text(text)
        return


def patch_kotlin_gradle_google_services_plugin(text: str) -> str:
    if "com.google.gms.google-services" in text:
        return text
    plugin_id = 'id("com.google.gms.google-services")'
    if re.search(r"plugins\s*\{", text):
        return re.sub(r"(plugins\s*\{\s*\n)", rf"\1    {plugin_id}\n", text, count=1)
    return text + '\napply(plugin = "com.google.gms.google-services")\n'


def patch_groovy_gradle_google_services_plugin(text: str) -> str:
    if "com.google.gms.google-services" in text:
        return text
    if re.search(r"plugins\s*\{", text):
        return re.sub(
            r"(plugins\s*\{\s*\n)",
            r"\1    id 'com.google.gms.google-services'\n",
            text,
            count=1,
        )
    return text + "\napply plugin: 'com.google.gms.google-services'\n"


def patch_kotlin_gradle_signing(text: str) -> str:
    marker = "// CI signing config (injected)"
    if marker not in text:
        signing_block = f"""
    {marker}
    signingConfigs {{
        create("release") {{
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            if (!keystorePath.isNullOrBlank()) {{
                storeFile = file(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }}
        }}
    }}

"""
        text = re.sub(r"(\n\s*buildTypes\s*\{)", signing_block + r"\1", text, count=1)

    text = text.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName("release")',
    )
    return text


def patch_groovy_gradle_signing(text: str) -> str:
    marker = "// CI signing config (injected)"
    if marker not in text:
        signing_block = f"""
    {marker}
    signingConfigs {{
        release {{
            def keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            if (keystorePath) {{
                storeFile file(keystorePath)
                storePassword System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias System.getenv("ANDROID_KEY_ALIAS")
                keyPassword System.getenv("ANDROID_KEY_PASSWORD")
            }}
        }}
    }}

"""
        text = re.sub(r"(\n\s*buildTypes\s*\{)", signing_block + r"\1", text, count=1)

    text = text.replace(
        "signingConfig = signingConfigs.debug",
        "signingConfig = signingConfigs.release",
    )
    text = text.replace(
        "signingConfig signingConfigs.debug",
        "signingConfig signingConfigs.release",
    )
    return text


def patch_main_activity() -> None:
    base_dirs = (
        Path("android/app/src/main/kotlin"),
        Path("android/app/src/main/java"),
    )
    for base in base_dirs:
        if not base.exists():
            continue
        for file in base.rglob("MainActivity.*"):
            ext = file.suffix.lower()
            target_dir = base.joinpath(*TARGET_PACKAGE.split("."))
            target_dir.mkdir(parents=True, exist_ok=True)
            target_file = target_dir / f"MainActivity{ext}"

            if ext == ".kt":
                target_file.write_text(_main_activity_kotlin_source())
            elif ext == ".java":
                target_file.write_text(_main_activity_java_source())
            else:
                continue

            if file.resolve() != target_file.resolve() and file.exists():
                file.unlink()
            return


def _main_activity_kotlin_source() -> str:
    return f"""package {TARGET_PACKAGE}

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            \"com.blackpiratex.book/android_widget\",
        ).setMethodCallHandler {{ call, result ->
            when (call.method) {{
                \"refreshReadingWidget\" -> {{
                    ReadingBooksWidgetProvider.refreshAllWidgets(applicationContext)
                    result.success(true)
                }}
                else -> result.notImplemented()
            }}
        }}
    }}
}}
"""


def _main_activity_java_source() -> str:
    return f"""package {TARGET_PACKAGE};

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {{
  @Override
  public void configureFlutterEngine(FlutterEngine flutterEngine) {{
    super.configureFlutterEngine(flutterEngine);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "com.blackpiratex.book/android_widget")
        .setMethodCallHandler((call, result) -> {{
          if ("refreshReadingWidget".equals(call.method)) {{
            ReadingBooksWidgetProvider.Companion.refreshAllWidgets(getApplicationContext());
            result.success(true);
          }} else {{
            result.notImplemented();
          }}
        }});
  }}
}}
"""


def install_android_home_widget_templates() -> None:
    if not TEMPLATES_DIR.exists():
        return

    _copy_template_files(
        TEMPLATES_DIR / "res",
        Path("android/app/src/main/res"),
        placeholder_map={"__PACKAGE__": TARGET_PACKAGE},
    )

    kotlin_base = Path("android/app/src/main/kotlin")
    kotlin_target = kotlin_base.joinpath(*TARGET_PACKAGE.split("."))
    kotlin_target.mkdir(parents=True, exist_ok=True)
    _copy_template_files(
        TEMPLATES_DIR / "kotlin",
        kotlin_target,
        placeholder_map={"__PACKAGE__": TARGET_PACKAGE},
    )


def _copy_template_files(
    source_dir: Path,
    target_dir: Path,
    *,
    placeholder_map: dict[str, str],
) -> None:
    if not source_dir.exists():
        return
    for source in source_dir.rglob("*"):
        if not source.is_file():
            continue
        relative = source.relative_to(source_dir)
        destination = target_dir / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        content = source.read_text()
        for key, value in placeholder_map.items():
            content = content.replace(key, value)
        destination.write_text(content)


def _inject_plugin_line_into_plugins_block(text: str, plugin_line: str) -> str:
    if "plugins {" in text:
        return text.replace("plugins {\n", "plugins {\n" + plugin_line, 1)
    if "plugins\n{" in text:
        return text.replace("plugins\n{\n", "plugins\n{\n" + plugin_line, 1)
    return text


if __name__ == "__main__":
    main()
