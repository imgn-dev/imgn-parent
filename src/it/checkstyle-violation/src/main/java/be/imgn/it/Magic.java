package be.imgn.it;

/** Uses a magic number, which the shared ruleset forbids. */
public final class Magic {

    private Magic() {}

    /**
     * Returns a magic number.
     *
     * @return a number
     */
    public static int magic() {
        return 12345;
    }
}
