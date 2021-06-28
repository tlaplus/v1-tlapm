---- MODULE ENABLED_INSTANCE_nullary_op_two_vars_test ----
EXTENDS TLAPS

---- MODULE Inner ----
VARIABLE x, y

A == ENABLED (x' # y')

======================

VARIABLE x

M == INSTANCE Inner WITH y <- x

THEOREM M!A
BY ExpandENABLED DEF M!A

==========================================================
