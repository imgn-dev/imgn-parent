package be.imgn.it;

/** Uses the sibling, so dependency:analyze-only sees the dependency as used. */
public final class App {

    private App() {}

    /**
     * Runs the application.
     *
     * @return the greeting from the sibling module
     */
    public static String run() {
        return Greeting.text();
    }
}
