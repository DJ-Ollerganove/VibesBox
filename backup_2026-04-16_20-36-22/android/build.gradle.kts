import com.android.build.gradle.LibraryExtension

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
                        dsl.namespace = "de.djog.app.${subproject.name.replace("-", "_")}"
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

