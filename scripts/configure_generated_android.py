from __future__ import annotations

import re
from pathlib import Path


TARGET_PACKAGE = "com.blackpiratex.book"
TARGET_APP_LABEL = "BlackPirateX Book tracker"


def main() -> None:
    patch_manifest()
    patch_gradle()
    patch_main_activity()


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

    manifest.write_text(text)


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
            text = patch_kotlin_gradle_signing(text)
        else:
            text = patch_groovy_gradle_signing(text)
        path.write_text(text)


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
            text = file.read_text()
            if not re.search(r"^package\s+[\w.]+", text, flags=re.MULTILINE):
                continue
            text = re.sub(
                r"^package\s+[\w.]+",
                f"package {TARGET_PACKAGE}",
                text,
                count=1,
                flags=re.MULTILINE,
            )

            ext = file.suffix
            target_dir = base.joinpath(*TARGET_PACKAGE.split("."))
            target_dir.mkdir(parents=True, exist_ok=True)
            target_file = target_dir / f"MainActivity{ext}"
            target_file.write_text(text)

            if file.resolve() != target_file.resolve():
                file.unlink()
            return


if __name__ == "__main__":
    main()
