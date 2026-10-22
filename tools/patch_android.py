import os, re

# ---- Gradle: desugaring (needed by notification libraries) ----
kts = os.path.exists("android/app/build.gradle.kts")
p = "android/app/build.gradle.kts" if kts else "android/app/build.gradle"
s = open(p).read()
if kts:
    s = s.replace("compileOptions {",
                  "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
else:
    s = s.replace("compileOptions {",
                  "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
    s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
open(p, "w").write(s)
print("gradle patched:", p)
print("minSdk lines:", [l.strip() for l in s.splitlines() if "minSdk" in l])

# ---- Manifest: permissions, lock-screen flags, app name ----
m = "android/app/src/main/AndroidManifest.xml"
x = open(m).read()
perms = [
    "INTERNET", "POST_NOTIFICATIONS", "SCHEDULE_EXACT_ALARM",
    "USE_EXACT_ALARM", "USE_FULL_SCREEN_INTENT",
    "RECEIVE_BOOT_COMPLETED", "WAKE_LOCK", "VIBRATE",
]
add = "".join(
    '    <uses-permission android:name="android.permission.%s"/>\n' % n
    for n in perms
)
x = re.sub(r"(<manifest[^>]*>\n)", lambda mt: mt.group(1) + add, x, count=1)
x = x.replace("<activity",
              '<activity android:showWhenLocked="true" android:turnScreenOn="true"', 1)
x = re.sub(r'android:label="[^"]*"', 'android:label="NOON"', x, count=1)
open(m, "w").write(x)
print("manifest patched")

# ---- Manifest: notification receivers ----
x = open(m).read()
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
open(m, "w").write(x)
print("receivers added")
