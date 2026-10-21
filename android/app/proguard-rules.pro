# R8 keep rules for the release build (see build.gradle.kts).
# Flutter, Firebase, Google Mobile Ads and most plugins ship their own
# consumer rules; only what they miss is listed here.

# flutter_local_notifications stores scheduled notifications as Gson JSON and
# reads them back by reflection (daily reminder after reboot / app update).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# The Flutter embedding references Play Core (deferred components) classes
# that this app does not include; without these R8 fails with
# "Missing classes detected while running R8".
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
