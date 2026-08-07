package be.imgn.it;

import java.util.List;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Shapes that palantir-java-format and checkstyle must agree on. */
public final class Shapes {

    private static final int MAX_LENGTH = 100;

    private Shapes() {}

    /**
     * A switch whose arms palantir wraps onto the next line.
     *
     * @param marker the value to classify
     * @return a description
     * @throws IllegalStateException when the marker is of an unknown kind
     */
    public static String describe(Marker marker) {
        return switch (marker) {
            case Summary summary ->
                "a summary with a deliberately long description so palantir wraps this arm: " + summary.created();
            case Empty ignored -> "empty";
            default -> throw new IllegalStateException("unknown marker: " + marker);
        };
    }

    /**
     * A lambda passed as an argument, long enough to wrap.
     *
     * @param values the values
     * @return the joined values
     */
    public static String join(List<String> values) {
        return values.stream()
                .map(Function.identity())
                .filter(value -> !value.isBlank() && value.length() < MAX_LENGTH && !value.startsWith("ignore-me"))
                .collect(Collectors.joining(", "));
    }

    /** An empty marker interface: the normal shape of a sealed ADT root. */
    public interface Marker {}

    /**
     * An empty record body, which palantir writes as {}.
     *
     * @param created how many were created
     * @param updated how many were updated
     * @param deleted how many were deleted
     * @param skipped how many were skipped
     */
    public record Summary(long created, long updated, long deleted, long skipped) implements Marker {}

    /** A second empty record, to be sure the first is not a one-off. */
    public record Empty() implements Marker {}
}
