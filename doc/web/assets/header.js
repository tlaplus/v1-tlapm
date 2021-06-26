// The menu hierarchy.
// Spaces at the beginning of the strings give the nesting level.
// The corresponding file/directory names are the same with prefixed spaces
// removed, all special characters replaced by underscores,
// all characters converted to lowercase, and ".html"
// added at the end of file names (but not directories).

// Special characters are all characters except letters, digits, "-", and "+"

// For the moment, the depth is limited to 3 levels: 0, 1, or 2 spaces.

var menumap = [
    "Home",
    "Download",
    " Binaries",
    "  Windows",
    "  Linux",
    "  MacOS",
    " Source",
    " What's new",
    " Unsupported",
    " License",
    " Previous releases",
    "Documentation",
    " Tutorial",
    "  The example",
    "  A simple proof",
    "  Hierarchical proofs",
    "  Advanced options",
    "  Other proof constructs",
    "  Tactics",
    "  Practical hints",
    " Unsupported features",
    " Publications",
    " TLA+ Hyperbook",
    " TLA+ Video Course",
    " Misc",
    "Community",
    " Contact",
    " Developers",
    " TLA+.net" /* Do not put a comma on the last line, IE8 doesn't like it */
]

/* NOTE
   For this to work, the web site must be in a directory that
   doesn't have "/content/" in its full path.
*/

var content = baseurl + 'content/'
var assets = baseurl + 'assets/'
var suffix = ".html"

var len = document.URL.length
var pathstr = document.URL.slice (content.length, len - suffix.length)
var path = pathstr.match (/[^\\\/]+/g)

var branch = [[], [], []]

// Relative path pointing to the "content/" directory
var base = ""
for (i = 1; i < path.length; i++){
    base = "../" + base
}

// Return the file name associated with a given title.
function file (title) {
    return title.replace (/[^-a-zA-Z0-9+]/g, "_").toLowerCase();
}

// Return the number of spaces at the beginning of s.
function getlevel (s) {
    for (i = 0; i < s.length; i++){
        if (s.charAt (i) != ' ') return i
    }
    return s.length
}

// Return the string s without its space prefix
function getdata (s) {
    for (i = 0; i < s.length; i++){
        if (s.charAt (i) != ' ') return s.slice (i)
    }
    return ""
}


// Parse the menumap array and find the current branch within it.
// Fill the 'branch' array with the siblings of the current path at
// each level: branch[level][i] is the i-th son of the (level-1) ancestor
// of the path.
// arguments:
//   i = current position in menumap array
//   lvl = current level being filled
// returns next position in menumap array
function findbranch (i, lvl){
    var l
    while (i < menumap.length){
        l = getlevel (menumap [i])
        if (l < lvl) return i
        if (l == lvl){
            branch[lvl].push (getdata (menumap [i]))
            if (getdata (menumap [i]).toLowerCase() == path [lvl]){
                i = findbranch (i + 1, lvl + 1)
            }else{
                i ++
            }
        }else{
            i ++
        }
    }
    return i
}

function on (prefix, depth, i) {
    if (path[depth] == file (branch[depth][i])){
        return (' class="' + prefix + 'on"')
    }else{
        return ' class="' + prefix + 'off"'
    }
}

function w (data) {
    document.writeln (data);
}

function addmenu () {
  findbranch (0, 0)

  w('<div id="wrapper">')
  w('  <div id="header">')
  w('    <div id="title">')
  w('      <a class="title" href="' + base
    + 'home.html">TLA+ Proof System</a>')
  w('    </div>')
  w('    <div class="logomsr">')
  w('      <a href="http://www.msr-inria.inria.fr">')
  w('        <img src="' + assets + '/images/logo-MS-Research-Inria-Joint-Centre-Small.png"')
  w('             alt="Microsoft Research - Inria Joint Centre"')
  w('             class="logo" />')
  w('      </a>')
  w('    </div>')
  w('  </div>')
  w('  <ul id="nav">')
  for (i = 0; i < branch[0].length; i++){
      w('    <li><a' + on ("", 0, i) + ' href="' + base + file (branch[0][i])
        + '.html">' + branch[0][i] + '</a></li>')
  }
  w('  </ul>')
  w('  <div id="transp"></div>')
  w('  <div id="content" class="clearfix">')
  w('    <div id="col_1">')
  if (branch[1].length > 0) {
      w('      <h2>Menu</h2>')
  }else{
      w('      <h2 class="white">Menu</h2>')
  }
  w('      <ul id="menu">')
  for (i = 0; i < branch[1].length; i++){
      w('        <li' + on ("menu", 1, i) + '>')
      w('          <a href="' + base + file (path[0]) + '/'
        + file (branch[1][i]) + '.html">' + branch[1][i] + '</a>')
      w('        </li>')
      if (path[1] == file (branch[1][i])){
          for (k = 0; k < branch[2].length; k++){
              w('        <li' + on ("index", 2, k) + '>')
              w('          <a href="' + base + file (path[0]) + '/'
                + file (path[1]) + '/'
                + file (branch[2][k]) + '.html">' + branch[2][k] + '</a>')
              w('        </li>')
          }
      }
  }
  w('      </ul>')
  w('    </div>')
  w('    <div id="col_2">')
}

addmenu ()

function tla_display () {
    tla_get_file_comment ();
    var divs = document.body.getElementsByTagName("div");
    var i;
    for (i = 0; i < divs.length; i++){
        var lines = divs[i].getAttribute ("lines")
        if (lines != null){
            divs[i].setAttribute("class", "listing sole");
            divs[i].innerHTML = tla_get_html (lines);
        }
    }
    divs = document.body.getElementsByTagName("tla");
    while (divs.length > 0){
        var newdiv = document.createElement("code");
        copy_attributes (divs[0], newdiv);
        newdiv.innerHTML = tla_colorize (divs[0].innerHTML);
        divs[0].parentNode.replaceChild(newdiv, divs[0]);
    }
}

function copy_attributes (srcnode, dstnode){
    var i;
    var att = srcnode.attributes;
    for (i = 0; i < att.length; i++){
        dstnode.setAttribute(att[i].name, att[i].value);
    }
}

var tla_file = "";

function tla_get_file_comment () {
    var divs = document.getElementsByTagName("file");
    var i;
    for (i = 0; i < divs.length; i++){
        if (divs[i].childNodes[0].nodeType == 8){
            var text = divs[i].childNodes[0].data.trim() + '\n';
            tla_file = text;
            break;
        }
    }
}

function tla_get_html (ref) {
    var descr = ref.split ("/");
    return tla_html_encode (tla_restrict (tla_file, descr));
}

var re_special_chars_re = /([[()|.\\+*?{}$^]|\])/;

function re_escape_string (str) {
    var res = "";
    for (i = 0; i < str.length; i++){
        if (re_special_chars_re.test(str.charAt(i))){
            res = res + '\\';
        }
        res = res + str.charAt(i);
    }
    return res;
}

function tla_restrict (text, descr) {
    if (descr.length == 1){
        if (descr[0] == "all"){
            descr[0] = "";
            descr[1] = "1-99999999";
        }else{
            descr[1] = "1";
        }
    }
    var startoff;
    var result = "";
    var lines;
    for (;descr.length >= 2; descr = descr.slice(2)){
        startoff = text.search (re_escape_string (descr[0]));
        if (startoff == -1){
            result += "\\* not found: " + descr[0];
            continue;
        }else{
            lines = text.slice(startoff).split('\n');
        }
        var ranges = descr[1].split(',');
        var i;
        for (i = 0; i < ranges.length; i++){
            var points = ranges[i].split('-');
            var start = Number(points[0]);
            var end = points.length < 2 ? start : Number(points[1]);;
            if (end >= lines.length) end = lines.length - 1;
            var j;
            var show = true;
            for (j = start; j <= end; j++){
                if (/.*hide @@.*/.test(lines[j-1])) show = false;
                if (show) result += lines[j-1] + '\n';
                if (/.*@@ show.*/.test(lines[j-1])) show = true;
            }
        }
    }
    return result;
}

// order of decreasing length guarantees that any word that is a
// substring of another will appear after it.
var tla_keywords = [
    "PROPOSITION", "ASSUMPTION", "CONSTANTS", "RECURSIVE",
    "UNCHANGED", "VARIABLES", "CONSTANT", "INSTANCE", "SUFFICES",
    "TEMPORAL", "VARIABLE", "ENABLED", "EXTENDS", "OBVIOUS",
    "OMITTED", "THEOREM", "WITNESS", "ACTION", "ASSUME",
    "CHOOSE", "DEFINE", "DOMAIN", "EXCEPT", "LAMBDA", "MODULE",
    "SUBSET", "AXIOM", "LEMMA", "LOCAL", "OTHER", "PROOF",
    "PROVE", "STATE", "UNION", "CASE", "DEFS", "ELSE", "HAVE",
    "HIDE", "ONLY", "PICK", "TAKE", "THEN", "WITH", "DEF",
    "LET", "NEW", "QED", "SF_", "USE", "WF_", "BY", "IF",
    "IN"
];

function tla_colorize (text) {
    text = text.replace (/\(\*/g, '<span class="comment">(*');
    text = text.replace (/\*\)/g, '*)</span>');
    text = text.replace (/(\\\*.*)\n/g, '<span class="comment">$1</span>\n');
    for (i = 0; i < tla_keywords.length; i++){
        var key = tla_keywords[i];
        var re = new RegExp (key, 'g');
        text = text.replace (re, '<span class="purple">' + key + '</span>');
    }
    return text;
}

function tla_html_encode (text) {
    text = text.replace (/</g, "&lt;");
    text = text.replace (/>/g, "&gt;");
    return tla_colorize (text);
}
