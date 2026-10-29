package be.imgn.it;

/** Holds a field that generated code in the same package reads. */
public final class Widget {

    @Exposed
    String label = "widget";

    /**
     * Returns the label.
     *
     * @return the label
     */
    public String label() {
        return label;
    }
}
