# imgn parent

Shared Maven build configuration for all `be.imgn` projects. One artifact,
published as two files:

| File | What it is |
|---|---|
| `be.imgn.parent:parent:pom` | The parent POM: dependency management, plugin versions, quality gates, release setup. |
| `be.imgn.parent:parent:jar:config` | A classified jar built from this repo's `src/main/resources`, carrying `checkstyle.xml` and `checkstyle-suppressions.xml` on the plugin classpath. |

A `pom`-packaged artifact cannot carry classpath resources, so the rulesets ride
along as a *classified attachment* to the same coordinates rather than as a
separate artifact.

## Building

```bash
./mvnw install
```

Builds go through the wrapper, never a locally installed `mvn`, so everyone runs
the same Maven. It is pinned to the latest stable release, `3.9.16` — the same
value as the enforcer floor `${minimum.maven.version}`, so the pinned Maven can
never be older than the minimum the build demands.

A child generates its own wrapper once, with no arguments and no configuration
of its own — version, distribution type and Maven version are all inherited:

```bash
mvn wrapper:wrapper   # then use ./mvnw from here on
```

Commit `mvnw`, `mvnw.cmd` and `.mvn/wrapper/maven-wrapper.properties`.
`distributionType=only-script` keeps the wrapper jar out of the repository — the
script downloads Maven itself.

Two consequences of the POM carrying its own config jar, both handled:

- **Checkstyle does not run on this POM.** It would need a jar that does not
  exist until `package` of the same build. The `checkstyle-for-java-projects`
  profile activates on `src/main/java`, which this repo has not and every real
  project has.
- **`imgn.config.version` is a literal, not `${project.version}`.** In an
  inherited plugin dependency that expression resolves against the *child*, so
  every child would look for a config jar under its own version. The property
  must be bumped on release; a non-inherited enforcer rule fails the build here
  if it ever drifts from `<version>`.

## Using it from a project

Child projects are *not* listed in a `<modules/>` block. They reference the
parent by coordinates and get everything out of the box:

```xml
<parent>
  <groupId>be.imgn.parent</groupId>
  <artifactId>parent</artifactId>
  <version>2026-08</version>
  <relativePath/>
</parent>
```

The empty `<relativePath/>` matters — without it Maven looks for the parent POM
in `../pom.xml` and fails.

**`<licenses>` is inherited.** Every child that does not override it publishes a
POM declaring Apache-2.0, this POM's licence. A project that is proprietary or
licensed differently must declare its own `<licenses>` block — silence means
agreement here.

## Quality gates

Every child gets these without declaring anything:

| Phase | Tool | What it does |
|---|---|---|
| `validate` | Enforcer | Maven/Java version floors, no dynamic versions, dependency convergence |
| `validate` | Spotless | Auto-formats with Palantir Java Format |
| `validate` | Checkstyle | Enforces the shared ruleset |
| `compile` | Error Prone + NullAway | Static analysis and null-safety, as compile errors |

Spotless is declared before Checkstyle on purpose: both bind to `validate`, and
Maven runs plugins in declaration order within a phase, so code is formatted
before it is checked.

`dependency:analyze-only` runs at `verify` with `failOnWarning`, so a dependency
that is declared but unused — or used but only present transitively — fails the
build. Two exemptions are configured centrally: `jspecify`, whose annotations
leave no trace in bytecode and so always look unused, and the JUnit artifacts,
because depending on the `junit-jupiter` aggregate while importing from
`junit-jupiter-api` is the idiomatic usage.

## Testing this POM

`src/it/` holds real projects built against the POM under construction, run by
`maven-invoker-plugin` on every `./mvnw verify`:

| Project | Expected |
|---|---|
| `clean-project` | builds green |
| `checkstyle-violation` | **fails** — magic number |
| `nullaway-violation` | **fails** — null passed where non-null required |

The two failing projects are the point: if a gate ever stops enforcing, its
build succeeds, which does not match `invoker.buildResult = failure`, and the
integration test fails. Nothing else in this repository proves the gates still
bite.

Maven Failsafe is configured in `<pluginManagement>` but not activated. A module
with integration tests opts in — no version or configuration needed:

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-failsafe-plugin</artifactId>
</plugin>
```

## Checkstyle in the IDE

The build reads the ruleset off the plugin classpath, but IDE plugins need a
real file and cannot read one from inside a jar. Every project therefore unpacks
it during `initialize`:

```
target/checkstyle/be/imgn/build/checkstyle.xml
target/checkstyle/be/imgn/build/checkstyle-suppressions.xml
```

In IntelliJ: **Settings → Tools → Checkstyle → +** → *Use a local Checkstyle
file* → `$PROJECT_DIR$/target/checkstyle/be/imgn/build/checkstyle.xml`. The
ruleset references `${checkstyle.suppressions.file}`, so the plugin asks for
that property — point it at `checkstyle-suppressions.xml` next to it. Set the
Checkstyle version to match `${checkstyle.version}`, or the IDE and the build
will disagree about what the rules mean.

The path is relative to the project, and identical everywhere, so
`.idea/checkstyle-idea.xml` can be committed and shared.

Two caveats. The files only exist after a build, so a fresh clone shows a broken
config path until one runs. And `mvn validate` is not enough — `validate` runs
*before* `initialize`. Any ordinary build reaches it.

In this repo itself there is nothing to unpack: the files are the sources, at
`src/main/resources/be/imgn/build/`. Point the IDE straight at them.

## Strict compilation

Every warning is on and every warning is fatal:

```xml
<parameters>true</parameters>
<showDeprecation>true</showDeprecation>
<showWarnings>true</showWarnings>
<compilerArgs>
  <arg>-Xlint:all</arg>
  <arg>-Werror</arg>
</compilerArgs>
```

`-Xlint:all` has no exclusions — notably `serial` and `processing` are *not*
muted. Two consequences worth knowing before a first build against this parent:

- Every `Serializable` class needs a `serialVersionUID`, exceptions included:
  `[serial] serializable class Ser has no definition of serialVersionUID`.
- A module with annotations on the source path but no processor claiming them
  gets `No processor claimed any of these annotations`, which is now fatal.

Fix those per module rather than muting the category globally.

`-Werror` also promotes Error Prone's WARNING-level checks to build failures,
so for any Error Prone check there is no useful middle ground between ERROR and
OFF.

`<parameters>true</parameters>` writes real parameter names into the bytecode —
a `MethodParameters` attribute holding `locale`, not `arg0` — which frameworks
doing reflective binding rely on.

## Banning `System.out` / `System.err`

Error Prone's [`SystemOut`](https://errorprone.info/bugpattern/SystemOut) check
fails the build on any print to standard out or standard error:

```
[SystemOut] Production code should not print to standard out or standard error.
```

It works on the AST, so — unlike a regex rule — commented-out calls and string
literals mentioning `System.out.print` are not flagged.

Command-line tools print to stdout by design. Two ways to allow it.

**A whole module** — set the property in the project's own `<properties>`:

```xml
<properties>
  <errorprone.systemout.severity>OFF</errorprone.systemout.severity>
</properties>
```

**A single method or class** — annotate it:

```java
@SuppressWarnings("SystemOut")
public static void main(String[] args) {
    System.out.println("...");
}
```

Prefer the annotation. It keeps the ban in force for the rest of the module and
marks the one place where printing is intentional. Reach for the property only
when a module is *entirely* a command-line tool.

Note there is no warn-only middle ground: the compiler runs with `-Werror`, so
the check is effectively ERROR or OFF.

## Lombok is banned

Because a `.java` file using Lombok is no longer Java. What you read is not what
compiles: methods that appear in no source file, a class whose real shape exists
only after an AST rewrite. Every tool that reads source rather than bytecode —
Checkstyle here, but also code review, grep, and your own eyes — is looking at
something other than the program.

Two layers, because one has a hole.

The Enforcer bans the whole `org.projectlombok` group — which also covers
`lombok-mapstruct-binding` and similar — and fails at `validate`, before
anything compiles:

```
Rule: BannedDependencies failed with message:
Lombok is not allowed.
   org.projectlombok:lombok:jar:1.18.44 <--- banned via the exclude/include list
```

Checkstyle's `IllegalImport` additionally rejects `lombok` imports. That is not
redundant: Lombok added through the compiler's `annotationProcessorPaths` is not
a project dependency, so the Enforcer never sees it, and only the import ban
catches it:

```
Lomb.java:3:1: Importation illégale - lombok.Data. [IllegalImport]
```

Error Prone is no help here — it has no Lombok check, and it sees the AST after
Lombok has already run.

## No fully qualified names outside imports

Error Prone's
[`UnnecessarilyFullyQualified`](https://errorprone.info/bugpattern/UnnecessarilyFullyQualified)
check is on as an error. Write `List`, not `java.util.List`:

```
[UnnecessarilyFullyQualified] The fully qualified name 'java.util.List' is
unambiguous to the compiler if imported, prefer using the name 'List'.
```

It is AST-based, so comments, javadoc, string literals and text blocks are
never flagged — only real type references are.

It is also conservative: it fires only when importing the type would actually
be unambiguous. If a competing simple name appears anywhere in the same file
(`java.util.List` imported, `java.awt.List` used), the qualified form is left
alone, because there is no import that would work.

Suppress a deliberate case:

```java
@SuppressWarnings("UnnecessarilyFullyQualified")
```

## Null-safety

NullAway treats `be.imgn` as annotated, meaning every reference in your code is
non-null unless marked `org.jspecify.annotations.@Nullable`:

```java
public static String greet(@Nullable String name) {
    String safe = name == null ? "world" : name;
    return "Hello, " + safe;
}
```

A project living outside that package tree overrides
`nullaway.annotated.packages`.

## Checking for updates

Version rules are declared inline in `versions-maven-plugin`'s configuration —
nothing else reads them, so they need not travel in the config jar. They filter
out milestones, release candidates, alphas, betas and dated snapshots, so these
only propose stable releases:

```bash
mvn versions:display-dependency-updates
mvn versions:display-plugin-updates
mvn versions:display-property-updates
```

Error Prone, NullAway and Palantir Java Format are invisible to those goals —
the first two live in `annotationProcessorPaths`, the third is inline in the
Spotless configuration. Check them against Maven Central directly.

## CI

`.github/workflows/ci.yml` runs `./mvnw clean verify` on every push and pull
request, against JDK 25 and the newest JDK. Both are built because Error Prone
reflects into javac internals and is the first thing to break on a new release.
Integration test logs are uploaded when a build fails.

`.github/dependabot.yml` opens weekly PRs for Maven dependencies and Actions, so
upgrades arrive continuously rather than in bulk.

## Releasing

Manual, via the **Release** workflow in GitHub Actions. It takes the release
version and the next development version, then sets both, verifies, publishes,
tags and pushes.

Locally the equivalent is:

```bash
./mvnw -Prelease deploy
```

The `release` profile attaches sources and javadoc, signs with GPG, publishes
via the Central plugin, and turns on enforcement that rejects `SNAPSHOT`
versions and dependencies. During normal development those release-only rules
are skipped by the auto-activated `dev-defaults` profile. `autoPublish` is
false, so a deployment waits in the Central portal for a human to release it.

**`maven-release-plugin` is deliberately not used by the workflow.**
`release:prepare` rewrites `<version>` but knows nothing about
`imgn.config.version`, so the enforcer rule guarding the two would fail the
release. The workflow sets both with `versions:set` and
`versions:set-property`, then tags by hand.

### Required repository secrets

| Secret | What it is |
|---|---|
| `CENTRAL_TOKEN_USERNAME` | Central Portal user token, name half |
| `CENTRAL_TOKEN_PASSWORD` | Central Portal user token, secret half |
| `GPG_PRIVATE_KEY` | ASCII-armoured private key, exported with `gpg --armor --export-secret-keys` |
| `GPG_PASSPHRASE` | Passphrase for that key |

The public half of the signing key must be published to a keyserver, or Central
will reject the bundle.

### Before the first publish

- Replace every `CHANGE_ME` in `<url>`, `<scm>` and `<developers>`. Central
  validates these and will refuse the deployment otherwise.
- Confirm `be.imgn` is a namespace you have verified in the Central portal.
  Verifying `be.imgn` covers `be.imgn.parent` and every other subgroup.
- Check whether Central demands `-sources` and `-javadoc` jars for the attached
  `config` classifier. A `pom`-packaged project is normally exempt, but this one
  ships a jar alongside the POM.
