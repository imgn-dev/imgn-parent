# imgn parent

Shared Maven build configuration for all `be.imgn` projects. Two artifacts,
published as three files:

| File | What it is |
|---|---|
| `be.imgn.parent:parent:pom` | The parent POM: plugin versions, quality gates, release setup. Inherit it. |
| `be.imgn.parent:parent:jar:config` | A classified jar built from this repo's `src/main/resources`, carrying `checkstyle.xml` and `checkstyle-suppressions.xml` on the plugin classpath. |
| `be.imgn.parent:bom:pom` | The library version catalogue. Import it. |

A `pom`-packaged artifact cannot carry classpath resources, so the rulesets ride
along as a *classified attachment* to the parent's coordinates rather than as a
separate artifact.

The BOM is separate for the opposite reason: it is the one thing a project should
be able to take *without* taking the build configuration. See
[Managed dependency versions](#managed-dependency-versions).

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

## Managed dependency versions

Two artifacts, on purpose.

**`be.imgn.parent:parent`** — the build parent. Inheriting it brings the quality
gates, and the few versions those gates depend on:

| | |
|---|---|
| Testing | `junit-bom`, `assertj-bom`, `archunit-junit6`, `jqwik` |
| Annotations | `jspecify`, `error_prone_annotations` |

**`be.imgn.parent:bom`** — the library catalogue. Opt in with an `<import>`:

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>be.imgn.parent</groupId>
      <artifactId>bom</artifactId>
      <version>2026-09</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```

| | |
|---|---|
| JSON | `jackson-bom` (Jackson 3, `tools.jackson`) |
| Database | `jdbi3-bom`, `h2` |
| Parsing | `antlr4-runtime` |
| Logging | `slf4j-bom` |
| Platform | `directories` |

Then declare what you use **without a `<version>`**. Nothing is on a classpath
until you declare it: managing a version is not a recommendation to use the
library, only a statement that the number is not yours to pick.

The split is the point. A build parent that also dictated the JDBI version would
be making an upgrade decision for every project, including the ones with no
database. Keeping the catalogue in a separate artifact means a project takes the
gates and the versions independently — and a project that already has a corporate
parent it cannot change can still import the catalogue.

**Import and inherit are not the same.** A project that *inherits* can pin one
library by overriding the property (`<jdbi.version>`); a project that *imports*
cannot — import takes the resolved versions and its own properties do not
override them. Inherit the parent, import the BOM, and override a property only
where inheritance actually reaches.

`error_prone_annotations` is the one worth knowing about: libraries compiled
against it (JDBI, anything Guava-adjacent) make javac emit *"Cannot find
annotation method `value()` in type `GuardedBy`"*, which `-Werror` turns fatal.
Declaring it with no version fixes that. It is in the parent rather than the BOM
because `-Werror` is a gate, not a library choice.

**ANTLR is a matched pair.** A runtime that disagrees with the generator fails
when the parser *runs*, not when it is built, so the symptom is a malfunction
rather than a build error. `${antlr4.version}` is defined once in the parent and
inherited by the BOM, so there is one number and drift is impossible: the BOM
manages `antlr4-runtime`, the parent manages `antlr4-maven-plugin`. Declare the
plugin with no `<version>` and never pin either half yourself.

`bom/src/it/managed-library-versions` consumes both the way a real project does —
inherit the parent, import the BOM — and declares six libraries with no version,
so a dropped entry fails there rather than in a consumer.

### Why `bom/` is not a `<module>`

`<modules>` is inherited. If this POM aggregated `bom/`, every external child
would inherit that list and try to build a `bom/` directory of its own. So the
two are separate Maven invocations, parent first:

```
./mvnw clean install
./mvnw -f bom/pom.xml clean install
```

The BOM inherits the parent — for the licence, SCM, developer and signing blocks
only, so none of it is restated. That inheritance never reaches a consumer: an
`<import>` takes `dependencyManagement` and nothing else.

## Quality gates

Every child gets these without declaring anything:

| Phase | Tool | What it does |
|---|---|---|
| `validate` | Enforcer | Maven/Java version floors, no dynamic versions, dependency convergence |
| `validate` | Spotless | Auto-formats with Palantir Java Format |
| `validate` | Checkstyle | Enforces the shared ruleset |
| `compile` | Error Prone + NullAway | Static analysis and null-safety, as compile errors |

`reactorModuleConvergence` has two consequences worth knowing before they
surprise you. A reactor module whose parent is not the reactor root fails the
rule, so a parentless or externally-parented BOM module cannot stay in the
aggregator. And `mvn -pl <module>` fails unless you also pass `-am`.

Spotless is declared before Checkstyle on purpose: both bind to `validate`, and
Maven runs plugins in declaration order within a phase, so code is formatted
before it is checked.

`dependency:analyze-only` runs at `verify` with `failOnWarning`, so a dependency
that is declared but unused — or used but only present transitively — fails the
build. Two exemptions are configured centrally: `jspecify`, whose annotations
leave no trace in bytecode and so always look unused, and the JUnit artifacts,
because depending on the `junit-jupiter` aggregate while importing from
`junit-jupiter-api` is the idiomatic usage.

## Turning off an Error Prone check

Error Prone runs with `-Werror`, so a check that fights a project's conventions
is fatal and cannot be suppressed per site at any sane scale. Override
`errorprone.extra.args`, which is appended verbatim to the plugin argument:

```xml
<properties>
  <errorprone.extra.args>-Xep:InvalidInlineTag:OFF</errorprone.extra.args>
</properties>
```

Space-separate several. This exists so a child never has to override
`<compilerArgs>`, which would silently discard the `add-exports` flags, the
compile policy and NullAway along with it.

## Registering a custom Javadoc tag

Javadoc runs with `doclint` at `all,-missing` and `failOnWarnings`, so a tag the
JDK does not know is an error. It does not break `verify`, only
`attach-javadocs`, which means the project builds fine and then cannot be
released. Override `javadoc.extra.args`, appended to `<additionalOptions>`:

```xml
<properties>
  <javadoc.extra.args>-tag mtg.rule:a:Rule:</javadoc.extra.args>
</properties>
```

`-tag` registers a **block** tag, written `@mtg.rule 702.6a`, which renders as
its own `Rule:` section.

Registering the name turns an *inline* `{@mtg.rule 702.6a}` from a loud error
into a silent deletion. Doclint stops complaining, the build goes green, and
javadoc drops the text from the rendered page without a word — the docs ship
with every such reference missing. **Errors going to zero is not evidence the
tag renders.** Read the generated HTML:

```
./mvnw javadoc:jar
unzip -p target/*-javadoc.jar path/to/Type.html | grep -c 'Rule:'
```

The first project to hit this had 1313 inline references and 96 errors; the
errors went to zero and all 1313 references silently vanished. An inline tag
needs a `Taglet`; pass `-taglet` and `-tagletpath` through this same property.

Same purpose as `errorprone.extra.args`: a child never has to override the
javadoc configuration, which would discard `doclint`, `failOnWarnings` and the
release wiring with it.

## Suppressing a Checkstyle rule at one site

`@SuppressWarnings("checkstyle:CyclomaticComplexity")` works on any element, for
the cases where a rule measures something real but harmless — a flat switch
dispatching one arm per grammar alternative scores high complexity because the
grammar is large, not because the code is hard.

Both halves are required for this to work, and the failure is silent: a
`SuppressWarningsHolder` inside `TreeWalker` collects the annotations, and a
`SuppressWarningsFilter` at `Checker` level consumes what it collected. With
only the holder, every annotation is accepted and ignored. `2026-08-01` shipped
that way; `src/it/checkstyle-suppresswarnings{,-absent}` is what keeps it fixed.

## Snapshots, ranges and multi-module projects

`banDynamicVersions` runs with `allowSnapshots=true`. A module depending on its
`-SNAPSHOT` sibling is how a multi-module project refers to itself between
releases; banning it means no such project can build at all. Ranges, `LATEST`
and `RELEASE` are still rejected — they make a build depend on when it ran.

Shipping a release that depends on a snapshot is the real hazard, and
`requireReleaseDeps` / `requireReleaseVersion` catch it under `-PperformRelease`,
which is the only moment it matters.

Two more consequences of `reactorModuleConvergence`, both surprising the first
time: every reactor module's parent must be the reactor root, so a standalone
BOM module has to be folded into the root POM; and `mvn -pl <module>` fails
unless `-am` is passed.

## Layout belongs to the formatter

Checkstyle here deliberately carries no `Indentation` module, and
`WhitespaceAround` permits every empty body. Spotless and Checkstyle both bind
to `validate`, Spotless first, so anything Checkstyle demands that
palantir-java-format does not produce is unfixable in a child project: the
formatter rewrites the file moments before the linter reads it. Whatever
palantir emits is the house style.

`src/it/formatter-checkstyle-agreement` is what keeps that true.

## Testing this POM

`src/it/` holds real projects built against the POM under construction, run by
`maven-invoker-plugin` on every `./mvnw verify`:

| Project | Expected |
|---|---|
| `clean-project` | builds green |
| `formatter-checkstyle-agreement` | builds green — empty records, marker interfaces and wrapped lambdas, with no suppressions |
| `errorprone-extra-args` | builds green — a custom inline Javadoc tag, with the check switched off |
| `checkstyle-suppresswarnings` | builds green — a 16-arm switch, complexity suppressed by annotation |
| `visibilitymodifier-junit-fields` | builds green — package-private `@TempDir` and `@RegisterExtension` fields |
| `snapshot-sibling` | builds green — a reactor module depending on its `-SNAPSHOT` sibling |
| `javadoc-extra-args` | builds green — a custom block tag registered through the property |
| `checkstyle-violation` | **fails** — magic number |
| `nullaway-violation` | **fails** — null passed where non-null required |
| `errorprone-extra-args-absent` | **fails** — same sources, without the property |
| `checkstyle-suppresswarnings-absent` | **fails** — same switch, without the annotation |

| `javadoc-extra-args-absent` | **fails** — same tag, without the property |

The failing projects are the point: if a gate ever stops enforcing, its
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

The path is relative to the project and identical everywhere, so the setting is
the same in every project — but it is configured per developer. IntelliJ writes
it to `.idea/checkstyle-idea.xml`, which is commonly excluded by a global
`~/.config/git/ignore` rule, so do not count on it being committed.

Enabling **Import settings from Maven** in the Checkstyle plugin avoids the
manual setup entirely: it reads `<configLocation>`, `<suppressionsLocation>` and
the Checkstyle version straight from the POM on every Maven import, resolving
the ruleset from the plugin classpath — the config jar. Nothing to point at by
hand, and it cannot drift from the build.

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

**`maven-release-plugin` is deliberately not configured at all.**
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
