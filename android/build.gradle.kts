import com.android.build.gradle.LibraryExtension
import java.io.File
import org.gradle.api.JavaVersion
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

// image_gallery_saver 2.0.3: veraltetes package= im Library-Manifest bricht AGP 8+ (processReleaseManifest).
// Einmal pro Build-Zyklus aus dem Pub-Cache entfernen; Namespace kommt unten über finalizeDsl.
gradle.projectsLoaded {
    rootProject.allprojects.forEach { proj ->
        if (proj.name == "image_gallery_saver") {
            val manifest = File(proj.projectDir, "src/main/AndroidManifest.xml")
            if (manifest.isFile) {
                val text = manifest.readText()
                val stripped = text.replace(Regex("""\s+package="[^"]*"\s*"""), "\n  ")
                if (stripped != text) {
                    manifest.writeText(stripped)
                }
            }
            // Embedding v2 only: alter Import verweist auf entfernte v1-API (Flutter 3.38)
            val pluginKt = File(
                proj.projectDir,
                "src/main/kotlin/com/example/imagegallerysaver/ImageGallerySaverPlugin.kt",
            )
            if (pluginKt.isFile) {
                val kt = pluginKt.readText()
                val fixed = kt.replace(
                    Regex("import io\\.flutter\\.plugin\\.common\\.PluginRegistry\\.Registrar\\r?\\n"),
                    "",
                )
                if (fixed != kt) {
                    pluginKt.writeText(fixed)
                }
            }
        }
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    
    // Stelle sicher, dass alle Subprojekte Java 17 verwenden
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
        options.compilerArgs.add("-Xlint:-options") // Unterdrücke Warnungen über veraltete Optionen
    }
}

// image_gallery_saver: altes Plugin setzt Java 8; Kotlin folgt Root (17) → JVM-Ziel angleichen
subprojects {
    val p = project
    val fixImageGalleryJvm: () -> Unit = {
        if (p.name == "image_gallery_saver") {
            p.extensions.findByType(LibraryExtension::class.java)?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
            p.tasks.withType<KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
            }
        }
    }
    if (p.state.executed) fixImageGalleryJvm() else p.afterEvaluate { fixImageGalleryJvm() }
}

// Alle Android-Library-Plugins (z. B. image_gallery_saver) mit compileSdk 36 bauen (lStar / Material 3)
subprojects {
    val configureCompileSdk: () -> Unit = {
        if (project.plugins.hasPlugin("com.android.library")) {
            project.extensions.findByType(LibraryExtension::class.java)?.apply {
                compileSdk = 36
            }
        }
    }
    if (state.executed) configureCompileSdk() else afterEvaluate { configureCompileSdk() }
}

// Namespace-Fix: Externen Paketen ohne Namespace automatisch einen zuweisen
subprojects {
    val subproject = this
    if (subproject.name != "app") {
        project.plugins.withType<com.android.build.gradle.BasePlugin> {
            project.extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
                finalizeDsl { dsl ->
                    if (dsl.namespace == null) {
                        dsl.namespace = when (subproject.name) {
                            "image_gallery_saver" -> "com.example.imagegallerysaver"
                            else -> "de.djog.app.${subproject.name.replace("-", "_")}"
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

