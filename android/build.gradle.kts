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

    // `package:jni` compiles libdartjni.so through CMake, and the linker stamps a
    // GNU build ID into it by default -- a hash that comes out different on every
    // machine even when the library itself does not. Measured on this project: the
    // APK published from CI and one built locally from the same tag differ in
    // exactly 20 bytes, and those 20 bytes are the build ID. Nothing reads it here,
    // and it is the one thing standing between two builds of the same source being
    // byte for byte the same.
    //
    // That matters because of what F-Droid can then do: with `binary:` in the build
    // recipe it rebuilds a release from source, compares it against the APK
    // published here, and on a match ships *this project's* signed APK rather than
    // one of its own -- so somebody moving from a GitHub download to F-Droid keeps
    // their install and their database. The comparison is a signature copy, which
    // v2 signatures make equivalent to byte equality, so 20 bytes is as fatal as a
    // megabyte.
    //
    // Scoped to `jni` rather than applied to every subproject: it is the only module
    // here that builds native code of its own, and a flag that reaches libraries
    // nobody has looked at is a change whose effects nobody has looked at either.
    plugins.withId("com.android.library") {
        if (name == "jni") {
            extensions.configure<LibraryExtension>("android") {
                defaultConfig {
                    externalNativeBuild {
                        cmake {
                            arguments += "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none"
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
