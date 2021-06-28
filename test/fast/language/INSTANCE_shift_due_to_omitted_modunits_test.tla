---- MODULE INSTANCE_shift_due_to_omitted_modunits_test ----


---- MODULE Inner ----
EXTENDS TLAPS

VARIABLE y

A == y'
THEOREM B == []TRUE
======================


VARIABLE z


M == INSTANCE Inner WITH y <- z


THEOREM
    \EE x:
        LET Q == INSTANCE Inner WITH y <- x
        IN Q!A
OBVIOUS


============================================================
command: ${TLAPM} --toolbox 0 0 ${FILE}
nostderr: Assertion failed
