package be.imgn.it;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;

class MockitoAgentTest {

    // CharSequence rather than List: mock(List.class) returns a raw List and the
    // unchecked conversion is fatal under -Werror. The mock is read through a
    // helper rather than asserted on directly, because Error Prone's
    // DirectInvocationOnMock rejects calling a mock straight from the test.
    private static int lengthOf(CharSequence value) {
        return value.length();
    }

    @Test
    void mockingWorksWithTheAgentRegistered() {
        CharSequence text = mock(CharSequence.class);
        when(text.length()).thenReturn(42);
        assertThat(lengthOf(text)).isEqualTo(42);
    }
}
