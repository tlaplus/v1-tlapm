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


## Unsupported TLA+ features
<div class="hr"></div>

- Recursive operator definitions are not supported. Recursive function
  definitions *are* handled correctly.
- None of the back-end provers support reasoning about real numbers.
- Quantification over tuples and set constructors using tuples are not
  supported (for example
  ```tla
  {<<x, y>> \in S \X T : ...}
  ```
  ). Note that this produces a really obscure error message, or
  sometimes a silent crash of TLAPS.
- `ENABLED`, `\cdot` (action composition), and many temporal operators
  are unsupported.
- The Zenon and Isabelle back-ends do not know the definition of the
  `..` operator, but you can reason about it with SMT solvers. In
  general, proof obligations involving arithmetic can usually only be
  proved by the SMT backend.
- TLAPS has no built-in knowledge of (most of) the operators defined
  in the `TLC` standard module, and it cannot use their definitions
  either.


## Poorly Supported TLA+ Features
<div class="hr"></div>

While the following features are supported, the back-end provers do not
provide much automatic proving and require a lot of guidance.

- The `CASE` construct, strings, tuples, and records. For records, the
  provers usually need to be told explicitly to use a fact of the form
  `r.f = e` even when they are given the fact `r = [f |-> e, ...]`.
- To reason about an expression `e` of the form `CHOOSE x : P(x)`, you
  will have to explicitly state `P(e)` and prove it (by proving
  `\E x : P(x)`).
- When doing arithmetic, the back-end provers cannot do any reasoning
  that involves the division, modulus, or exponentiation operators.


## Known Limitations and Problems
<div class="hr"></div>

The following limitations and problems of TLAPS and its backends are
known to us and will hopefully be removed in a future version. We
welcome your feedback on problems that you encounter. Why not subscribe
to the [Google TLA+ group](
    https://groups.google.com/forum/#!forum/tlaplus)
where such issues are discussed?

- The SMT backend may fail to prove obligations involving several
  `CHOOSE` expressions. In particular, the axioms for determinacy of
  `CHOOSE` stating
  ```tla
  (\\A x : P(x) <=> Q(x)) => (CHOOSE x : P(x)) = (CHOOSE x : Q(x))
  ```
  may not be available to the SMT solver.
- Expressions inside a proof obligation of the form
  ```tla
  ASSUME ..., NEW P(_), ... PROVE ...
  ```
  where `P` is an operator with one or more arguments are only supported
  by the Isabelle backend.
- We have reports of `tlapm` crashing with a stack backtrace that
  starts with
  ```tla
  Unix.Unix_error(3, "select", "")
  ```
  If you see such a crash, please report it, with as much detail as
  possible and the whole contents of the `.tlaps` directory.
- In an `ASSUME`, `tlapm` accepts `NEW STATE`, `NEW VARIABLE`, `NEW ACTION`,
  and `NEW TEMPORAL` declarations but does not handle them correctly.
- Parameterized instantiations of theorems are not handled correctly.
- Subexpression references are not handled correctly when referencing
  a subexpression of an `ASSUME ... PROVE`.


<!-- DO NOT EDIT BELOW THIS LINE, DO NOT REMOVE THIS LINE -->

<script type="text/javascript">
  document.write ('\x3Cscript type="text/javascript" src="'
                  + baseurl + 'assets/footer.js">\x3C/script>')
</script>
</body>
</html>
