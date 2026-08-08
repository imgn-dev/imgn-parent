package be.imgn.it;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.Extension;
import org.junit.jupiter.api.extension.RegisterExtension;
import org.junit.jupiter.api.io.TempDir;

class InjectedFieldsTest {

    @TempDir
    Path dir;

    @RegisterExtension
    final Extension extension = new Extension() {};

    @Test
    void junitInjectsNonPrivateFields() {
        assertThat(dir).isNotNull();
        assertThat(extension).isNotNull();
    }
}
