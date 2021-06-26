<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US" lang="en-US">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<link rel="stylesheet" type="text/css" id="ss"/>
<title>TLA+ Proof System</title>
</head>
<body>
<script type="text/javascript">
  var baseurl = (document.URL.match (/.*[\\\/]content[\\\/]/))[0]
  baseurl = baseurl.slice (0, baseurl.length - "content/".length)
  document.getElementById('ss').href = baseurl + 'assets/css/common.css'
  document.write ('\x3Cscript type="text/javascript" src="'
                  + baseurl + 'assets/header.js">\x3C/script>')
</script>

<!-- DO NOT EDIT ABOVE THIS LINE, DO NOT REMOVE THIS LINE -->


## Tactics
<div class="hr"></div>

A proof is semantically correct if each proof obligation is correct –
meaning that the assertion follows from the usable facts. Thus, the
following could be a semantically correct proof:

```tla
THEOREM FermatsLastTheorem ==
    \A x, y, z, n \in Nat \ {0} : (n > 2) => (x^n + y^n # z^n)
BY PeanoAxioms
```

<!--
---- MODULE Fermat ----
EXTENDS TLAPS, Naturals
AXIOM PeanoAxioms == TRUE
THEOREM FermatsLastTheorem ==
    \A x, y, z, n \in Nat \ {0} : (n > 2) => (x^n + y^n # z^n)
BY PeanoAxioms
====
-->

However, we would not expect any computer program to check its
correctness. For most mechanical theorem provers, a proof is checkable
if the current version of the prover will verify the proof. A TLA+ proof
is checkable if each of its obligations is checkable. Since the language
is independent of any prover, there can be no precise definition of what
constitutes a checkable obligation. In practice, a proof step is
checkable if there is *some* backend verifier that accepts it. You
should resist tailoring your proof to particular backends because your
proofs will then become unmaintainable as TLAPS evolves. Instead, if a
backend verifier does not accept a leaf proof, you should try to
simplify the reasoning further using a new level of proof. Eventually,
your proof will produce obligations of sufficiently low complexity that
they will likely continue to be accepted by future versions of TLAPS.

That being said, there are some cases in which you may want to bypass
the default behavior of TLAPS. You may want to give a longer timeout to
the default backend provers. Or you may want to call particular
specialized backend verifiers that perform better than general purpose
theorem provers for certain fragments of logic. We call these
specialized procedures *tactics*. These tactics are declared in the
`TLAPS.tla` standard module.


### SMT, Zenon and Isabelle
<div class="hr"></div>

For proving an obligation, the default behaviour of TLAPS is to try
three back-ends in succession: SMT, Zenon, and Isa.

- SMT is the baseline SMT solver (by default Z3); it is tried with a
  timeout of 5 seconds.
- [Zenon](http://zenon-prover.org/) is a tableaux-based prover for
  first-order logic; it is tried with a timeout of 10 seconds.
- Isa is the automatic tactic `auto` of the
  [Isabelle](http://www.cl.cam.ac.uk/research/hvg/isabelle/) prover;
  is tried with a timeout of 30 seconds.

If Isabelle does not find a proof, TLAPS reports a failure on this
obligation. If you want to change the default timeouts and/or tactics,
you can use the following backend identifiers.

|    |    |
|----|----|
| `BY ZenonT(30)` | Modifying Zenon timeout. |
| `BY Isa` | Calling directly Isabelle with default tactic and timeout. |
| `BY IsaT(60)` | Modifying Isabelle timeout. |
| `BY IsaM("blast")` | Modifying Isabelle tactic. |
| `BY IsaMT("blast",60)` | Modifying Isabelle timeout and tactic. |


### SMT solvers
<div class="hr"></div>

**Note**: the Z3 solver is distributed
with TLAPS. If you want to use CVC4 you have to download and install it
from [CVC4](https://cvc4.github.io). Please check that you are allowed
to install a version according to the licensing conditions of these
solvers, and make sure that the executables are in your `$PATH`.

The SMT backend identifier invokes the baseline SMT solver. By default
this is the [Z3](https://github.com/Z3Prover/z3/wiki) solver, but you
can change it to call any SMT solver that can read
[SMT-LIB](http://smtlib.cs.uiowa.edu) format (version 2) input and can
handle linear integer and real reasoning. In order to invoke this
backend alone (without falling back to Zenon or Isabelle), use the SMT
or SMTT identifiers in a USE or BY clause.

|    |    |
|----|----|
| `BY SMT` | Call baseline SMT solver with default timeout of 5 seconds. |
| `BY SMTT(60)` | Call baseline SMT solver with a different timeout. |

In order to invoke [Z3](https://github.com/Z3Prover/z3/wiki) explicitly,
use the Z3 or Z3T identifiers in a USE or BY clause.

|    |    |
|----|----|
| `BY Z3` | Call Z3 backend with default timeout of 5 seconds. |
| `BY Z3T(60)` | Call Z3 with a different timeout. |

In order to invoke [CVC4](https://cvc4.github.io), use the `CVC4` or
`CVC4T` identifiers in a `USE` or `BY` clause (but remember that CVC4 is
not distributed with TLAPS).

|    |    |
|----|----|
| `BY CVC4` | Call CVC4 backend with default timeout of 5 seconds. |
| `BY CVC4T(60)` | Call CVC4 with a different timeout. |

If you want to change the baseline SMT solver, you have three options.

First option: change the baseline SMT solver only for the current run of
TLAPS. To do this, give the `--solver` command-line option to tlapm with
the solver's command line (described below) as argument, surrounded by
single quotes. If you use the ToolBox, you have to click on "Launch
Prover" to give that argument (see [Advanced
options](Advanced_options.html)). The option and argument would be
entered in the text box as follows:

| solver            | text box contents                |
|-------------------|----------------------------------|
| CVC4              | `--solver 'cvc4 -L smt "$file"'` |
| Z3 (Windows)      | `--solver 'z3 /smt2 "$file"'`    |
| Z3 (Linux, MacOS) | `--solver 'z3 -smt2 "$file"'`    |

Second option: permanently change the baseline SMT solver via a ToolBox
setting. This is done by going to the *File* menu, choosing the
*Preferences* item, then in the dialog box, under
*TLA+ Preferences > TLAPS > Additional Preferences*,
enter a command line in the SMT Solver text box.
This command line should run your SMT solver on a SMT-LIB file,
with `"$file"` in place of the file name. Here are a few examples:

| solver            | command line          |
|-------------------|-----------------------|
| CVC4              | `cvc4 -L smt "$file"` |
| Z3 (Windows)      | `z3 /smt2 "$file"`    |
| Z3 (Linux, MacOS) | `z3 -smt2 "$file"`    |

Third option: permanently change the baseline SMT solver via an
environment variable. This is done by setting the `TLAPM_SMT_SOLVER`
environment variable to be the command line described above. For
example, under Linux you should add the line

|    |
|----|
| `export TLAPM_SMT_SOLVER='cvc4 -lang smt2 "$file"'` |

to your shell's startup file (`.bashrc`).


<!-- DO NOT EDIT BELOW THIS LINE, DO NOT REMOVE THIS LINE -->

<script type="text/javascript">
  document.write ('\x3Cscript type="text/javascript" src="'
                  + baseurl + 'assets/footer.js">\x3C/script>')
</script>
</body>
</html>
