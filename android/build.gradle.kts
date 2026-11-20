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
    // Align Android library plugin compileSdk (e.g. flutter_webrtc defaults to 31) with :app (36)
    // via AGP's androidComponents.finalizeDsl so compileSdk is updated after the plugin DSL is
    // evaluated and before AGP locks the DSL / creates checkReleaseAarMetadata.
    val subproject = this
    subproject.plugins.withId("com.android.library") {
        val alignCompileSdk: (Any) -> Unit = { libAndroid ->
            val appCompileSdk = rootProject.findProject(":app")
                ?.extensions
                ?.findByName("android")
                ?.let { appAndroid ->
                    runCatching {
                        appAndroid.javaClass.getMethod("getCompileSdk").invoke(appAndroid) as? Int
                    }.getOrNull()
                }
                ?: 36

            val currentCompileSdk = runCatching {
                libAndroid.javaClass.getMethod("getCompileSdk").invoke(libAndroid) as? Int
            }.getOrNull()

            if ((currentCompileSdk ?: 0) < appCompileSdk) {
                val setCompileSdk = libAndroid.javaClass.methods.firstOrNull { method ->
                    method.name == "setCompileSdk" &&
                        method.parameterCount == 1 &&
                        (method.parameterTypes[0] == Integer::class.java ||
                            method.parameterTypes[0] == Int::class.javaPrimitiveType)
                }
                if (setCompileSdk != null) {
                    setCompileSdk.invoke(libAndroid, appCompileSdk)
                } else {
                    runCatching {
                        libAndroid.javaClass
                            .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                            .invoke(libAndroid, appCompileSdk)
                    }
                }
            }
        }

        val androidComponents = subproject.extensions.findByName("androidComponents")
        val actionFinalize = androidComponents?.javaClass?.methods?.firstOrNull { method ->
            method.name == "finalizeDsl" &&
                method.parameterCount == 1 &&
                org.gradle.api.Action::class.java.isAssignableFrom(method.parameterTypes[0])
        }
        if (actionFinalize != null) {
            actionFinalize.invoke(
                androidComponents,
                object : org.gradle.api.Action<Any> {
                    override fun execute(libAndroid: Any) {
                        alignCompileSdk(libAndroid)
                    }
                },
            )
        } else {
            val fnFinalize = androidComponents?.javaClass?.methods?.firstOrNull { method ->
                method.name == "finalizeDsl" &&
                    method.parameterCount == 1 &&
                    kotlin.jvm.functions.Function1::class.java.isAssignableFrom(method.parameterTypes[0])
            }
            fnFinalize?.invoke(androidComponents, alignCompileSdk)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
