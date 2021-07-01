## <img src="images/logo_macosx30s.png" class="blogo" alt="[Apple logo]" />Mac OS X (10.13 and later)

The package: [`tlaps-1.4.5-i386-darwin-inst.bin`](
    https://github.com/tlaplus/tlapm/releases/latest/download/tlaps-1.4.5-i386-darwin-inst.bin)


### 1. Install   `make`

`make` is required. You can install either Apple's version from the
Apple developer tools (Xcode is available for free in the Mac App
store), or the GNU version via [Homebrew](http://brew.sh) or
[MacPorts](http://www.macports.org/ports.php?by=name&substr=gmake), or
[from source](http://www.gnu.org/software/make/).


### 2. Install the Proof System

Do *not* try to run the installer by clicking it.

You may have to change the installer's permissions with the following
command-line:

```shell
$ chmod a+x tlaps-1.4.5-i386-darwin-inst.bin
```

In order to install the proof system into `/usr/local`, run the installer as:

```shell
$ sudo ./tlaps-1.4.5-i386-darwin-inst.bin
```

(you must have an administrator account, and you will have to type your
password)

This will install the tlapm binary in `/usr/local/bin` and some other
data in `/usr/local/lib/tlaps`, including the `zenon`, `isabelle`, `z3`,
`ls4`, and `translate` binaries.

It is not recommended to install the proof system in another directory.
If you want to do it anyway, see the download instructions for Linux.
You will also have to set the PATH variable used by GUI applications by
following the instructions found on [Stack Overflow](
    http://stackoverflow.com/questions/603785/environment-variables-in-mac-os-x)


### 3. Set the toolbox's library path

We strongly recommend that you install the
[Toolbox](http://lamport.azurewebsites.net/tla/toolbox.html) (version
1.6.0 or later). You will need to add the location of the `TLAPS.tla`
file to the list of libraries used by the Toolbox. To do this, open the
Toolbox and go to "File > Preferences > TLA+ Preferences". Add the
directory where `TLAPS.tla` is located to the list of library path
locations. If you have the default installation, this directory is
`/usr/local/lib/tlaps/`.


### 4. Install CVC4 (optional)

You may want to install CVC4 to use as an additional SMT back-end for
TLAPS (the default, Z3, is included in the installer). Note that some of
our example files use CVC4 for a few proof obligations.

To install CVC4, you first need to install [Homebrew](http://brew.sh),
then follow the instructions on the [CVC4 installation page](
    https://cvc4.github.io/mac.html).


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
