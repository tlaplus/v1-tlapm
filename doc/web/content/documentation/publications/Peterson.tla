--------------------------- MODULE Peterson  ----------------------------
EXTENDS TLAPS

Not(i) == IF i = 0 THEN 1 ELSE 0

(*******
--algorithm Peterson {
   variables flag = [i \in {0, 1} |-> FALSE], turn = 0;
   process (proc \in {0,1}) {
     a0: while (TRUE) {
     a1:   flag[self] := TRUE;
     a2:   turn := Not(self);
     a3a:  if (flag[Not(self)]) {goto a3b} else {goto cs} ;
     a3b:  if (turn = Not(self)) {goto a3a} else {goto cs} ;
     cs:   skip;  \* critical section
     a4:   flag[self] := FALSE;
     } \* end while
    } \* end process
  }
********)

\* BEGIN TRANSLATION
VARIABLES flag, turn, pc

vars == << flag, turn, pc >>

ProcSet == ({0,1})

Init == (* Global variables *)
        /\ flag = [i \in {0, 1} |-> FALSE]
        /\ turn = 0
        /\ pc = [self \in ProcSet |-> "a0"]

a0(self) == /\ pc[self] = "a0"
            /\ pc' = [pc EXCEPT ![self] = "a1"]
            /\ UNCHANGED << flag, turn >>

a1(self) == /\ pc[self] = "a1"
            /\ flag' = [flag EXCEPT ![self] = TRUE]
            /\ pc' = [pc EXCEPT ![self] = "a2"]
            /\ turn' = turn

a2(self) == /\ pc[self] = "a2"
            /\ turn' = Not(self)
            /\ pc' = [pc EXCEPT ![self] = "a3a"]
            /\ flag' = flag

a3a(self) == /\ pc[self] = "a3a"
             /\ IF flag[Not(self)]
                   THEN /\ pc' = [pc EXCEPT ![self] = "a3b"]
                   ELSE /\ pc' = [pc EXCEPT ![self] = "cs"]
             /\ UNCHANGED << flag, turn >>

a3b(self) == /\ pc[self] = "a3b"
             /\ IF turn = Not(self)
                   THEN /\ pc' = [pc EXCEPT ![self] = "a3a"]
                   ELSE /\ pc' = [pc EXCEPT ![self] = "cs"]
             /\ UNCHANGED << flag, turn >>

cs(self) == /\ pc[self] = "cs"
            /\ TRUE
            /\ pc' = [pc EXCEPT ![self] = "a4"]
            /\ UNCHANGED << flag, turn >>

a4(self) == /\ pc[self] = "a4"
            /\ flag' = [flag EXCEPT ![self] = FALSE]
            /\ pc' = [pc EXCEPT ![self] = "a0"]
            /\ turn' = turn

proc(self) == a0(self) \/ a1(self) \/ a2(self) \/ a3a(self) \/ a3b(self)
                 \/ cs(self) \/ a4(self)

Next == (\E self \in {0,1}: proc(self))

Spec == Init /\ [][Next]_vars

\* END TRANSLATION

\* The following predicate defines mutual exclusion of Peterson's algorithm.
MutualExclusion == ~(pc[0] = "cs"  /\ pc[1] = "cs")

-----------------------------------------------------------------------------
\* The proof

TypeOK == /\ pc \in [{0,1} -> {"a0", "a1", "a2", "a3a", "a3b", "cs", "a4"}]
          /\ turn \in {0, 1}
          /\ flag \in [{0,1} -> BOOLEAN]

I == \A i \in {0, 1} :
       /\ (pc[i] \in {"a2", "a3a", "a3b", "cs", "a4"} => flag[i])
       /\ (pc[i] \in {"cs", "a4"})
            => /\ pc[Not(i)] \notin {"cs", "a4"}
               /\ (pc[Not(i)] \in {"a3a", "a3b"}) => (turn = i)

Inv == TypeOK /\ I

\* Use this specification to check with TLC that Inv is an inductive invariant.
ISpec == Inv /\ [][Next]_vars

USE DEF ProcSet

\* First proof, using SMT for showing that Inv is inductive
THEOREM Spec => []MutualExclusion
<1>1. Init => Inv
  BY DEFS Init, Inv, TypeOK, I
<1>2. Inv /\ [Next]_vars => Inv'
  BY SMT DEFS Inv, TypeOK, I, Next, proc, a0, a1, a2, a3a, a3b, cs, a4, Not, vars 
<1>3. Inv => MutualExclusion
  BY DEFS Inv, I, MutualExclusion, Not
<1>4. QED
  PROOF OMITTED

\* Second proof, using just Zenon and Isabelle
THEOREM Spec => []MutualExclusion
<1>1. Init => Inv
  BY DEFS Init, Inv, TypeOK, I
<1>2. Inv /\ [Next]_vars => Inv'
  <2>1. SUFFICES ASSUME Inv, Next PROVE Inv'
    BY DEFS Inv, TypeOK, I, vars
  <2>2. TypeOK'
    BY Inv, Next, Auto DEFS Inv, TypeOK, Next, proc, a0, a1, a2, a3a, a3b, cs, a4, Not
  <2>3. I'
    <3>1. SUFFICES ASSUME NEW j \in {0,1}
                   PROVE  I!(j)'
      BY DEF I
    <3>2. PICK i \in {0,1} : proc(i)
      BY Next DEF Next
    <3>3. CASE i=j
      BY Inv, proc(i), i=j DEFS Inv, TypeOK, I, proc, a0, a1, a2, a3a, a3b, cs, a4, Not
    <3>4. CASE i#j
      BY Inv, proc(i), i#j DEFS Inv, TypeOK, I, proc, a0, a1, a2, a3a, a3b, cs, a4, Not
    <3>5. QED
      BY <3>3, <3>4
  <2>4. QED
    BY <2>2, <2>3 DEF Inv
<1>3. Inv => MutualExclusion
  BY DEFS Inv, (*TypeOK,*) I, MutualExclusion, Not
<1>4. QED
  PROOF OMITTED

=============================================================================
