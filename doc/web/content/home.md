### About
<div class="hr"></div>

The **TLA**+ **P**roof **S**ystem (TLAPS) mechanically checks
[TLA+](http://research.microsoft.com/users/lamport/tla/tla.html) proofs.

TLA+ is a general-purpose formal specification language that is
particularly useful for describing concurrent and distributed systems.
The TLA+ proof language is declarative, hierarchical, and scalable to
large system specifications. It provides a consistent abstraction over
the various “backend” verifiers.

The current release of TLAPS does not perform temporal reasoning, and it
does not handle some features of TLA+. See the list of currently
[unsupported TLA+ features](download/unsupported.html). An extension to
the full TLA+ language is under active development. However, TLAPS is
now suitable for verifying safety properties of non-trivial algorithms.
(Only trivial temporal-logic reasoning that is easily checked by hand is
needed for safety.) For examples, see the [proof of a Byzantine Paxos
algorithm](
    http://research.microsoft.com/en-us/um/people/lamport/tla/byzpaxos.html)
and the [proof of a security
architecture](http://research.microsoft.com/apps/pubs/default.aspx?id=144962).


### Get it
<div class="hr"></div>

The current version of TLAPS is 1.4.5. It can (and should) be used from
the [Toolbox IDE](
    http://research.microsoft.com/en-us/um/people/lamport/tla/toolbox.html).
TLAPS is free software, distributed under the BSD [license](
    Download/License.html).
You can obtain it in the [download section](download.html).


### Documents
<div class="hr"></div>

New users should read the [tutorial](documentation/tutorial.html). The
[TLA+ hyperbook](
    http://research.microsoft.com/en-us/um/people/lamport/tla/hyperbook.html)
has a more in-depth tutorial of TLA+ and associated tools. The complete
specification of the proof language is contained in the
[TLA+2 Preliminary Guide](
    http://research.microsoft.com/en-us/um/people/lamport/tla/tla2-guide.pdf).
You can also look at [academic publications](documentation/publications.html).


### Community
<div class="hr"></div>

TLAPS is developed as part of the [*Tools for
Proofs*](http://www.msr-inria.fr/projects/tools-for-proofs) project at
the [Microsoft Research–Inria](http://www.msr-inria.fr) joint centre in
Paris, France. Users are encouraged to use the [TLA+
users](https://groups.google.com/forum/#!forum/tlaplus) Google group to
discuss the system. A [public
bug-tracker](https://github.com/tlaplus/tlapm/issues) is available.


<div style="position:relative; top:50px">

------------------------------------------------------------------------

This page can be found by searching the Web for the 16-letter string
`uidtlapshomepage`. Please do not put this string in any document that
could wind up on the Web--including email messages and Postscript and
Word documents. You can refer to it in Web documents as "the string
obtained by removing the `-` from `uid-tlapshomepage`".
</div>
