# ML Kit text recognition: only the Latin model is bundled (receipts). The
# plugin also references the Chinese, Devanagari, Japanese and Korean models;
# they are left out on purpose, so R8 is told not to look for them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
