package be.imgn.it;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.DriverManager;
import java.sql.SQLException;
import org.junit.jupiter.api.Test;

class CatalogueTest {

    @Test
    void everyManagedLibraryResolves() {
        assertThat(Catalogue.describe()).isNotBlank();
    }

    @Test
    void h2ResolvesAtTestScope() throws SQLException {
        try (var connection = DriverManager.getConnection("jdbc:h2:mem:it")) {
            assertThat(connection.isValid(1)).isTrue();
        }
    }
}
