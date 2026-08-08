package be.imgn.it;

/** A flat dispatch whose arm count alone exceeds the complexity cap. */
public final class Dispatch {

    private Dispatch() {}

    /**
     * Maps a keyword to its category.
     *
     * @param keyword the keyword to classify
     * @return the category, or "unknown"
     */
    public static String categorise(String keyword) {
        return switch (keyword) {
            case "alpha" -> "a";
            case "bravo" -> "b";
            case "charlie" -> "c";
            case "delta" -> "d";
            case "echo" -> "e";
            case "foxtrot" -> "f";
            case "golf" -> "g";
            case "hotel" -> "h";
            case "india" -> "i";
            case "juliett" -> "j";
            case "kilo" -> "k";
            case "lima" -> "l";
            case "mike" -> "m";
            case "november" -> "n";
            case "oscar" -> "o";
            case "papa" -> "p";
            default -> "unknown";
        };
    }
}
