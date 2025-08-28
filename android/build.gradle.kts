allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 🔹 Redirect build output to ../../build
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // 🔹 Ensure app module is evaluated first
    project.evaluationDependsOn(":app")
}

// 🔹 Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
