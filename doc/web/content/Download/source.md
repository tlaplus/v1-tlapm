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


## Generic Instructions

These instructions apply to any UNIX-like system, including GNU/Linux, most BSD
variants, Solaris, Cygwin on Windows, MacOSX, etc.

Notes for Windows users:

- TLAPS requires Cygwin 3.0.7 or later. At this time it works only with the
  32-bit version of cygwin.
- The following Cygwin packages are required for the instructions below:
  `gcc4`, `make`, `wget`, `perl`. Install them using Cygwin's `setup.exe`.

TLAPS tarball:
[tlaps-1.4.5.tar.gz](https://github.com/tlaplus/tlapm/archive/v1.4.5.tar.gz)


### 1. Unpack TLAPS tarball

You can unpack TLAPS by running the following command:

```
$ tar -xzf tlaps-1.4.5.tar.gz
```

This creates a directory named `tlaps-1.4.5` that contains four subdirectories:
`tlapm`, `zenon`, `isabelle` and `emacs`.


### 2. Install OCaml

TLAPS is implemented in OCaml and requires version 4.04.2 or higher. You can
follow any of the suggestions on [the offical OCaml release
page](https://ocaml.org/docs/install.html) to install OCaml. On Windows/Cygwin,
OCaml can be installed directly from Cygwin's `setup.exe`. On most modern
GNU/Linux distributions, OCaml is already packaged. Here are the commands for
the common Linux distributions:

<table style="margin-left: 2em;">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr class="odd">
<td style="padding-right: 3em">Debian, Ubuntu, etc.</td>
<td><code>apt-get install ocaml</code></td>
</tr>
<tr class="even">
<td data-valign="top">Redhat, Fedora, SuSe,<br />
Mandriva, CentOS, etc.</td>
<td data-valign="top"><code>yum install ocaml</code></td>
</tr>
<tr class="odd">
<td data-valign="top">Gentoo</td>
<td data-valign="top"><code>emerge ocaml</code></td>
</tr>
<tr class="even">
<td data-valign="top">Arch Linux</td>
<td data-valign="top"><code>pacman install ocaml</code></td>
</tr>
</tbody>
</table>

On MacOSX, you can use the package managers [Homebrew](http://brew.sh/)
(`brew install objective-caml`) or [MacPorts](http://www.macports.org)
(`port install ocaml`).

If you want to install OCaml from source, consider using
[OPAM](http://opam.ocaml.org).


### 3. Compile and Install Zenon

Run the following commands.

```
$ pushd tlaps-1.4.5/zenon
$ ./configure && make && make install
$ popd
```

By default, the above will try to install in `/usr/local`. If you don't have
write access to that directory, or would rather install Zenon elsewhere,
such as in `$HOME/bin`, run the following:

```
$ pushd tlaps-1.4.5/zenon
$ ./configure --prefix $HOME && make && make install
$ popd
```


### 4. Install Isabelle2011-1

Follow the [instructions](
    http://isabelle.in.tum.de/website-Isabelle2011-1/download.html)
on the Isabelle Web site. TLAPS actually does not need the full Isabelle2011-1
distribution. If you want only the necessary components, run the following
commands:

```
$ wget http://isabelle.in.tum.de/website-Isabelle2011-1/dist/Isabelle2011-1.tar.gz
$ wget http://isabelle.in.tum.de/website-Isabelle2011-1/dist/polyml-5.4.0.tar.gz
$ tar -xzf -C /usr/local Isabelle2011-1.tar.gz
$ tar -xzf -C /usr/local polyml-5.4.0.tar.gz
```

You may replace `/usr/local` above by any other directory. For example, to
install Isabelle2011-1 in your `$HOME`, use ` -C $HOME ` instead of
` -C /usr/local `.

Note that the `isabelle` and `isabelle-process` executables (found in
`/usr/local/Isabelle/bin` or `$HOME/Isabelle/bin`), or symbolic links to them,
must be in your `$PATH` for TLAPS to work.

You may delete the `Isabelle2011-1.tar.gz` and `polyml-5.4.0.tar.gz` files after
the above steps.


### 5. Compile Isabelle/TLA+

Run the following commands.

```
$ pushd /usr/local/Isabelle/src/Pure
$ isabelle make
$ popd
$ pushd tlaps-1.4.5/isabelle
$ make
$ popd
```

(Replace `/usr/local` above with wherever you installed Isabelle in the previous
step.)


### 6. Compile the **TLA**<sup>+</sup> **P**roof **M**anager (TLAPM)

Run the following commands.

```
$ pushd tlaps-1.4.5/tlapm
$ ./configure && make all
$ sudo make install
$ popd
```

By default, the above will try to install TLAPM in `/usr/local`. If you don't
have write access to that directory, or would rather install the `TLAPM`
elsewhere, such as in `$HOME/bin`, run the following:

```
$ pushd tlaps-1.4.5/tlapm
$ ./configure --prefix $HOME && make all
$ make install
$ popd
```


### 7. Verify the installation

Run the following command:

```
$ tlapm --config
```

It should report the versions of `zenon` and `isabelle` you installed in earlier
steps.

You can also test the `TLAPS` on any of the examples in the
`/usr/local/lib/tlaps/examples` directory (which you can easily refer to using
the option `-I +examples` to `tlapm`). For instance:

```
$ tlapm -C -I +examples/cantor Cantor1.tla
```

You will see a lot of output from Isabelle, the most important being the message
at the end stating that all obligations were proved. For more information on how
to use TLAPS, read the [tutorial](../Documentation/Tutorial.html).


### 8. Update paths

The environment variable `PATH` may need to be updated, depending on the
operating system and where `tlapm` has been installed.

Note that for calling `tlapm` from a Windows environment when it has been
installed inside Cygwin, the Windows environment path needs to be updated too.
For more details on that, see the section on setting the Windows path in
the page about [Windows installation](Binaries/Windows.html).


<!-- DO NOT EDIT BELOW THIS LINE, DO NOT REMOVE THIS LINE -->

<script type="text/javascript">
  document.write ('\x3Cscript type="text/javascript" src="'
                  + baseurl + 'assets/footer.js">\x3C/script>')
</script>
</body>
</html>
