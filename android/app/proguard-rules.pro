## Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

## Play Billing / RevenueCat / Install Referrer
-keep class com.android.billingclient.** { *; }
-keep class com.revenuecat.** { *; }
-dontwarn com.revenuecat.**
-keep class com.android.installreferrer.** { *; }
-dontwarn com.android.installreferrer.**

## Firebase / Google Play Services / Maps
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.maps.** { *; }
-keep class com.google.android.libraries.maps.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

## Gson / Retrofit / OkHttp (ShazamKit-Netzwerk, Plugins)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Exceptions
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

## ShazamKit AAR + VibesBox FGS
-keep class com.shazam.** { *; }
-dontwarn com.shazam.**
-keep class com.vibesbox.dj.ShazamForegroundService { *; }
-keep class com.vibesbox.dj.** { *; }

## ML Kit / barcode / camera plugins (falls per reflection)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class io.flutter.plugins.** { *; }

## Kotlin / Coroutines
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }

## Parcelable / Serializable models used by plugins
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

## Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
