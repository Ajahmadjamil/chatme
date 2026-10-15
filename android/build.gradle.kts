plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
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

// flutter_callkit_incoming asks Gradle for a Java 17 toolchain, which fails
// when only a newer JDK (e.g. Android Studio's JDK 21) is installed.
// Compile it with the JDK that runs Gradle instead — the plugin keeps
// source/targetCompatibility 17, so the output is the same.
// Must stay above evaluationDependsOn(":app") so it is registered in time.
subprojects {
    if (name == "flutter_callkit_incoming") {
        val useRunningJdk: Project.() -> Unit = {
            extensions.findByType<JavaPluginExtension>()?.toolchain?.languageVersion?.set(
                JavaLanguageVersion.of(JavaVersion.current().majorVersion)
            )
        }
        if (state.executed) useRunningJdk() else afterEvaluate { useRunningJdk() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
