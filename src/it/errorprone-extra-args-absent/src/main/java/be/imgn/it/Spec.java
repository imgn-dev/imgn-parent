package be.imgn.it;

/**
 * Documents a rule with a project-specific inline tag.
 *
 * <p>Error Prone's InvalidInlineTag rejects {@x.custom 1.2} unless the check is
 * switched off, and -Werror makes that fatal.
 */
public final class Spec {

    private Spec() {}

    /**
     * Applies the rule at {@x.custom 702.6a}.
     *
     * @return the rule reference
     */
    public static String rule() {
        return "702.6a";
    }
}
