#!/usr/bin/env python3
"""Ajusta o projeto Android gerado pelo `flutter create` para o Master Music."""
import glob
import os
import re

APP = "android/app"
PKG = "com.mastermusic.master_music"

# ---------- AndroidManifest ----------
mp = f"{APP}/src/main/AndroidManifest.xml"
s = open(mp, encoding="utf-8").read()

if "xmlns:tools" not in s:
    s = s.replace("<manifest ", '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)

perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
"""
s = s.replace("<application", perms + "    <application", 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Master Music"', s, count=1)

https_query = (
    '<intent><action android:name="android.intent.action.VIEW"/>'
    '<data android:scheme="https"/></intent>'
)
if "<queries>" in s:
    s = s.replace("<queries>", "<queries>\n        " + https_query, 1)
else:
    s = s.replace("</manifest>", f"    <queries>\n        {https_query}\n    </queries>\n</manifest>", 1)

service = """
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService"/>
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON"/>
            </intent-filter>
        </receiver>
"""
s = s.replace("</application>", service + "    </application>", 1)
open(mp, "w", encoding="utf-8").write(s)

# ---------- MainActivity ----------
for f in glob.glob(f"{APP}/src/main/**/MainActivity.*", recursive=True):
    os.remove(f)
kdir = f"{APP}/src/main/kotlin/com/mastermusic/master_music"
os.makedirs(kdir, exist_ok=True)
with open(f"{kdir}/MainActivity.kt", "w", encoding="utf-8") as f:
    f.write(
        f"package {PKG}\n\n"
        "import com.ryanheise.audioservice.AudioServiceActivity\n\n"
        "class MainActivity : AudioServiceActivity()\n"
    )

# ---------- build.gradle(.kts) ----------
kts = os.path.exists(f"{APP}/build.gradle.kts")
gp = f"{APP}/build.gradle.kts" if kts else f"{APP}/build.gradle"
g = open(gp, encoding="utf-8").read()

if kts:
    placeholder = f'        manifestPlaceholders["appAuthRedirectScheme"] = "{PKG}"\n'
    g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", g)
else:
    placeholder = f"        manifestPlaceholders = [appAuthRedirectScheme: '{PKG}']\n"
    g = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", g)

g, n = re.subn(r"(defaultConfig\s*\{\n)", r"\1" + placeholder.replace("\\", "\\\\"), g, count=1)
assert n == 1, "defaultConfig nao encontrado"
open(gp, "w", encoding="utf-8").write(g)
print("Android patch OK")
