allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// https://github.com/google/webcrypto.dart/issues/207#issuecomment-3316058846
subprojects {
    plugins.withId("com.android.application") {
        val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
        if (android.namespace.isNullOrEmpty()) {
            android.namespace = group.toString()
        }
        android.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
        android.compileSdkVersion(35)
        android.buildToolsVersion = "35.0.0"
        android.ndkVersion = "28.2.13676358"
    }
    plugins.withId("com.android.library") {
        val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
        if (android.namespace.isNullOrEmpty()) {
            android.namespace = group.toString()
        }
        android.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
        android.compileSdkVersion(35)
        android.buildToolsVersion = "35.0.0"
        android.ndkVersion = "28.2.13676358"
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
