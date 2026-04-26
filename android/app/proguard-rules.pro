# Keep org.tensorflow classes
-keep class org.tensorflow.** { *; }
-keepclassmembers class org.tensorflow.** { *; }

# Keep TensorFlow Lite classes
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }

# Keep specific gpu classes that are causing R8 errors
-keep class org.tensorflow.lite.gpu.** { *; }

# Ignore warnings of missing tflite-gpu classes if you don't use gpu delegates
-dontwarn org.tensorflow.lite.gpu.**
