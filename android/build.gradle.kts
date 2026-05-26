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
    val configureNamespace = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val namespaceMethod = android.javaClass.getMethod("getNamespace")
                val namespace = namespaceMethod.invoke(android) as? String
                if (namespace.isNullOrBlank()) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    var pkg: String? = null
                    if (manifestFile.exists()) {
                        val manifestText = manifestFile.readText()
                        val packageRegex = """package=["']([^"']+)["']""".toRegex()
                        val match = packageRegex.find(manifestText)
                        if (match != null) {
                            pkg = match.groupValues[1]
                        }
                    }
                    if (pkg.isNullOrBlank()) {
                        pkg = "com.example.${project.name.replace("-", "_").replace(".", "_")}"
                    }
                    setNamespace.invoke(android, pkg)
                }
            } catch (e: Exception) {
                // Ignore if methods do not exist
            }
        }
    }

    val configureJvmTarget = {
        // Override Java compileOptions at the Android extension level
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                    .invoke(compileOptions, JavaVersion.VERSION_17)
                compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                    .invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (e: Exception) {
                // Fallback: set at task level
                project.tasks.withType<JavaCompile>().configureEach {
                    sourceCompatibility = "17"
                    targetCompatibility = "17"
                }
            }
        }
        // Align Kotlin JVM target
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }

    if (project.state.executed) {
        configureNamespace()
        configureJvmTarget()
    } else {
        project.afterEvaluate {
            configureNamespace()
            configureJvmTarget()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
