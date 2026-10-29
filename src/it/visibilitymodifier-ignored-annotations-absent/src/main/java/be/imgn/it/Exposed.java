package be.imgn.it;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** Marks a field that generated code reads, so it cannot be private. */
@Retention(RetentionPolicy.CLASS)
@Target(ElementType.FIELD)
public @interface Exposed {}
