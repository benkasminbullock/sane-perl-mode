# NAME

sane-perl-mode - a fork of cperl-mode to fix long-standing bugs

# DESCRIPTION

This is a fork of the Emacs Perl-editing mode cperl-mode.el. We made
this to fix some very long-term problems with cperl-mode.

At the moment we're documenting using this README.

# CHANGES FROM CPERL-MODE

This section describes the significant changes to the behaviour of
sane-perl-mode compared to cperl-mode. See also ["TESTING"](#testing) for
details of bug fixes.

## No error messages each time the m or s key is pressed

In cperl-mode, Emacs produces an error message about matching
parentheses not being found every time the "m" or "s" key is
pressed. In sane-perl-mode, these error messages have been
eliminated. This is the origin of the word "sane" in the name of this
fork.

Whilst labelling cperl-mode and its maintainers as "insane" might be
excessive, it's very difficult to imagine what the people who made
Emacs produce an error message each time the keys m or s are pressed
were thinking about. With Emacs 27, the screen would scroll when the
error messages were produced, so typing "m" or "s" when entering
keywords like `my` or `sub` would cause the Emacs window to suddenly
scroll. 

This bug has been reported over and over by many people to the
cperl-mode maintainers. BKB pointed the problem out to Ilya
Zakharevich on the usenet newsgroup comp.lang.perl.misc in about 2007
or so, so it's been there for at least fourteen years. However, they
have not taken any action.

Anyway the bug is fixed here. We hope it helps you restore your
sanity.

## Far-right indentation

Indenting the contents of `qw` and `qr!!x` far to the right of the
page can now be altered to indent the contents using the normal
indentation. To switch off the far-right indentation, set the option
`sane-perl-indentable-indent` to `nil` in `.emacs` or its
equivalent with

    (setq sane-perl-indentable-indent nil)

Once this option is set, the "far right" indentation

    my @array = qw!
                      far
                      right
                      indentation
                  !;

will be indented as

    my @array = qw!
        normal
        indentation
    !;

Similarly for regular expressions using the `/x` format.

This fix comes from the [jrockway fork of
cperl-mode](https://github.com/jrockway/cperl-mode/pull/54), but it
hadn't been applied in the ["HaraldJoerg"](#haraldjoerg) fork which sane-perl-mode
originates from, so it's been added on here. Further to the jrockway
fork fix, sane-perl-mode also puts the indentation of the !; at the
end on the left rather than under the final line, as shown above. The
jrockway fork currently does the following:

    my @array = qw!
        normal
        indentation
        !;

## Indent brace bug

The "indent brace bug" happens in cperl-mode when
`cperl-continued-statement-offset` is set to a non-zero value. It
causes the opening brace of a subroutine to be indented four spaces:

    sub xyz
        {

instead of

    sub xyz
    {

This is fixed in sane-perl-mode.

## Indentation styles

Sane-Perl-Mode provides various indentation styles via the function

    (sane-perl-set-style "BSD")

and examples of what the indentation styles are supposed to look
like. However, at the time we forked the module, the indentation
actually produced differed in most of the cases from the examples
provided. For example, the example of Whitesmith indentation from the
cperl-mode documentation looks like this:

    if (foo)
        {
            bar
                baz;
        label:
            {
                boon;
            }
        }
    else
        {
            stop;
        }

However, the output of `cperl-set-style` `Whitesmith`
`indent-region` is as follows:

    if (foo) {
        bar
            baz;
     label:
        {
            boon;
        }
    } else {
        stop;
    }

Because it looks like changes to the defaults of the mode caused this,
we are not sure whether to modify the indentation styles or the
examples. Generally we have followed the examples and modified the
indentation styles to look more like them, but K&R style is given as

     if (foo)
     {
     }
     else
     {

in the cperl-mode documentation, which is definitely wrong, see [this
Wikipedia
article](https://en.wikipedia.org/wiki/Indentation_style#K&R_style).

The styles where the example did not match the output are `BSD`,
`K&R`, `GNU`, and `Whitesmith`.  `C++`, `PBP`, and `PerlStyle`,
and the default `Sane-Perl` were already indenting as per the
documentation. We have altered either the settings or the example to
bring them into agreement, with the exception of the `Whitesmith`
style, where the documentation and results disagree, on only one line,
since we don't know how to reproduce that indentation using the
options.

## Documentation improvements

Spelling and grammar mistakes have been fixed. Some attempt has been
made to make the tone of the documentation more professional. Much of
the cperl-mode documentation seemed to be designed to deliberately
confuse users, or give opinions rather than facts.

We've also done some work on the one-line documentation which comes
with cperl-mode.

## Changes to defaults

Some of the default behaviours of cperl-mode have been changed.

### Underlining of trailing whitespace

The cperl-mode default of using underscores for displaying trailing
whitespace has been switched off. Trailing whitespace is harmless in
Perl, and hardly merits being highlighted in an exaggerated way,
especially since even whitespace in comments was highlighted. Further,
the underscores were also misleading. For example, after a dollar the
underscore would appear as `$_` (the default variable) when in fact
there was no `_` there.

cperl-mode requires a setting

    (setq cperl-invalid-face nil)

to stop it from adding underscores to trailing whitespace. This is
switched off by default in sane-perl-mode. To restore it, add

    (setq sane-perl-invalid-face 'underline)

to `.emacs`. 

### Untabifying by delete is off

Untabifying by delete (turning a tab character into spaces when
deleting whitespace) was switched off. It's still in the mode as a
user option.

### Font lock mode changes

Emacs has had font-lock-mode on globally by default since 2007, but in
cperl-mode the default for the variable `cperl-font-lock` is to be
turned off. 

In the development of sane-perl-mode, we discovered that the default
inherited from cperl-mode of having `sane-perl-font-lock` switched
off with Emacs' `font-lock-mode` on causes some very odd behaviour.

We've thus switched it on as the default. It can still be switched off
using

    (setq sane-perl-font-lock nil)

In this case, `font-lock-mode` itself will be switched off for the
Perl buffer as well, otherwise the option doesn't really make sense.

## Removal of obsolete and non-core support

### Version control systems

Support for the CVS, RCS, and SCCS version control systems has been
removed.

### Moose and other non-core modules

Support for Moose, Zydeco, and other module-specific keywords has been
removed.

### Opinion-comments removed

Editorial comments about the future of Perl development and other
things have been removed from the mode. Since these are a single
person's opinions, and there have been at least five maintainers of
this mode so far, it's not clear who the opinions belonged to, and it
doesn't make sense to keep them in a mode maintained by other people
who may not share the opinions.

### Removal of commented out and obsolete code

Commented-out code and clearly obsolete code referring to versions of
Emacs from the 1990s have been removed. See also [Don’t share
commented-out
code](https://www.nayuki.io/page/dont-share-commented-out-code) by
Nayuki.

# TESTING

The tests for the mode run Emacs in batch mode and then compare the
results to expected outputs using Perl's [Test::More](https://metacpan.org/pod/Test::More) framework. They
can be run using the Perl utility [prove](https://metacpan.org/pod/prove) as

    prove t/*.t

from the top directory.

Currently the following tests exist:

- Non far-right indentation

    Tests of the `qw!!` and `qr!!x` non-far-right indentation have been
    added in `t/run.t` and `t/test-regex.t`. See ["Far-right indentation"](#far-right-indentation).

- Invert-if

    CPerl mode contains a facility to switch between trailing if and
    leading if, as in

         if (condition) {
             something;
         }

    and

         something if condition;

    Testing of these in Sane Perl mode, renamed
    `sane-perl-invert-if-unless` and
    `sane-perl-invert-if-unless-modifiers`, is in `t/invert.t`

- Staircase indentation

    The staircase indentation bug is a bug where cperl-mode would indent
    as follows:

        use constant {
          ONE => 1,
            TWO => 2
        };

    Testing of the "staircase indentation" bug is in `t/staircase.t`. The
    indentation of the cperl-mode we originally forked from seems to be
    working at the moment.

- Indentation of braces

    The provisional fix of the ["Indent brace bug"](#indent-brace-bug) is tested in
    `t/indent-bug.t`

- Trailing whitespace

    Underlining of trailing whitespace is no longer the default but it is
    supported as an option. See ["Underlining of trailing
    whitespace"](#underlining-of-trailing-whitespace). Tests of its functioning, if the user chooses to switch
    it back on, is in `t/trailing.t`.

- Byte compilation

    The errors generated by Emacs on byte-compiling cperl-mode.el have all
    been fixed in sane-perl-mode.el. Tests of this are in
    `t/byte-compile.t`.

- Parsing links in Pod

    Cperl mode displays perl documentation using pod2html, but it uses an
    extra stage before displaying it in a help buffer which changes the
    links to an Emacs-valid format. There were some problems with parsing
    nested Pod commands within links. These have been fixed in
    sane-perl-mode.el. Tests are in `t/nested-pod.t`.

- Example indentations

    The test `t/doc-indent.t` tests whether sane-perl-mode produces the
    same indentation as the example indentations in the document. See
    ["Indentation styles"](#indentation-styles) for details.

- Semi-colon bug

    A test of our fix of the semicolon bug, where `};` (for example at
    the end of a BEGIN block) used to be mistakenly converted into

        }
        ;

    on applying `indent-region` is in `t/semicolon-bug.t`.

- Tests of CPerl-Mode features

    We have added some tests of CPerl-Mode features such as its documented
    indentation options in `t/indent.t` and `t/brace-option.t`, as
    regression tests to make sure that this mode doesn't start misbehaving
    in unexpected ways. All of the `cperl-mode-` options need to use
    `sane-perl-` as the prefix but otherwise should work the same way,
    unless otherwise documented. See ["Changes to defaults"](#changes-to-defaults) for what
    options have been changed so far.

# BUGS

Please report bugs at [the github issue
tracker](https://github.com/benkasminbullock/sane-perl-mode/issues). There
is also [a "discussions"
option](https://github.com/benkasminbullock/sane-perl-mode/discussions)
if you're not sure whether to report a bug or just ask a question.

# PERLTIDY EQUIVALENTS

This section details similar and equivalent commands between the
[perltidy](https://metacpan.org/pod/perltidy) utility and `sane-perl-mode`.

- sane-perl-extra-newline-before-brace

    This option is `nil` by default. Setting this to `t` is equivalent
    to `-sbl` in perltidy.

- sane-perl-indent-left-aligned-comments

    This option is `t` by default. This corresponds to setting `-ibc`
    `--indent-block-comments` in perltidy. A `nil` value corresponds to
    `-nibc` in perltidy.

- sane-perl-indent-level

    This option is `2` by default. This corresponds to `-i=2` in
    perltidy. To get the same value as perltidy's default of 4, use

        (setq sane-perl-indent-level 4)

- sane-perl-merge-trailing-else

    This option is `t` by default. Setting this to `t` is equivalent to
    `-ce` in perltidy.

# SEE ALSO

## cperl-mode

Other significant forks of cperl-mode are as follows:

- emacs-mirror

    [https://github.com/emacs-mirror/emacs/blob/master/lisp/progmodes/cperl-mode.el](https://github.com/emacs-mirror/emacs/blob/master/lisp/progmodes/cperl-mode.el)

    The original cperl-mode.el is actively being improved for modern
    versions of Emacs in the original Emacs trunk.

- HaraldJoerg

    [https://github.com/HaraldJoerg/cperl-mode](https://github.com/HaraldJoerg/cperl-mode)

    This is a fork of jrockway's cperl-mode fork. The author also
    contributes to the original Emacs cperl-mode.el at ["emacs-mirror"](#emacs-mirror).

- jrockway

    [https://github.com/jrockway/cperl-mode](https://github.com/jrockway/cperl-mode)

    This was a fork of Ilya Zakharevich's cperl-mode which was originally
    about adding Moose keywords, but then graduated to being some kind of
    default for a few years as Ilya Z. was not active.

## CPAN modules

(We have assumed that CPAN modules related to Emacs which haven't had
a release for over ten years are defunct and have not included them
here.)

- [Emacs::PDE](https://metacpan.org/pod/Emacs::PDE)

    This contains Emacs lisp scripts to run [perltidy](https://metacpan.org/pod/perltidy) and other
    facilities.

## Other information

- [PerlLanguage at EmacsWiki](https://www.emacswiki.org/emacs/PerlLanguage)
- [CPerlMode at EmacsWiki](https://www.emacswiki.org/emacs/CPerlMode)

# AUTHORS

Ben Bullock, <benkasminbullock@gmail.com>, <bkb@cpan.org>
