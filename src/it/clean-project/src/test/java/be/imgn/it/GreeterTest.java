package be.imgn.it;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Locale;
import org.junit.jupiter.api.Test;

class GreeterTest {

    @Test
    void greets_in_upper_case() {
        assertThat(new Greeter(Locale.ROOT).greet("olivier")).isEqualTo("Hello, OLIVIER");
    }
}
