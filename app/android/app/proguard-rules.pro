# flutter_local_notifications usa Gson con tipos genéricos.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
# Plugin de alarmas.
-keep class com.gdelataillade.alarm.** { *; }
# ONNX Runtime (detección de «Hey Ally»): usa JNI y reflexión.
-keep class ai.onnxruntime.** { *; }
