---- MODULE ENABLED_INSTANCE_nullary_op_test ----
EXTENDS TLAPS

---- MODULE Inner ----
VARIABLE x

A == ENABLED (x')

======================

VARIABLE x

M == INSTANCE Inner

THEOREM M!A
BY ExpandENABLED DEF M!A

=================================================
