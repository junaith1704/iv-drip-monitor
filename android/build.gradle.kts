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
}

subprojects {
    if (project.name == "flutter_ringtone_player") {
        val configurePlugin = {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    method.invoke(android, 34)
                } catch (e: Exception) {
                }
            }
            project.tasks.findByName("checkDebugAarMetadata")?.enabled = false
            project.tasks.findByName("checkReleaseAarMetadata")?.enabled = false
        }
        if (project.state.executed) {
            configurePlugin()
        } else {
            project.afterEvaluate {
                configurePlugin()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
