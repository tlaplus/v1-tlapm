---- MODULE Level_of_parametric_INSTANCE_test ----
(* Test if the level weights of operators are
updated in case they have been computed before
parametric instantiation.

No fingerprints are used in this test to ensure
that the level computation is performed.
*)

---- MODULE Inner ----
VARIABLE x

Foo == x
======================

(* This horizontal line tests that the test script
`test/TOOLS/do_one_test` correctly reasons about
nesting of submodules.
*)
--------------------------------------------------

M(x) == INSTANCE Inner

THEOREM TRUE
<1>1. M!Foo(TRUE) => M!Foo(TRUE)
    OBVIOUS
<1> QED

==================================================
command: ${TLAPM} --nofp --toolbox 0 0 ${FILE}
nostderr: ending abnormally
