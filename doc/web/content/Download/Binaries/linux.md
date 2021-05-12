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


## <img src="images/logo_linux35.png" class="blogo" alt="[Tux]" />Linux

The package: [`tlaps-1.4.5-x86_64-linux-gnu-inst.bin`](
    https://github.com/tlaplus/tlapm/releases/latest/download/tlaps-1.4.5-x86_64-linux-gnu-inst.bin)


### 1. Install the Proof System

You may have to change the installer's permissions with the following
command-line:

```shell
$ chmod a+x tlaps-1.4.5-\*-linux-gnu-inst.bin
```

In order to install the proof system into `/usr/local`, run the
installer as:

```shell
$ sudo ./tlaps-1.4.5-\*-linux-gnu-inst.bin
```

(you must have an administrator account, and you will have to type your
password)

If you want to install it in some other directory *dir*, run:

```shell
$ sudo ./tlaps-1.4.5-\*-linux-gnu-inst.bin -d *dir*
```

(you must have an administrator account, and you will have to type your
password)

This will install the tlapm binary in `dir/bin` and some other data in
`dir/lib/tlaps`, including the `zenon`, `isabelle`, `z3`, `ls4`, and
`translate` binaries.


### 2. Set the toolbox's library path

We strongly recommend that you install the
[Toolbox](http://lamport.azurewebsites.net/tla/toolbox.html) (version
1.6.0 or later). You will need to add the location of the `TLAPS.tla`
file to the list of libraries used by the Toolbox. To do this, open the
Toolbox and go to "File > Preferences > TLA+ Preferences". Add the
directory where `TLAPS.tla` is located to the list of library path
locations. If you have the default installation, this directory is
`/usr/local/lib/tlaps/`.


### 3. Copy the example files

You will find some example files in `/usr/local/lib/tlaps/examples` (or
in `dir/lib/tlaps/examples`), but you cannot open these files directly
with the Toolbox because you do not have write permission to them. You
should copy the files to your home directory and open the copies.


### 4. Install CVC4 (optional)

You may want to install CVC4 to use as an additional SMT back-end for
TLAPS (the default, Z3, is included in the installer). Note that some of
our example files use CVC4 for a few proof obligations.

To install CVC4, you should download it from [the CVC4 download
page](http://cvc4.cs.stanford.edu/downloads/builds/x86_64-linux-opt/),
then rename it and move it to `/usr/local/lib/tlaps/bin` with this
command:

```shell
$ mv cvc4-1.7-x86\_64-linux-opt /usr/local/lib/tlaps/bin/cvc4
```


### Uninstallation

To uninstall TLAPS, run:

```shell
$ \`tlapm --where\`/un-inst
```

The uninstaller for an existing version of TLAPS is automatically run
when the TLAPS installer (for any version of TLAPS, including the same
version) tries to install into the same location. Because of this,
**never store any important files in the location where TLAPS is
installed**.


<!-- DO NOT EDIT BELOW THIS LINE, DO NOT REMOVE THIS LINE -->

<script type="text/javascript">
  document.write ('\x3Cscript type="text/javascript" src="'
                  + baseurl + 'assets/footer.js">\x3C/script>')
</script>
</body>
</html>
