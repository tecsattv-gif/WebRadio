"""Ajusta a pasta android/ gerada pelo `flutter create` (roda no GitHub Actions).

- copia android_overlay/ (manifesto, Android Auto) por cima de android/
- troca a MainActivity para AudioServiceActivity (player em segundo plano)
- configura a assinatura fixa do APK se android/app/release.jks existir
"""
import os
import pathlib
import re
import shutil
import sys

root = pathlib.Path(__file__).resolve().parent.parent
android = root / "android"
overlay = root / "android_overlay"

if not android.exists():
    sys.exit("android/ não existe: rode flutter create antes")

# 1) overlay
for src in overlay.rglob("*"):
    if src.is_file():
        dst = android / src.relative_to(overlay)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        print("copiado", dst.relative_to(root))

# 2) MainActivity
acts = list((android / "app/src/main").rglob("MainActivity.kt")) + list(
    (android / "app/src/main").rglob("MainActivity.java"))
if not acts:
    sys.exit("MainActivity não encontrada")
for act in acts:
    text = act.read_text()
    pkg = re.search(r"^package\s+([\w.]+)", text, re.M).group(1)
    if act.suffix == ".kt":
        act.write_text(
            f"package {pkg}\n\n"
            "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
            "class MainActivity : AudioServiceActivity()\n")
    else:
        act.write_text(
            f"package {pkg};\n\n"
            "import com.ryanheise.audioservice.AudioServiceActivity;\n\n"
            "public class MainActivity extends AudioServiceActivity {}\n")
    print("MainActivity ->", act.relative_to(root))

# 3) assinatura
keystore = android / "app" / "release.jks"
kts = android / "app" / "build.gradle.kts"
groovy = android / "app" / "build.gradle"
if keystore.exists():
    if kts.exists():
        g = kts.read_text()
        block = '''    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = "webradio"
            keyPassword = System.getenv("KEYSTORE_PASSWORD")
        }
    }

    buildTypes {'''
        if 'create("release")' not in g:
            g = g.replace("    buildTypes {", block, 1)
        g = g.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        kts.write_text(g)
        print("assinatura configurada (kts)")
    elif groovy.exists():
        g = groovy.read_text()
        block = '''    signingConfigs {
        release {
            storeFile file("release.jks")
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias "webradio"
            keyPassword System.getenv("KEYSTORE_PASSWORD")
        }
    }

    buildTypes {'''
        if "signingConfigs {" not in g:
            g = g.replace("    buildTypes {", block, 1)
        g = g.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
        g = g.replace('signingConfig = signingConfigs.debug', 'signingConfig = signingConfigs.release')
        groovy.write_text(g)
        print("assinatura configurada (groovy)")
else:
    print("AVISO: sem chave de assinatura (segredo WEBRADIO_KEYSTORE) - APK assinado com chave de teste")
