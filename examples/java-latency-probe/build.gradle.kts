plugins {
    java
}

group = "com.example.lowlat"
version = "1.0.0"
description = "Pinned busy-spin ping-pong probe: thread affinity + huge pages + NUMA"

// Every library, including transitive ones, must be approved by the project owner.
// Adding a dependency means adding it here in the same change, after approval.
val approvedDependencies = setOf(
    "org.hdrhistogram:HdrHistogram:2.2.2", // latency distribution with no allocation on the hot path
)

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

dependencies {
    implementation("org.hdrhistogram:HdrHistogram:2.2.2")
}

tasks.withType<JavaCompile>().configureEach {
    options.release = 25
    options.encoding = "UTF-8"
    options.compilerArgs.addAll(listOf("-Xlint:all", "-Werror"))
}

val verifyApprovedDependencies by tasks.registering {
    group = "verification"
    description = "Fails if any resolved dependency, direct or transitive, is not in approvedDependencies."
    val resolved = listOf(configurations.compileClasspath, configurations.runtimeClasspath).map { configuration ->
        configuration.flatMap { it.incoming.artifacts.resolvedArtifacts }
    }
    val approved = approvedDependencies
    inputs.property("approved", approved)
    doLast {
        val found = resolved.flatMap { it.get() }
            .mapNotNull { it.id.componentIdentifier as? ModuleComponentIdentifier }
            .map { "${it.group}:${it.module}:${it.version}" }
            .toSortedSet()
        val unapproved = found - approved
        if (unapproved.isNotEmpty()) {
            throw GradleException(
                "Unapproved dependencies (get the owner's approval, then add them to approvedDependencies):\n  " +
                    unapproved.joinToString("\n  ")
            )
        }
    }
}

tasks.compileJava { dependsOn(verifyApprovedDependencies) }
tasks.check { dependsOn(verifyApprovedDependencies) }

// build/lib/*.jar so bin/launch can use a plain classpath
val copyRuntimeLibs by tasks.registering(Sync::class) {
    from(configurations.runtimeClasspath)
    into(layout.buildDirectory.dir("lib"))
}

tasks.assemble { dependsOn(copyRuntimeLibs) }
