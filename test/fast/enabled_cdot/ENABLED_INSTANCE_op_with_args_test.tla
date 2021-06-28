---- MODULE ENABLED_INSTANCE_op_with_args_test ----
EXTENDS TLAPS

---- MODULE Inner ----
VARIABLE x, y

A(z) == ENABLED (x' # y')

======================

VARIABLE x

M == INSTANCE Inner WITH y <- x

THEOREM M!A(x)
BY ExpandENABLED DEF M!A

===================================================
