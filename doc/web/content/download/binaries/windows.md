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


## <img src="images/windows_logo_only.png" class="blogo" alt="[Windows logo]" />Windows


The package:

- for 32-bit Cygwin: [`tlaps-1.4.5-i686-cygwin-inst.exe`](
    https://github.com/tlaplus/tlapm/releases/latest/download/tlaps-1.4.5-i686-cygwin-inst.exe)


### 1. Install Cygwin

[Cygwin](http://www.cygwin.com) version 3.0.7 or later is required. You need to
install the 32-bit version of Cygwin, even if your OS is 64-bit. This version of
TLAPS does **not** work on 64-bit Cygwin.


### 2. Install the Cygwin packages   `make`, `perl`, `wget`

Consult the [Cygwin manual](http://www.cygwin.com/cygwin-ug-net/setup-net.html)
for instructions on how to install Cygwin packages. Installing these packages
will bring in a number of other packages, which are also needed.


### 3. Install the Proof System

Download the [TLAPS installer](
    https://github.com/tlaplus/tlapm/releases/latest/download/tlaps-1.4.5-i686-cygwin-inst.exe)
and run the following command in a Cygwin terminal, from the directory in which
the package has been downloaded (usually `/cygdrive/c/Users/$USER/Downloads`):

```
$ ./tlaps-1.4.5-\*-cygwin-inst.exe
```

This will install the TLAPM binary in `/usr/local/bin` and some other data in
`/usr/local/lib/tlaps`, including the `zenon`, `isabelle`, `z3`, `ls4`, and
`translate` binaries.


### 4. Set the Toolbox's library path

We strongly recommend that you install the
[Toolbox](http://lamport.azurewebsites.net/tla/toolbox.html) (version 1.6.0 or
later). You will need to add the location of the `TLAPS.tla` file to the list of
libraries used by the Toolbox. To do this, open the Toolbox and go to "File \>
Preferences \> TLA+ Preferences". Add the directory where `TLAPS.tla` is located
to the list of library path locations. If you have the default installation,
this directory is `C:\cygwin\usr\local\lib\tlaps\`.


### 5. Set the Windows path

If TLAPM will be called from a Windows [environment](
    https://en.wikipedia.org/wiki/Run-time_environment)
(instead of a Cygwin environment), then certain directories need to
be added to the Windows [`PATH` environment variable](
    https://en.wikipedia.org/wiki/PATH_(variable)).
If you have the default installation, then these directories are:

- `C:\cygwin\usr\local\bin`
- `C:\cygwin\usr\bin`
- `C:\cygwin\bin`

Relevant information about setting the path can be found in the
[Cygwin documentation about paths](https://cygwin.com/faq.html#faq.using.path),
and the [Cygwin documentation about environment variables](
    https://cygwin.com/cygwin-ug-net/setup-env.html).
Within Cygwin, the previous paths are:

- `/usr/local/bin`
- `/usr/bin`
- `/bin`

The [tool `cygpath`](https://cygwin.com/cygwin-ug-net/cygpath.html)
may be useful for converting between path formats.


### 6. Install CVC4 (optional)

You may want to install CVC4 to use as an additional SMT back-end for TLAPS (the
default, Z3, is included in the installer). Note that some of our example files
use CVC4 for a few proof obligations.

To install CVC4, you should download it from [the CVC4 download page](
    http://cvc4.cs.stanford.edu/downloads/builds/win64-opt/),
then rename it and move it to `/usr/local/lib/tlaps/bin` with this command:

```
$ mv cvc4-1.7-win64-opt.exe /usr/local/lib/tlaps/bin/cvc4.exe
```


### Uninstallation

To uninstall TLAPS, open a cygwin terminal and type:

```
$ `tlapm --where`/un-inst
```

The uninstaller for an existing version of TLAPS is automatically run when the
TLAPS installer (for any version of TLAPS, including the same version) tries to
install into the same location. Because of this, **never store any important
files in the directory where TLAPS is installed**.


<!-- DO NOT EDIT BELOW THIS LINE, DO NOT REMOVE THIS LINE -->

<script type="text/javascript">
  document.write ('\x3Cscript type="text/javascript" src="'
                  + baseurl + 'assets/footer.js">\x3C/script>')
</script>
</body>
</html>
