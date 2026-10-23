import os
import re
import sys


def fail(msg):
    print("PATCH ERROR: " + msg)
    sys.exit(1)


# ---------- Gradle: desugaring ----------
kts = os.path.exists("android/app/build.gradle.kts")
gp = "android/app/build.gradle.kts" if kts else "android/app/build.gradle"
if not os.path.exists(gp):
    fail("app build.gradle not found")
s = open(gp, encoding="utf-8").read()
if "desugar_jdk_libs" not in s:
    if "compileOptions {" not in s:
        fail("compileOptions block not found in " + gp)
    if kts:
        s = s.replace("compileOptions {",
                      "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    else:
        s = s.replace("compileOptions {",
                      "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    open(gp, "w", encoding="utf-8").write(s)
print("gradle ok:", gp)
print("minSdk:", [l.strip() for l in s.splitlines() if "minSdk" in l])

# ---------- Manifest ----------
m = "android/app/src/main/AndroidManifest.xml"
if not os.path.exists(m):
    fail("AndroidManifest.xml not found")
x = open(m, encoding="utf-8").read()

perms = [
    "INTERNET", "POST_NOTIFICATIONS", "SCHEDULE_EXACT_ALARM",
    "USE_EXACT_ALARM", "USE_FULL_SCREEN_INTENT",
    "RECEIVE_BOOT_COMPLETED", "WAKE_LOCK", "VIBRATE",
]
add = ""
for n in perms:
    if ('android.permission.%s"' % n) not in x:
        add += '    <uses-permission android:name="android.permission.%s"/>\n' % n
if add:
    if not re.search(r"<manifest[^>]*>", x):
        fail("<manifest> tag not found")
    x = re.sub(r"(<manifest[^>]*>)", lambda mt: mt.group(1) + "\n" + add, x, count=1)

if "showWhenLocked" not in x:
    if "<activity" not in x:
        fail("<activity> not found")
    x = x.replace("<activity",
                  '<activity android:showWhenLocked="true" android:turnScreenOn="true"', 1)

x = re.sub(r'android:label="[^"]*"', 'android:label="NOON"', x, count=1)

if "ScheduledNotificationReceiver" not in x:
    if "</application>" not in x:
        fail("</application> not found")
    recv = """    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED"/>
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
        </intent-filter>
    </receiver>
"""
    x = x.replace("</application>", recv + "</application>", 1)

open(m, "w", encoding="utf-8").write(x)

# ---------- تحقق نهائي ----------
x = open(m, encoding="utf-8").read()
for n in perms:
    if ('android.permission.%s"' % n) not in x:
        fail("permission missing: " + n)
for need in ("showWhenLocked", "ScheduledNotificationReceiver",
             "ScheduledNotificationBootReceiver"):
    if need not in x:
        fail("manifest missing: " + need)
print("manifest ok")
