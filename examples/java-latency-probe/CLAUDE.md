# java-latency-probe

- Build tool is **Gradle** (Kotlin DSL, wrapper `./gradlew`). Never add Maven files (`pom.xml`, `mvnw`).
- Toolchain: `.sdkmanrc` (`sdk env`). Java 25.
- **No new libraries without the owner's explicit approval.** Approved dependencies are listed in
  `approvedDependencies` in `build.gradle.kts`; `verifyApprovedDependencies` fails the build for anything else,
  and `gradle/verification-metadata.xml` pins every artifact's checksum.
- Native calls (thread affinity, etc.) use the FFM API (`java.lang.foreign`), not third-party wrappers.
