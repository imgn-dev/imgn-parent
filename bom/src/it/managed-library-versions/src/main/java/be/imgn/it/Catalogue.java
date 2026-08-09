package be.imgn.it;

import com.palantir.javapoet.TypeSpec;
import dev.dirs.ProjectDirectories;
import org.antlr.v4.runtime.CharStreams;
import org.jdbi.v3.core.Jdbi;
import tools.jackson.databind.json.JsonMapper;

/** Touches each managed library, so dependency:analyze-only sees them as used. */
public final class Catalogue {

    private Catalogue() {}

    /**
     * Names the libraries resolved through the parent's dependency management.
     *
     * @return one line per library
     */
    public static String describe() {
        return JsonMapper.builder().build().getClass().getName()
                + " " + CharStreams.fromString("grammar").getSourceName()
                + " " + Jdbi.class.getName()
                + " " + ProjectDirectories.from("be", "imgn", "it").dataDir
                + " " + TypeSpec.classBuilder("Generated").build().name();
    }
}
