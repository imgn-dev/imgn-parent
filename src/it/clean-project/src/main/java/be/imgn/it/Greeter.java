package be.imgn.it;

import java.util.Locale;

/** Builds greetings. */
public final class Greeter {

    private final Locale locale;

    /**
     * Creates a greeter.
     *
     * @param locale the locale
     */
    public Greeter(Locale locale) {
        this.locale = locale;
    }

    /**
     * Greets someone.
     *
     * @param name the name
     * @return the greeting
     */
    public String greet(String name) {
        return "Hello, " + name.toUpperCase(this.locale);
    }
}
