"""Read Markdown files and create HTML files from them.

Traverses the directory tree rooted in the directory `ROOT_DIR`.
For all Markdown files encountered during this traversal,
those files that are known to this script are converted to
HTML. Any known files that are not found raise an exception
after conversion of all found files has been completed.

The conversion is performed by reading the Markdown source,
determining whether it is a redirection page or not,
and if it is, then append only a suitable HTML footer,
otherwise append both a suitable HTML header, and a suitable
HTML footer. The resulting Markdown with footer and header is
then passed to `PANDOC`, which converts it to HTML.

The program with name stored in the constant `PANDOC` (below)
is expected to be available in the runtime environment's `PATH`.

The names of the generated HTML files differ from the
corresponding Markdown sources only in their extension.
"""
import difflib
import os
import pprint
import subprocess
import sys


ROOT_DIR = 'content/'
MARKDOWN_SOURCES = [
    # the below listing is lexicographic,
    # as when browsing files
    # `content/`
    'content/community.md',
    'content/documentation.md',
    'content/download.md',
    'content/home.md',
    # `content/community/`
    'content/community/contact.md',
    'content/community/developers.md',
    'content/community/tla+_net.md',
    # `content/documentation/`
    'content/documentation/misc.md',
    'content/documentation/publications.md',
    'content/documentation/tla+_hyperbook.md',
    'content/documentation/tla+_video_course.md',
    'content/documentation/tutorial.md',
    'content/documentation/unsupported_features.md',
    # `content/documentation/tutorial/`
    'content/documentation/tutorial/a_simple_proof.md',
    'content/documentation/tutorial/advanced_options.md',
    'content/documentation/tutorial/hierarchical_proofs.md',
    'content/documentation/tutorial/other_proof_constructs.md',
    'content/documentation/tutorial/practical_hints.md',
    'content/documentation/tutorial/tactics.md',
    'content/documentation/tutorial/the_example.md',
    # `content/download/`
    'content/download/binaries.md',
    'content/download/license.md',
    'content/download/previous_releases.md',
    'content/download/source.md',
    'content/download/unsupported.md',
    'content/download/what_s_new.md',
    # `content/download/binaries/`
    'content/download/binaries/linux.md',
    'content/download/binaries/macos.md',
    'content/download/binaries/windows.md',
]
PANDOC = 'pandoc'
# the templates for the below HTML strings are in the files:
# `doc/web/assets/template-redirect.html`
# `doc/web/assets/template.html`
CONTENT_PAGE_HEADER = (
r'''<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
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
<noscript><p><b>Warning: This site uses JavaScript. Without JavaScript, you
are missing the navigation menus.</b></p><hr/></noscript>

<!-- DO NOT EDIT ABOVE THIS LINE, DO NOT REMOVE THIS LINE -->


''')
CONTENT_PAGE_FOOTER = r'''

<!-- DO NOT EDIT BELOW THIS LINE, DO NOT REMOVE THIS LINE -->

<script type="text/javascript">
  document.write ('\x3Cscript type="text/javascript" src="'
                  + baseurl + 'assets/footer.js">\x3C/script>')
</script>
</body>
</html>
'''
REDIRECT_PAGE_FOOTER = '''\
</body>
</html>
'''


def main():
    """Entry point."""
    _check_python_version()
    markdown_sources = list(MARKDOWN_SOURCES)
    unknown_markdown_files = list()
    for root, dirs, files in os.walk(ROOT_DIR):
        for name in files:
            path = os.path.join(root, name)
            r = _convert_file_to_html(
                path, markdown_sources)
            if r == 'success':
                markdown_sources.remove(path)
            elif r == 'unknown':
                unknown_markdown_files.append(path)
            else:
                assert r is None, r
    if unknown_markdown_files:
        print(
            'Found unknown Markdown files:\n{s}'.format(
                s=pprint.pformat(unknown_markdown_files)))
    if not markdown_sources:
        return
    raise FileNotFoundError((
        'Expected to find the following '
        'Markdown files too:\n{s}'
        ).format(
            s=pprint.pformat(s=markdown_sources)))


def _convert_file_to_html(path, markdown_sources):
    """Read Markdown file at `path`, and convert to HTML file.

    - if `path` is not a Markdown file, return `None`
    - if `path` is not in `markdown_sources`,
      do not convert it, and return `'unknown'`
    - otherwise, convert the file, and return `'success'`

    @type path: `str`
    @type markdown_sources: `list` of `str`
    @rtype: `str`
    """
    _, ext = os.path.splitext(path)
    if ext != '.md':
        return
    if path not in markdown_sources:
        print(f'skipping unknown Markdown file `{path}`')
        return 'unknown'
    print(f'processing file:  {path}')
    with open(path, 'rt') as f:
        md_src = f.read()
    _convert_source_to_html(md_src, path)
    return 'success'


def _convert_source_to_html(md_src, md_path):
    """Convert Markdown `md_src` to HTML, dump to file.

    The path to the HTML file to be created is
    obtained from `md_path` by replacing the
    extension `'.md'` with `'.html'`.

    @param md_src: Markdown source
    @type md_src: `str`
    @param md_path: path to Markdown source file
    @type md_path: `str`
    """
    assert os.extsep == '.', os.extsep
    basepath, ext = os.path.splitext(md_path)
    assert ext == '.md', ext
    if '<title>Redirection</title>' in md_src:
        html_src = _convert_redirection_page_to_html(md_src)
    else:
        html_src = _convert_content_page_to_html(md_src)
    html_path = basepath + '.html'
    with open(html_path, 'wt') as f:
        f.write(html_src)


def _convert_redirection_page_to_html(md_src):
    """Return HTML from converting Markdown `md_src`.

    This function appends the HTML footer for
    redirection webpages.

    @type md_src: `str`
    """
    md_src += REDIRECT_PAGE_FOOTER
    return _convert_md_to_html(md_src)


def _convert_content_page_to_html(md_src):
    """Return HTML from converting Markdown `md_src`.

    This function prepends the HTML header and
    appends the HTML footer for redirection webpages.

    @type md_src: `str`
    """
    md_src = (
        CONTENT_PAGE_HEADER + md_src + CONTENT_PAGE_FOOTER)
    return _convert_md_to_html(md_src)


def _convert_md_to_html(md_src):
    """Return HTML resulting from `md_src` via `PANDOC`.

    @type md_src: `str`
    """
    cmd = [PANDOC, '-f', 'gfm', '-t', 'html']
    proc = subprocess.Popen(
        cmd,
        text=True,
        stdin=subprocess.PIPE,
        stderr=subprocess.PIPE,
        stdout=subprocess.PIPE)
    stdout_text, stderr_text = proc.communicate(input=md_src)
    returncode = proc.wait()
    if returncode == 0:
        return stdout_text
    raise RuntimeError(
        f'`{PANDOC}` returned exit code:  {returncode}\n'
        f'and stdout:\n{stdout_text}\n'
        f'and stderr:\n{stderr_text}')



def _print_str_diff(a, b):
    """Print unified diff between strings `a` and `b`.

    @type a: `str`
    @type b: `str`
    """
    lines_1 = a.splitlines()
    lines_2 = b.splitlines()
    diff = difflib.unified_diff(lines_1, lines_2)
    msg = '\n'.join(diff)
    print(msg)


def _check_python_version():
    """Raise `RuntimeError` if running on Python < 3.7."""
    if sys.version_info.major > 3:
        return
    if (sys.version_info.major == 3 and
            sys.version_info.minor >= 7):
        return
    raise RuntimeError(
        'This script requires Python >= 3.7')


if __name__ == '__main__':
    main()
