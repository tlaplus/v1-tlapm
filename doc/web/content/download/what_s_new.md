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


### What's new in TLAPS version TBD

When instantiating a version of the TLA+ module `TLAPS.tla` (i.e., using
an `INSTANCE TLAPS` statement) that is from an earlier version of TLAPS,
a warning may be raised about the expression level of declared operators
within the scope of `ENABLED`. To avoid this warning, please use a newer
version of the TLA+ module `TLAPS.tla`, for example the TLA+ module
`TLAPS.tla` contained in this release of TLAPS. Installing TLAPS also
copies the module `TLAPS.tla` to a path from where it is used. So if
instantiating that "installed" copy of the file `TLAPS.tla`, then this
warning would not arise.


### What's new in TLAPS version 1.4.5   <span style="font-size:80%;">(February 2020)</span>
<div class="hr"></div>

We switched to Z3 for the default SMT back-end prover and fixed a number
of bugs (including some soundness bugs).


### What's new in TLAPS version 1.4.3   <span style="font-size:80%;">(June 2015)</span>
<div class="hr"></div>

Many bug fixes.


### What's new in TLAPS version 1.3.2   <span style="font-size:80%;">(May 2014)</span>

<div class="hr"></div>

We added a few definitions and theorems in `NaturalsInduction.tla` and
changed the name of the `translate` utility to `ptl_to_trp` in order to
avoid possible name clashes.


### What's new in TLAPS version 1.3.0   <span style="font-size:80%;">(March 2014)</span>
<div class="hr"></div>

We fixed some bugs, but the most important change is the addition of a
back-end prover for temporal logic (LS4), invoked with the pragma `PTL`
(Propositional Temporal Logic).


### What's new in TLAPS version 1.2.1   <span style="font-size:80%;">(September 2013)</span>
<div class="hr"></div>

##### (non-exhaustive list)

#### TLA proof manager

- New option: `--stretch` to adapt timeouts to the machine's speed
- Speed improvements for large multi-module specifications
- Many bug fixes

#### Backend provers

- Removed Cooper's algorithm (everybody should use SMT instead)
- A new back-end for calling TPTP provers
- New option on Windows: `--fast-isabelle` to invoke Isabelle more efficiently


### What's new in TLAPS version 1.1.1   <span style="font-size:80%;">(November 2012)</span>
<div class="hr"></div>

##### (non-exhaustive list)

#### TLA proof manager

- Many bug fixes; robustness improvements

#### Backend provers

- New translation for SMT back-ends (more robust and more effective)


### What's new in TLAPS version 1.0   <span style="font-size:80%;">(January 2012)</span>
<div class="hr"></div>

##### (non-exhaustive list)

#### TLA proof manager

- Overall efficiency improved (speed and robustness: minor bugs fixed)
- New way to call backend provers via TLA+ identifiers (see
  [tactics](../Documentation/Tutorial/Tactics.html)).
- Improved fingerprints (incremental saving, improved sharing,
  history).
- Implementation of Cooper's quantifier-elimination algorithm (tactic
  `SimpleArithmetic`) can now deal with abstract terms (e.g. prove
  that `f[x] + 1 > f[x]` without unfolding the definition of `f`).
- Improved Toolbox integration.
- Improved reasons of failure messages.

#### Backend provers

- New backend translator to SMTLIB2 standard smt input format.
- New backend translator to the Z3 smt-solver native input format.
- New backend translator to the Yices smt-solver native input format.
- Upgrade from Isabelle2009-1 to Isabelle2011-1.


<!-- DO NOT EDIT BELOW THIS LINE, DO NOT REMOVE THIS LINE -->

<script type="text/javascript">
  document.write ('\x3Cscript type="text/javascript" src="'
                  + baseurl + 'assets/footer.js">\x3C/script>')
</script>
</body>
</html>
