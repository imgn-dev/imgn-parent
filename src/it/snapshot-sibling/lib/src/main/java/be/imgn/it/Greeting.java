package be.imgn.it;

/** Something for the sibling module to actually call. */
public final class Greeting {

    private Greeting() {}

    /**
     * Returns the greeting.
     *
     * @return the greeting text
     */
    public static String text() {
        return "hello";
    }
}
