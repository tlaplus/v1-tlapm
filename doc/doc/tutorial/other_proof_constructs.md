## TLA+ proof constructs
<div class="hr"></div>


### `SUFFICES`
<div class="hr"></div>

An ordinary expression or `ASSUME` ... `PROVE` ... in a step stands for an
assertion of that step. Its subproof proves it, and the rest of the
proof in the same level is allowed to use the assertion as an
assumption. `SUFFICES` reverses these two roles. Succinctly, the following
two proof fragments are equivalent.

<table class="none">
<colgroup>
<col style="width: 33%" />
<col style="width: 33%" />
<col style="width: 33%" />
</colgroup>
<tbody>
<tr class="odd">
<td data-valign="top">

```tla
<4>1. t1
  <5>1. s1
  <5>2. s2
  …
  <5>m. QED
<4>2. t2
<4>3. t3
…
<4>n. QED
```

</td>
<td class="a"> </td>
<td data-valign="top">

```tla
<4>1. SUFFICES t1
  <5>1. t2
  <5>2. t3
  …
  <5>n-1. QED
<4>2. s1
<4>3. s2
…
<4>m+1. QED
```

</td>
</tr>
</tbody>
</table>

In the proof on the left-hand side above, `t1` is known in
proof-steps `<4>2`, `<4>3`, ..., `<4>n`, while in the
proof on the right-hand side, `t1` is known in proof-steps
`<5>1`, `<5>2`, ..., `<5>n-1`. `SUFFICES` is mainly used
to rephrase the sequent to be proved in a more perspicuous form. For
example, suppose we have:

```tla
VARIABLE x
A == /\ x = 1
     /\ x' = 2
B == /\ x = 2
     /\ x' = 1
Next == A \/ B
Inv == x \in {1, 2}

THEOREM Inv /\ Next => Inv'
<1>1. ASSUME Inv, Next PROVE Inv'
  <2>1. ASSUME A PROVE Inv'
  <2>2. ASSUME B PROVE Inv'
  <2>3. QED BY <1>1, <2>1, <2>2 DEF Next
<1>2. QED BY <1>1
```

This proof is unnatural because of the nested occurrences of `ASSUME` ...
`PROVE` ... . The point where `Next` needs to be expanded, in `<2>3`, is
potentially far removed from its relevant assertion, `<1>1`. It
would be better instead to rephrase the theorem as a conjunction and
then derive the conjuncts with a `SUFFICES` as follows:

```tla
THEOREM Inv /\ Next => Inv'
<1>1. SUFFICES /\ Inv /\ A => Inv'
               /\ Inv /\ B => Inv'
  BY DEF Next
<1>2. ASSUME Inv, A PROVE Inv'
<1>3. ASSUME Inv, B PROVE Inv'
<1>4. QED BY <1>2, <1>3
```

In this form, the definition of `Next` is cited right next to the
assertion where it is relevant. In the rest of the proof after step
`<1>1`, the definition of `Next` is irrelevant. The proof is also
shallower because we change an instance of a `QED` step into a `BY` leaf
proof. This kind of restatement of the current goal can make proofs much
easier to read and maintain.

(Strictly speaking, the `SUFFICES` step was not necessary in this simple
proof because the `DEF Next` could have been folded into the proof of
`<1>4`. However, in more complex proofs it is better to use `SUFFICES`
as needed to rephrase the goal *up front*. These steps also serve as
hints to the reader about the direction of the proof.)


### `HAVE`, `TAKE` and `WITNESS`
<div class="hr"></div>

TLAPS provides some shortcuts for proving implications and quantifications.
They can be described with their equivalent `SUFFICES` construct:

<table data-rules="all" style="width:110%"
       data-cellpadding="6px" border:"1px solid black">
<colgroup>
<col style="width: 33%" />
<col style="width: 33%" />
<col style="width: 33%" />
</colgroup>
<thead>
<tr class="header">
<th style="width: 10px">goal</th>
<th style="width: 10px">step</th>
<th style="width: 10px">

equivalent `SUFFICES` step

</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td data-valign="top">

```tla
e => f
```

</td>
<td data-valign="top">

```tla
<n>l. HAVE g
```

</td>
<td data-valign="top">

```tla
<n>l. SUFFICES ASSUME g PROVE f
    OBVIOUS
```

</td>
</tr>
<tr class="even">
<td data-valign="top">

```tla
\A x : P(x)
```

</td>
<td data-valign="top">

```tla
<n>l. TAKE y
```

</td>
<td data-valign="top">

```tla
<n>l. SUFFICES ASSUME NEW y PROVE P(y)
    OBVIOUS
```

</td>
</tr>
<tr class="odd">

<td data-valign="top">

```tla
\A x \in S : P(x)
```

</td>
<td data-valign="top">

```tla
<n>l. TAKE y \in T
```

</td>
<td data-valign="top">

```tla
<n>l. SUFFICES ASSUME NEW y \in T
               PROVE P(y)
  OBVIOUS
```

</td>
</tr>
<tr class="even">

<td data-valign="top">

```tla
\E x : P(x)
```

</td>
<td data-valign="top">

```tla
<n>l. WITNESS e
```

</td>
<td data-valign="top">

```tla
<n>l. SUFFICES P(e)
  OBVIOUS
```

</td>
<tr class="odd">
<td data-valign="top">

```tla
\E x \in S : P(x)
```

</td>
<td data-valign="top">

```tla
<n>l. WITNESS e \in T
```

</td>
<td data-valign="top">

```tla
<n>l. SUFFICES ASSUME e \in T
               PROVE P(e)
  <n+1>1. e \in T
    OBVIOUS
  <n+1>2. QED
    BY <n+1>1
```

</td>
</tr>
</tbody>
</table>

One important deficiency of `HAVE`, `TAKE` and `WITNESS` steps is that the
precise form of the rephrased goal is not textually present in the
proof. The (human) reader might get confused by long chains of these
steps, especially if interleaved with other kinds of steps. These
constructs should therefore be used sparingly, preferably only in the
lowest levels of proof where there is some actual benefit in linearizing
the proof.


### `PICK`
<div class="hr"></div>

An assumption of the form `\E x : P(x)` can be used by picking a fresh `x`
for which `P(x)` is assumed. This is done using the step `PICK x : P(x)`.
Note that `\E x : P(x)` need not be present exactly in the assumptions;
this step accepts a subproof that supplies the justification for
`\E x : P(x)`. Here is a somewhat contrived example:

```tla
THEOREM ~ \E x \in Nat : x + 1 = 0
<1>1. SUFFICES ASSUME \E x \in Nat : x + 1 = 0
               PROVE  FALSE
  OBVIOUS
  (* new facts: \E x \in Nat : x + 1 = 0 *)
  (* goal: FALSE *)
<1>2. PICK u \in Nat : u = -1
  (* goal: \E u \in Nat : u = -1 *)
  <2>1. \A n \in Nat : n + 1 = 0 => n = -1
    OBVIOUS
  <2>2. QED BY <2>1, <1>1
  (* new facts: u \in Nat, u = -1 *)
  (* goal: FALSE *)
<1> QED BY -1 \notin Nat, <1>2
```


<!--
---- MODULE other_constructs ----
EXTENDS TLAPS, Integers

---- MODULE suffices ----
\* suffices proof 1
VARIABLE x
A == /\ x = 1
     /\ x' = 2
B == /\ x = 2
     /\ x' = 1
Next == A \/ B
Inv == x \in {1, 2}

THEOREM Inv /\ Next => Inv'
<1>1. ASSUME Inv, Next PROVE Inv'
  <2>1. ASSUME A PROVE Inv'
  <2>2. ASSUME B PROVE Inv'
  <2>3. QED BY <1>1, <2>1, <2>2 DEF Next
<1>2. QED BY <1>1

\* suffices proof 2
THEOREM Inv /\ Next => Inv'
<1>1. SUFFICES /\ Inv /\ A => Inv'
               /\ Inv /\ B => Inv'
  BY DEF Next
<1>2. ASSUME Inv, A PROVE Inv'
<1>3. ASSUME Inv, B PROVE Inv'
<1>4. QED BY <1>2, <1>3
====

\* pick example
THEOREM ~ \E x \in Nat : x + 1 = 0
<1>1. SUFFICES ASSUME \E x \in Nat : x + 1 = 0
               PROVE  FALSE
  OBVIOUS
  (* new facts: \E x \in Nat : x + 1 = 0 *)
  (* goal: FALSE *)
<1>2. PICK u \in Nat : u = -1
  (* goal: \E u \in Nat : u = -1 *)
  <2>1. \A n \in Nat : n + 1 = 0 => n = -1
    OBVIOUS
  <2>2. QED BY <2>1, <1>1
  (* new facts: u \in Nat, u = -1 *)
  (* goal: FALSE *)
<1> QED BY -1 \notin Nat, <1>2

====
-->
