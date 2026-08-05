package be.imgn.it;

/** Passes null where NullAway requires non-null. */
public final class Nulls {

    private Nulls() {}

    /**
     * Length of a name.
     *
     * @return a length
     */
    public static int length() {
        return measure(null);
    }

    private static int measure(String value) {
        return value.length();
    }
}
