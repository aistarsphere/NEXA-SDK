# R8 keep rules for the LABEEB release build (shrink + obfuscate).
# Flutter and its plugins ship their own consumer rules; these cover native
# libraries that are reached through JNI or reflection.

# LiveKit / WebRTC (flutter_webrtc, livekit_client): JNI callbacks by name.
-keep class org.webrtc.** { *; }
-keep class io.livekit.** { *; }
-dontwarn org.webrtc.**
-dontwarn io.livekit.**

# ONNX Runtime (wake word + speaker verification): loaded through JNI.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# The assistant plugin: services and receivers are named in the manifest.
-keep class com.nexa.assistant.** { *; }

# Keep line numbers for crash reports (mapping.txt is uploaded with the build).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
