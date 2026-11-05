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

# 2) MainActivity (player em segundo plano + cadeado/fixar tela)
KOTLIN_ACTIVITY = """import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Permissão de notificação (Android 13+), sem plugin extra
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "webradio/notif")
            .setMethodCallHandler { call, result ->
                try {
                    val needs = android.os.Build.VERSION.SDK_INT >= 33
                    when (call.method) {
                        "granted" -> result.success(
                            !needs || checkSelfPermission("android.permission.POST_NOTIFICATIONS") ==
                                android.content.pm.PackageManager.PERMISSION_GRANTED)
                        "request" -> {
                            if (needs) requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 7701)
                            result.success(true)
                        }
                        "settings" -> {
                            val i = android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            }
        // Modo do áudio do Android: 1 = tocando, 2 = em ligação, 3 = chamada de app (WhatsApp...)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "webradio/audio")
            .setMethodCallHandler { call, result ->
                if (call.method == "mode") {
                    try {
                        val am = getSystemService(android.content.Context.AUDIO_SERVICE) as android.media.AudioManager
                        result.success(am.mode)
                    } catch (e: Exception) {
                        result.success(0)
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "webradio/lock")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "pin" -> { startLockTask(); result.success(true) }
                        "unpin" -> { stopLockTask(); result.success(true) }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
"""
acts = list((android / "app/src/main").rglob("MainActivity.kt")) + list(
    (android / "app/src/main").rglob("MainActivity.java"))
if not acts:
    sys.exit("MainActivity não encontrada")
for act in acts:
    text = act.read_text()
    pkg = re.search(r"^package\s+([\w.]+)", text, re.M).group(1)
    if act.suffix == ".kt":
        act.write_text(
            f"package {pkg}\n\n" + KOTLIN_ACTIVITY)
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
