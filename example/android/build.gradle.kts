allprojects {
    repositories {
        google()
        mavenCentral()
        // The Wolvy Android SDK from publishToMavenLocal while it is unreleased (gradle.properties).
        if (providers.gradleProperty("wolvy.useMavenLocal").orNull == "true") mavenLocal()
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
