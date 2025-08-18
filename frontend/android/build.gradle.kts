allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Set custom root build directory (e.g., "../../build")
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

// Set custom build directory for all subprojects
subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    layout.buildDirectory.set(newSubprojectBuildDir)

    // Ensure subprojects depend on `:app` evaluation if needed
    evaluationDependsOn(":app")
}

// Register a clean task that deletes the custom build directory
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
