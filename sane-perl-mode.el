;;; sane-perl-mode.el --- Perl code editing commands   -*- lexical-binding:t -*-

;; This is a fork of cperl-mode.el. See the file README.pod for more
;; information.

;; Repository:
;;     https://github.com/benkasminbullock/sane-perl-mode
;; Maintainer:
;;     Ben Bullock <benkasminbullock@gmail.com>, <bkb@cpan.org>

;; The following is the comment header of cperl-mode.el:

;; Copyright (C) 1985-1987, 1991-2020 Free Software Foundation, Inc.

;; Authors: Ilya Zakharevich
;;	    Bob Olson
;;	    Jonathan Rockway <jon@jrock.us>
;;          Harald Jörg <haj@posteo.de>
;; Keywords: languages, Perl
;; Package-Requires: ((emacs "26.1"))
;; Package-Version: 1.0

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; from the same repository where you found this file.  If not, see
;; <https://www.gnu.org/licenses/>.

;; You can either fine-tune the bells and whistles of this mode or
;; bulk enable them by putting

;; (setq sane-perl-hairy t)

;; in your .emacs file.

;; Do not forget to read micro-docs (available from `Perl' menu)   <<<<<<
;; or as help on variables `sane-perl-tips', `sane-perl-problems',         <<<<<<
;; `sane-perl-praise', `sane-perl-speed'.				   <<<<<<

;; The mode information (C-h m) provides customization help.

;;; Compatibility with older versions (for publishing on ELPA)
;; The following helpers allow sane-perl-mode.el to work with older
;; versions of Emacs.
;;
;; Whenever the minimum version is bumped (see "Package-Requires"
;; above), please eliminate the corresponding compatibility-helpers.
;; Whenever you create a new compatibility-helper, please add it here.

;; Available in Emacs 28: format-prompt
(defalias 'sane-perl--format-prompt
  (if (fboundp 'format-prompt) 'format-prompt
    (lambda (msg default)
      (if default (format "%s (default %s): " msg default)
	(concat msg ": ")))))

(eval-when-compile (require 'cl-lib))
(require 'facemenu)

(defvar msb-menu-cond)
(defvar gud-perldb-history)

(defun sane-perl-choose-color (&rest list)
  "Return the first color from LIST which is supported on the frame."
  (let (answer)
    (while list
      (or answer
	  (if (or (x-color-defined-p (car list))
		  (null (cdr list)))
	      (setq answer (car list))))
      (setq list (cdr list)))
    answer))

;;; Customization
(defgroup sane-perl nil
  "Major mode for editing Perl code."
  :prefix "sane-perl-"
  :group 'languages
  :version "20.3")

(defgroup sane-perl-indentation-details nil
  "Indentation."
  :prefix "sane-perl-"
  :group 'sane-perl)

(defgroup sane-perl-affected-by-hairy nil
  "Variables affected by `sane-perl-hairy'."
  :prefix "sane-perl-"
  :group 'sane-perl)

(defgroup sane-perl-autoinsert-details nil
  "Auto-insert tuneup."
  :prefix "sane-perl-"
  :group 'sane-perl)

(defgroup sane-perl-faces nil
  "Fontification colors."
  :link '(custom-group-link :tag "Font Lock Faces group" font-lock-faces)
  :prefix "sane-perl-"
  :group 'sane-perl)

(defgroup sane-perl-speed nil
  "Speed vs. validity tuneup."
  :prefix "sane-perl-"
  :group 'sane-perl)

(defgroup sane-perl-help-system nil
  "Help system tuneup."
  :prefix "sane-perl-"
  :group 'sane-perl)

(defgroup sane-perl-keyword-sets nil
  "Add keywords coming from Perl modules"
  :prefix "sane-perl-"
  :group 'sane-perl)


(defcustom sane-perl-extra-newline-before-brace nil
  "If true, add a newline before opening braces.
Non-nil means that if, elsif, while, until, else, for, foreach
and do constructs look like:

	if ()
	{
	}

instead of:

	if () {
	}"
  :type 'boolean
  :group 'sane-perl-autoinsert-details)

(defcustom sane-perl-extra-newline-before-brace-multiline
  sane-perl-extra-newline-before-brace
  "If true, add a newline before opening braces.
Non-nil means the same as `sane-perl-extra-newline-before-brace', but
for constructs with multiline if/unless/while/until/for/foreach condition."
  :type 'boolean
  :group 'sane-perl-autoinsert-details)

(defcustom sane-perl-indent-level 2
  "Indentation of Sane-Perl statements with respect to containing block."
  :type 'integer
  :group 'sane-perl-indentation-details)

;; It is not unusual to put both things like perl-indent-level and
;; sane-perl-indent-level in the local variable section of a file.  If only
;; one of perl-mode and sane-perl-mode is in use, a warning will be issued
;; about the variable.  Autoload these here, so that no warning is
;; issued when using either perl-mode or sane-perl-mode.
;;;###autoload(put 'sane-perl-indent-level 'safe-local-variable 'integerp)
;;;###autoload(put 'sane-perl-brace-offset 'safe-local-variable 'integerp)
;;;###autoload(put 'sane-perl-continued-brace-offset 'safe-local-variable 'integerp)
;;;###autoload(put 'sane-perl-label-offset 'safe-local-variable 'integerp)
;;;###autoload(put 'sane-perl-continued-statement-offset 'safe-local-variable 'integerp)
;;;###autoload(put 'sane-perl-extra-newline-before-brace 'safe-local-variable 'booleanp)
;;;###autoload(put 'sane-perl-merge-trailing-else 'safe-local-variable 'booleanp)

(defcustom sane-perl-lineup-step nil
  "`sane-perl-lineup' will always lineup at multiple of this number.
If nil, the value of `sane-perl-indent-level' will be used."
  :type '(choice (const nil) integer)
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-brace-imaginary-offset 0
  "Imagined indentation of a Perl open brace that actually follows a statement.
An open brace following other text is treated as if it were this far
to the right of the start of its line."
  :type 'integer
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-brace-offset 0
  "Extra indentation for braces, compared with other text in same context."
  :type 'integer
  :group 'sane-perl-indentation-details)
(defcustom sane-perl-label-offset -2
  "Offset of Sane-Perl label lines relative to usual indentation."
  :type 'integer
  :group 'sane-perl-indentation-details)
(defcustom sane-perl-min-label-indent 1
  "Minimal offset of Sane-Perl label lines."
  :type 'integer
  :group 'sane-perl-indentation-details)
(defcustom sane-perl-continued-statement-offset 2
  "Extra indent for lines not starting new statements."
  :type 'integer
  :group 'sane-perl-indentation-details)
(defcustom sane-perl-continued-brace-offset 0
  "Extra indent for substatements that start with open-braces.
This is in addition to `sane-perl-continued-statement-offset'."
  :type 'integer
  :group 'sane-perl-indentation-details)
(defcustom sane-perl-close-paren-offset -1
  "Extra indent for substatements that start with close-parenthesis."
  :type 'integer
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-indent-wrt-brace t
  "Non-nil means indent statements in if/etc block relative brace, not if/etc."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-indent-subs-specially t
  "Non-nil means indent subs that are inside other blocks (hash values, for example) relative to the beginning of the \"sub\" keyword, rather than relative to the statement that contains the declaration."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-auto-newline nil
  "If true, insert newlines automatically where appropriate.
Non-nil means automatically newline before and after braces, and
after colons and semicolons, inserted in Sane-Perl code.  The
following \\[sane-perl-electric-backspace] will remove the
inserted whitespace.  Insertion after colons requires both this
variable and `sane-perl-auto-newline-after-colon' to be set."
  :type 'boolean
  :group 'sane-perl-autoinsert-details)

(defcustom sane-perl-autoindent-on-semi nil
  "Non-nil means automatically indent after insertion of (semi)colon.
Active if `sane-perl-auto-newline' is false."
  :type 'boolean
  :group 'sane-perl-autoinsert-details)

(defcustom sane-perl-auto-newline-after-colon nil
  "Non-nil means automatically newline even after colons.
Subject to `sane-perl-auto-newline' setting."
  :type 'boolean
  :group 'sane-perl-autoinsert-details)

(defcustom sane-perl-tab-always-indent t
  "Non-nil means TAB in Sane-Perl mode should always reindent the current line.
This is regardless of where in the line point is when the TAB command is used."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-indentable-indent t
  "*Indentation used for quote-like constructs.
If nil, the value of `sane-perl-indent-level' will be used, else
indentation will be relative to the starting column of the separator
of the construct (on a previous line)"
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-font-lock t
  "If non-nil, Sane-Perl buffers will use the command `font-lock-mode'.
Can be overwritten by `sane-perl-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-electric-lbrace-space nil
  "Non-nil means { after $ should be preceded by ` '.
Can be overwritten by `sane-perl-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-electric-parens-string "({[]})<"
  "String of parentheses that should be electric in Sane-Perl.
Closing ones are electric only if the region is highlighted."
  :type 'string
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-electric-parens nil
  "Non-nil means parentheses should be electric in Sane-Perl.
Can be overwritten by `sane-perl-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-electric-parens-mark window-system
  "Not-nil means that electric parens look for active mark.
Default is yes if there is visual feedback on mark."
  :type 'boolean
  :group 'sane-perl-autoinsert-details)

(defcustom sane-perl-electric-linefeed nil
  "If true, LFD should be hairy in Sane-Perl, otherwise C-c LFD is hairy.
In any case these two mean plain and hairy linefeeds together.
Can be overwritten by `sane-perl-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-electric-keywords nil
  "Not-nil means keywords are electric in Sane-Perl.
Can be overwritten by `sane-perl-hairy' if nil.

Uses the function `abbrev-mode' to do the expansion.  If you want
to use your own abbrevs in `sane-perl-mode', but do not want keywords
to be electric, you must redefine `sane-perl-mode-abbrev-table': do
\\[edit-abbrevs], search for `sane-perl-mode-abbrev-table', and, in
that paragraph, delete the words that appear at the ends of lines and
that begin with \"sane-perl-electric\".
"
  :type '(choice (const null) boolean)
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-electric-backspace-untabify nil
  "Not-nil means electric-backspace will untabify in Sane-Perl."
  :type 'boolean
  :group 'sane-perl-autoinsert-details)

(defcustom sane-perl-hairy nil
  "Not-nil means most of the bells and whistles are enabled in Sane-Perl.
Affects: `sane-perl-font-lock', `sane-perl-electric-lbrace-space',
`sane-perl-electric-parens', `sane-perl-electric-linefeed', `sane-perl-electric-keywords',
`sane-perl-info-on-command-no-prompt', `sane-perl-clobber-lisp-bindings',
`sane-perl-lazy-help-time'."
  :type 'boolean
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-comment-column 32
  "Column to put comments in Sane-Perl (use \\[sane-perl-indent] to lineup with code)."
  :type 'integer
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-indent-comment-at-column-0 nil
  "Non-nil means that comment started at column 0 should be indentable."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-info-on-command-no-prompt nil
  "Not-nil (and non-null) means not to prompt on \\[sane-perl-info-on-command].
The opposite behavior is always available if prefixed with C-c.
Can be overwritten by `sane-perl-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-clobber-lisp-bindings nil
  "Not-nil (and non-null) means not overwrite C-h f.
The function is available on \\[sane-perl-info-on-command], \\[sane-perl-get-help].
Can be overwritten by `sane-perl-hairy' if nil."
  :type '(choice (const null) boolean)
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-lazy-help-time nil
  "Not-nil (and non-null) means to show lazy help after given idle time.
Can be overwritten by `sane-perl-hairy' to be 5 sec if nil."
  :type '(choice (const null) (const nil) integer)
  :group 'sane-perl-affected-by-hairy)

(defcustom sane-perl-pod-face 'font-lock-comment-face
  "Face for POD highlighting."
  :type 'face
  :group 'sane-perl-faces)

(defcustom sane-perl-pod-head-face 'font-lock-variable-name-face
  "Face for POD highlighting.
Font for POD headers."
  :type 'face
  :group 'sane-perl-faces)

(defcustom sane-perl-here-face 'font-lock-string-face
  "Face for here-docs highlighting."
  :type 'face
  :group 'sane-perl-faces)

(defcustom sane-perl-invalid-face nil
  "Face for highlighting trailing whitespace."
  :type 'face
  :version "21.1"
  :group 'sane-perl-faces)

(defcustom sane-perl-pod-here-fontify '(featurep 'font-lock)
  "Not-nil after evaluation means to highlight POD and here-docs sections."
  :type 'boolean
  :group 'sane-perl-faces)

(defcustom sane-perl-fontify-m-as-s t
  "Not-nil means highlight 1arg regular expression operators same as 2arg."
  :type 'boolean
  :group 'sane-perl-faces)

(defcustom sane-perl-highlight-variables-indiscriminately nil
  "Non-nil means perform additional highlighting on variables.
Currently only changes how scalar variables are highlighted.
Note that the variable is only read at initialization time for
the variable `sane-perl-font-lock-keywords-2', so changing it after you've
entered Sane-Perl mode the first time will have no effect."
  :type 'boolean
  :group 'sane-perl)

(defcustom sane-perl-pod-here-scan t
  "Not-nil means look for POD and here-docs sections during startup.
You can always make lookup from menu or using \\[sane-perl-find-pods-heres]."
  :type 'boolean
  :group 'sane-perl-speed)

(defcustom sane-perl-regexp-scan t
  "Not-nil means make marking of regular expression more thorough.
Effective only with `sane-perl-pod-here-scan'."
  :type 'boolean
  :group 'sane-perl-speed)

(defcustom sane-perl-hook-after-change t
  "Not-nil means install hook to know which regions of buffer are changed.
May significantly speed up delayed fontification.  Changes take effect
after reload."
  :type 'boolean
  :group 'sane-perl-speed)

(defcustom sane-perl-max-help-size 66
  "Non-nil means shrink-wrapping of info-buffer allowed up to these percents."
  :type '(choice integer (const nil))
  :group 'sane-perl-help-system)

(defcustom sane-perl-shrink-wrap-info-frame t
  "Non-nil means shrink-wrapping of info-buffer-frame allowed."
  :type 'boolean
  :group 'sane-perl-help-system)

(defcustom sane-perl-info-page "perl"
  "Name of the Info manual containing perl docs.
Older version of this page was called `perl5', newer `perl'."
  :type 'string
  :group 'sane-perl-help-system)

(defcustom sane-perl-use-syntax-table-text-property t
  "Non-nil means Sane-Perl sets up and uses `syntax-table' text property."
  :type 'boolean
  :group 'sane-perl-speed)

(defcustom sane-perl-use-syntax-table-text-property-for-tags
  sane-perl-use-syntax-table-text-property
  "Non-nil means: set up and use `syntax-table' text property generating TAGS."
  :type 'boolean
  :group 'sane-perl-speed)

(defcustom sane-perl-scan-files-regexp "\\.\\([pP][Llm]\\|xs\\)$"
  "Regexp to match files to scan when generating TAGS."
  :type 'regexp
  :group 'sane-perl)

(defcustom sane-perl-noscan-files-regexp
  "/\\(\\.\\.?\\|\\.git|blib\\)$"
  "Regexp to match files/dirs to skip when generating TAGS."
  :type 'regexp
  :group 'sane-perl)

(defcustom sane-perl-regexp-indent-step nil
  "Indentation used when beautifying regexps.
If nil, the value of `sane-perl-indent-level' will be used."
  :type '(choice integer (const nil))
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-indent-left-aligned-comments t
  "Non-nil means that the comment starting in leftmost column should indent."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-extra-perl-args ""
  "Extra arguments to use when starting Perl.
Currently used with `sane-perl-check-syntax' only."
  :type 'string
  :group 'sane-perl)

(defcustom sane-perl-message-electric-keyword t
  "Non-nil means that the `sane-perl-electric-keyword' prints a help message."
  :type 'boolean
  :group 'sane-perl-help-system)

(defcustom sane-perl-indent-region-fix-constructs 1
  "Amount of space to insert between `}' and `else' or `elsif'
in `sane-perl-indent-region'.  Set to nil to leave as is.  Values other
than 1 and nil will probably not work."
  :type '(choice (const nil) (const 1))
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-break-one-line-blocks-when-indent t
  "Non-nil means that one-line if/unless/while/until/for/foreach BLOCKs
need to be reformatted into multiline ones when indenting a region."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-fix-hanging-brace-when-indent t
  "Non-nil means that BLOCK-end `}' may be put on a separate line
when indenting a region.
Braces followed by else/elsif/while/until are excepted."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-merge-trailing-else t
  "Non-nil means that BLOCK-end `}' followed by else/elsif/continue
may be merged to be on the same line when indenting a region."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-indent-parens-as-block nil
  "Non-nil means that non-block ()-, {}- and []-groups are indented as blocks,
but for trailing \",\" inside the group, which won't increase indentation.
One should tune up `sane-perl-close-paren-offset' as well."
  :type 'boolean
  :group 'sane-perl-indentation-details)

(defcustom sane-perl-syntaxify-by-font-lock t
  "Non-nil means that Sane-Perl uses the `font-lock' routines for syntaxification."
  :type '(choice (const message) boolean)
  :group 'sane-perl-speed)

(defcustom sane-perl-syntaxify-unwind
  t
  "Non-nil means that Sane-Perl unwinds to a start of a long construction
when syntaxifying a chunk of buffer."
  :type 'boolean
  :group 'sane-perl-speed)

(defcustom sane-perl-syntaxify-for-menu
  t
  "Non-nil means that Sane-Perl syntaxifies up to the point before showing menu.
This way enabling/disabling of menu items is more correct."
  :type 'boolean
  :group 'sane-perl-speed)

(defcustom sane-perl-ps-print-face-properties
  '((font-lock-keyword-face		nil nil		bold shadow)
    (font-lock-variable-name-face	nil nil		bold)
    (font-lock-function-name-face	nil nil		bold italic box)
    (font-lock-constant-face		nil "LightGray"	bold)
    (sane-perl-array-face		nil "LightGray"	bold underline)
    (sane-perl-hash-face		nil "LightGray"	bold italic underline)
    (font-lock-comment-face		nil "LightGray"	italic)
    (font-lock-string-face		nil nil		italic underline)
    (sane-perl-nonoverridable-face	nil nil		italic underline)
    (font-lock-type-face		nil nil		underline)
    (font-lock-warning-face		nil "LightGray"	bold italic box)
    (underline				nil "LightGray"	strikeout))
  "List given as an argument to `ps-extend-face-list' in `sane-perl-ps-print'."
  :type '(repeat (cons symbol
		       (cons (choice (const nil) string)
			     (cons (choice (const nil) string)
				   (repeat symbol)))))
  :group 'sane-perl-faces)

(defcustom sane-perl-perldoc-program "perldoc"
  "Path to the shell command perldoc."
  :type 'file
  :group 'sane-perl
  :version 28)

(defcustom sane-perl-pod2html-program "pod2html"
  "Path to the shell command pod2html."
  :type 'file
  :group 'sane-perl
  :version 28)

(defvar sane-perl-dark-background
  (sane-perl-choose-color "navy" "os2blue" "darkgreen"))
(defvar sane-perl-dark-foreground
  (sane-perl-choose-color "orchid1" "orange"))

(defface sane-perl-nonoverridable-face
  `((((class grayscale) (background light))
     (:background "Gray90" :slant italic :underline t))
    (((class grayscale) (background dark))
     (:foreground "Gray80" :slant italic :underline t :weight bold))
    (((class color) (background light))
     (:foreground "dark olive green"))
    (((class color) (background dark))
     (:foreground ,sane-perl-dark-foreground))
    (t (:weight bold :underline t)))
  "Font Lock mode face used non-overridable keywords and modifiers of regexps."
  :group 'sane-perl-faces)

(defface sane-perl-array-face
  `((((class grayscale) (background light))
     (:background "Gray90" :weight bold))
    (((class grayscale) (background dark))
     (:foreground "Gray80" :weight bold))
    (((class color) (background light))
     (:foreground "Blue"))
    (((class color) (background dark))
     (:foreground "yellow" :background ,sane-perl-dark-background :weight bold))
    (t (:weight bold)))
  "Font Lock mode face used to highlight array names."
  :group 'sane-perl-faces)

(defface sane-perl-hash-face
  `((((class grayscale) (background light))
     (:background "Gray90" :weight bold :slant italic))
    (((class grayscale) (background dark))
     (:foreground "Gray80" :weight bold :slant italic))
    (((class color) (background light))
     (:foreground "dark violet"))
    (((class color) (background dark))
     (:foreground "Red" :background ,sane-perl-dark-background :weight bold :slant italic))
    (t (:weight bold :slant italic)))
  "Font Lock mode face used to highlight hash names."
  :group 'sane-perl-faces)



;;; Short extra-docs.

(defvar sane-perl-tips 'please-ignore-this-line
  "Note that to enable Compile choices in the menu you need to install
mode-compile.el.

To make Emacs default to `sane-perl-mode' on Perl files, put the
following into .emacs:

  (defalias \\='perl-mode \\='sane-perl-mode)

Get perl5-info from
  $CPAN/doc/manual/info/perl5-old/perl5-info.tar.gz
Also, one can generate a newer documentation running `pod2texi' converter
  $CPAN/doc/manual/info/perl5/pod2texi-0.1.tar.gz

If you use imenu-go, run imenu on perl5-info buffer (you can do it
from Perl menu).  If many files are related, generate TAGS files from
Tools/Tags submenu in Perl menu.

If some class structure is too complicated, use Tools/Hierarchy-view
from Perl menu, or hierarchic view of imenu.  The second one uses the
current buffer only, the first one requires generation of TAGS from
Perl/Tools/Tags menu beforehand.

Run Perl/Tools/Insert-spaces-if-needed to fix your lazy typing.

Switch auto-help on/off with Perl/Tools/Auto-help.

Though with contemporary Emaxen Sane-Perl mode should maintain the correct
parsing of Perl even when editing, sometimes it may be lost.  Fix this by

  \\[normal-mode]

In cases of more severe confusion sometimes it is helpful to do

  \\[load-library] sane-perl-mode RET
  \\[normal-mode]

Before reporting (non-)problems look in the problem section of online
micro-docs on what I know about Sane-Perl problems.")

(defvar sane-perl-problems 'please-ignore-this-line
  "Description of problems in Sane-Perl mode.
`fill-paragraph' on a comment may leave the point behind the
paragraph.  It also triggers a bug in some versions of Emacs (Sane-Perl tries
to detect it and bulk out).")

(defvar sane-perl-praise "")

(defvar sane-perl-speed "")

(defvar sane-perl-tips-faces 'please-ignore-this-line
  "Sane-Perl mode uses the following faces for highlighting:

  `sane-perl-array-face'			Array names
  `sane-perl-hash-face'			Hash names
  `font-lock-comment-face'	Comments, PODs and whatever is considered
				syntactically to be not code
  `font-lock-constant-face'	HERE-doc delimiters, labels, delimiters of
				2-arg operators s/y/tr/ or of RExen,
  `font-lock-warning-face'	Special-cased m// and s//foo/,
  `font-lock-function-name-face' _ as a target of a file tests, file tests,
				subroutine names at the moment of definition
				(except those conflicting with Perl operators),
				package names (when recognized), format names
  `font-lock-keyword-face'	Control flow switch constructs, declarators
  `sane-perl-nonoverridable-face'	Non-overridable keywords, modifiers of RExen
  `font-lock-string-face'	Strings, qw() constructs, RExen, POD sections,
				literal parts and the terminator of formats
				and whatever is syntactically considered
				as string literals
  `font-lock-type-face'		Overridable keywords
  `font-lock-variable-name-face' Variable declarations, indirect array and
				hash names, POD headers/item names
  `sane-perl-invalid-face'		Trailing whitespace

Note that in several situations the highlighting tries to inform about
possible confusion, such as different colors for function names in
declarations depending on what they (do not) override, or special cases
m// and s/// which do not do what one would expect them to do.

Help with best setup of these faces for printout requested (for each of
the faces: please specify bold, italic, underline, shadow and box.)

In regular expressions (including character classes):
  `font-lock-string-face'	\"Normal\" stuff and non-0-length constructs
  `font-lock-constant-face':	Delimiters
  `font-lock-warning-face'	Special-cased m// and s//foo/,
				Mismatched closing delimiters, parens
				we couldn't match, misplaced quantifiers,
				unrecognized escape sequences
  `sane-perl-nonoverridable-face'	Modifiers, as in gism in m/REx/gism
  `font-lock-type-face'		Escape sequences with arguments (\\x \\23 \\p \\N)
				and others match-a-char escape sequences
  `font-lock-keyword-face'	Capturing parens, and |
  `font-lock-function-name-face' Special symbols: $ ^ . [ ] [^ ] (?{ }) (??{ })
				\"Range -\" in character classes
  `font-lock-builtin-face'	\"Remaining\" 0-length constructs, multipliers
				?+*{}, not-capturing parens, leading
				backslashes of escape sequences
  `font-lock-variable-name-face' Interpolated constructs, embedded code,
				POSIX classes (inside charclasses)
  `font-lock-comment-face'	Embedded comments

")



;;; Portability stuff:

(defvar sane-perl-del-back-ch
  (car (append (where-is-internal 'delete-backward-char)
	       (where-is-internal 'backward-delete-char-untabify)))
  "Character generated by key bound to `delete-backward-char'.")

(and (vectorp sane-perl-del-back-ch) (= (length sane-perl-del-back-ch) 1)
     (setq sane-perl-del-back-ch (aref sane-perl-del-back-ch 0)))

(defun sane-perl-putback-char (c)		; Emacs 19
  (push c unread-command-events))       ; Avoid undefined warning

(defvar sane-perl-do-not-fontify
  ;; FIXME: This is not doing what it claims!
  (if (string< emacs-version "19.30")
      'fontified
    'lazy-lock)
  "Text property which inhibits refontification.")

(defsubst sane-perl-put-do-not-fontify (from to &optional post)
  ;; If POST, do not do it with postponed fontification
  (if (and post sane-perl-syntaxify-by-font-lock)
      nil
    (put-text-property (max (point-min) (1- from))
		       to sane-perl-do-not-fontify t)))

(defcustom sane-perl-mode-hook nil
  "Hook run by Sane-Perl mode."
  :type 'hook
  :group 'sane-perl)

(defvar sane-perl-syntax-state nil)
(defvar sane-perl-syntax-done-to nil)

;; Make customization possible "in reverse"
(defsubst sane-perl-val (symbol &optional default hairy)
  (cond
   ((eq (symbol-value symbol) 'null) default)
   (sane-perl-hairy (or hairy t))
   (t (symbol-value symbol))))


(defun sane-perl-make-indent (column &optional minimum keep)
 "Indent from point with tabs and spaces until COLUMN is reached.
MINIMUM is like in `indent-to', which see.
Unless KEEP, removes the old indentation."
 (or keep
      (delete-horizontal-space))
  (indent-to column minimum))

(eval-when-compile
  (mapc #'require '(imenu easymenu etags timer man info)))

(define-abbrev-table 'sane-perl-mode-electric-keywords-abbrev-table
  (mapcar (lambda (x)
            (let ((name (car x))
                  (fun (cadr x)))
              (list name name fun :system t)))
          '(("if" sane-perl-electric-keyword)
            ("elsif" sane-perl-electric-keyword)
            ("while" sane-perl-electric-keyword)
            ("until" sane-perl-electric-keyword)
            ("unless" sane-perl-electric-keyword)
            ("else" sane-perl-electric-else)
            ("continue" sane-perl-electric-else)
            ("for" sane-perl-electric-keyword)
            ("foreach" sane-perl-electric-keyword)
            ("formy" sane-perl-electric-keyword)
            ("foreachmy" sane-perl-electric-keyword)
            ("do" sane-perl-electric-keyword)
            ("=pod" sane-perl-electric-pod)
            ("=begin" sane-perl-electric-pod t)
            ("=over" sane-perl-electric-pod)
            ("=head1" sane-perl-electric-pod)
            ("=head2" sane-perl-electric-pod)
            ("=head3" sane-perl-electric-pod)
            ("=head4" sane-perl-electric-pod)
            ("=for" sane-perl-electric-pod)
            ("=encoding" sane-perl-electric-pod)
            ("pod" sane-perl-electric-pod)
            ("over" sane-perl-electric-pod)
            ("head1" sane-perl-electric-pod)
            ("head2" sane-perl-electric-pod)
            ("head3" sane-perl-electric-pod)
            ("head4" sane-perl-electric-pod)))
  "Abbrev table for electric keywords.  Controlled by `sane-perl-electric-keywords'."
  :case-fixed t
  :enable-function (lambda () (sane-perl-val 'sane-perl-electric-keywords)))

(define-abbrev-table 'sane-perl-mode-abbrev-table ()
  "Abbrev table in use in Sane-Perl mode buffers."
  :parents (list sane-perl-mode-electric-keywords-abbrev-table))

(when (boundp 'edit-var-mode-alist)
  (add-to-list 'edit-var-mode-alist '(perl-mode (regexp . "^sane-perl-"))))

(defvar sane-perl-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "{" 'sane-perl-electric-lbrace)
    (define-key map "[" 'sane-perl-electric-paren)
    (define-key map "(" 'sane-perl-electric-paren)
    (define-key map "<" 'sane-perl-electric-paren)
    (define-key map "}" 'sane-perl-electric-brace)
    (define-key map "]" 'sane-perl-electric-rparen)
    (define-key map ")" 'sane-perl-electric-rparen)
    (define-key map ";" 'sane-perl-electric-semi)
    (define-key map ":" 'sane-perl-electric-terminator)
    (define-key map "\C-j" 'newline-and-indent)
    (define-key map "\C-c\C-j" 'sane-perl-linefeed)
    (define-key map "\C-c\C-t" 'sane-perl-invert-if-unless)
    (define-key map "\C-c\C-a" 'sane-perl-toggle-auto-newline)
    (define-key map "\C-c\C-k" 'sane-perl-toggle-abbrev)
    (define-key map "\C-c\C-w" 'sane-perl-toggle-construct-fix)
    (define-key map "\C-c\C-f" 'auto-fill-mode)
    (define-key map "\C-c\C-e" 'sane-perl-toggle-electric)
    (define-key map "\C-c\C-b" 'sane-perl-find-bad-style)
    (define-key map "\C-c\C-p" 'sane-perl-pod-spell)
    (define-key map "\C-c\C-d" 'sane-perl-here-doc-spell)
    (define-key map "\C-c\C-n" 'sane-perl-narrow-to-here-doc)
    (define-key map "\C-c\C-v" 'sane-perl-next-interpolated-REx)
    (define-key map "\C-c\C-x" 'sane-perl-next-interpolated-REx-0)
    (define-key map "\C-c\C-y" 'sane-perl-next-interpolated-REx-1)
    (define-key map "\C-c\C-ha" 'sane-perl-toggle-autohelp)
    (define-key map "\C-c\C-hp" 'sane-perl-perldoc)
    (define-key map "\C-c\C-hP" 'sane-perl-perldoc-at-point)
    (define-key map "\e\C-q" 'sane-perl-indent-exp) ; Usually not bound
    (define-key map [(control meta ?|)] 'sane-perl-lineup)
    (define-key map "\177" 'sane-perl-electric-backspace)
    (define-key map "\t" 'sane-perl-indent-command)
    ;; don't clobber the backspace binding:
    (define-key map [(control ?c) (control ?h) ?F] 'sane-perl-info-on-command)
    (if (sane-perl-val 'sane-perl-clobber-lisp-bindings)
        (progn
	  (define-key map [(control ?h) ?f]
	    'sane-perl-info-on-command)
	  (define-key map [(control ?h) ?v]
	    'sane-perl-get-help)
	  (define-key map [(control ?c) (control ?h) ?f]
	    (key-binding "\C-hf"))
	  (define-key map [(control ?c) (control ?h) ?v]
	    (key-binding "\C-hv")))
      (define-key map [(control ?c) (control ?h) ?f]
        'sane-perl-info-on-current-command)
      (define-key map [(control ?c) (control ?h) ?v]
	'sane-perl-get-help))
    (substitute-key-definition
     'indent-sexp 'sane-perl-indent-exp
     map global-map)
    (substitute-key-definition
     'indent-region 'sane-perl-indent-region
     map global-map)
    (substitute-key-definition
     'indent-for-comment 'sane-perl-indent-for-comment
     map global-map)
    map)
  "Keymap used in Sane-Perl mode.")

;;; Menu
(defvar sane-perl-lazy-installed)
(defvar sane-perl-old-style nil)
(easy-menu-define
  sane-perl-menu sane-perl-mode-map "Menu for Sane-Perl mode"
  '("Perl"
    ["Beginning of function" beginning-of-defun t]
    ["End of function" end-of-defun t]
    ["Mark function" mark-defun t]
    ["Indent expression" sane-perl-indent-exp t]
    ["Fill paragraph/comment" fill-paragraph t]
    "----"
    ["Line up a construction" sane-perl-lineup (use-region-p)]
    ["Invert if/unless/while etc" sane-perl-invert-if-unless t]
    ("Regexp"
     ["Beautify" sane-perl-beautify-regexp
      sane-perl-use-syntax-table-text-property]
     ["Beautify one level deep" (sane-perl-beautify-regexp 1)
      sane-perl-use-syntax-table-text-property]
     ["Beautify a group" sane-perl-beautify-level
      sane-perl-use-syntax-table-text-property]
     ["Beautify a group one level deep" (sane-perl-beautify-level 1)
      sane-perl-use-syntax-table-text-property]
     ["Contract a group" sane-perl-contract-level
      sane-perl-use-syntax-table-text-property]
     ["Contract groups" sane-perl-contract-levels
      sane-perl-use-syntax-table-text-property]
     "----"
     ["Find next interpolated" sane-perl-next-interpolated-REx
      (next-single-property-change (point-min) 'REx-interpolated)]
     ["Find next interpolated (no //o)"
      sane-perl-next-interpolated-REx-0
      (or (text-property-any (point-min) (point-max) 'REx-interpolated t)
	  (text-property-any (point-min) (point-max) 'REx-interpolated 1))]
     ["Find next interpolated (neither //o nor whole-REx)"
      sane-perl-next-interpolated-REx-1
      (text-property-any (point-min) (point-max) 'REx-interpolated t)])
    ["Insert spaces if needed to fix style" sane-perl-find-bad-style t]
    ["Refresh \"hard\" constructions" sane-perl-find-pods-heres t]
    "----"
    ["Indent region" sane-perl-indent-region (use-region-p)]
    ["Comment region" sane-perl-comment-region (use-region-p)]
    ["Uncomment region" sane-perl-uncomment-region (use-region-p)]
    "----"
    ["Run" mode-compile (fboundp 'mode-compile)]
    ["Kill" mode-compile-kill (and (fboundp 'mode-compile-kill)
				   (get-buffer "*compilation*"))]
    ["Next error" next-error (get-buffer "*compilation*")]
    ["Check syntax" sane-perl-check-syntax (fboundp 'mode-compile)]
    "----"
    ["Debugger" sane-perl-db t]
    "----"
    ("Tools"
     ["Imenu" imenu (fboundp 'imenu)]
     ["Imenu on Perl Info" sane-perl-imenu-on-info (featurep 'imenu)]
     "----"
     ["Ispell PODs" sane-perl-pod-spell
      ;; Better not to update syntaxification here:
      ;; debugging syntaxification can be broken by this???
      (or
       (get-text-property (point-min) 'in-pod)
       (< (progn
	    (and sane-perl-syntaxify-for-menu
		 (sane-perl-update-syntaxification (point-max) (point-max)))
	    (next-single-property-change (point-min) 'in-pod nil (point-max)))
	  (point-max)))]
     ["Ispell HERE-DOCs" sane-perl-here-doc-spell
      (< (progn
	   (and sane-perl-syntaxify-for-menu
		(sane-perl-update-syntaxification (point-max) (point-max)))
	   (next-single-property-change (point-min) 'here-doc-group nil (point-max)))
	 (point-max))]
     ["Narrow to this HERE-DOC" sane-perl-narrow-to-here-doc
      (eq 'here-doc  (progn
		       (and sane-perl-syntaxify-for-menu
			    (sane-perl-update-syntaxification (point) (point)))
		       (get-text-property (point) 'syntax-type)))]
     ["Select this HERE-DOC or POD section"
      sane-perl-select-this-pod-or-here-doc
      (memq (progn
	      (and sane-perl-syntaxify-for-menu
		   (sane-perl-update-syntaxification (point) (point)))
	      (get-text-property (point) 'syntax-type))
	    '(here-doc pod))]
     "----"
     ["Sane-Perl pretty print (experimental)" sane-perl-ps-print
      (fboundp 'ps-extend-face-list)]
     "----"
     ["Syntaxify region" sane-perl-find-pods-heres-region
      (use-region-p)]
     ["Debug errors in delayed fontification" sane-perl-emulate-lazy-lock t]
     ["Debug unwind for syntactic scan" sane-perl-toggle-set-debug-unwind t]
     ["Debug backtrace on syntactic scan (BEWARE!!!)"
      (sane-perl-toggle-set-debug-unwind nil t) t]
     "----"
     ["Class Hierarchy from TAGS" sane-perl-tags-hier-init t]
     ("Tags"
      ["Create tags for current file" (sane-perl-write-tags nil t) t]
      ["Add tags for current file" (sane-perl-write-tags) t]
      ["Create tags for Perl files in directory"
       (sane-perl-write-tags nil t nil t) t]
      ["Add tags for Perl files in directory"
       (sane-perl-write-tags nil nil nil t) t]
      ["Create tags for Perl files in (sub)directories"
       (sane-perl-write-tags nil t t t) t]
      ["Add tags for Perl files in (sub)directories"
       (sane-perl-write-tags nil nil t t) t]))
    ("Perl docs"
     ["Define word at point" imenu-go-find-at-position
      (fboundp 'imenu-go-find-at-position)]
     ["Help on function" sane-perl-info-on-command t]
     ["Help on function at point" sane-perl-info-on-current-command t]
     ["Help on symbol at point" sane-perl-get-help t]
     ["Perldoc" sane-perl-perldoc t]
     ["Perldoc on word at point" sane-perl-perldoc-at-point t]
     ["View manpage of POD in this file" sane-perl-build-manpage t]
     ["Auto-help on" sane-perl-lazy-install
      (not sane-perl-lazy-installed)]
     ["Auto-help off" sane-perl-lazy-unstall
      sane-perl-lazy-installed])
    ("Toggle..."
     ["Auto newline" sane-perl-toggle-auto-newline t]
     ["Electric parens" sane-perl-toggle-electric t]
     ["Electric keywords" sane-perl-toggle-abbrev t]
     ["Fix whitespace on indent" sane-perl-toggle-construct-fix t]
     ["Auto-help on Perl constructs" sane-perl-toggle-autohelp t]
     ["Auto fill" auto-fill-mode t])
    ("Indent styles..."
     ["Sane-Perl" (sane-perl-set-style "Sane-Perl") t]
     ["PBP" (sane-perl-set-style  "PBP") t]
     ["PerlStyle" (sane-perl-set-style "PerlStyle") t]
     ["GNU" (sane-perl-set-style "GNU") t]
     ["C++" (sane-perl-set-style "C++") t]
     ["K&R" (sane-perl-set-style "K&R") t]
     ["BSD" (sane-perl-set-style "BSD") t]
     ["Whitesmith" (sane-perl-set-style "Whitesmith") t]
     ["Memorize Current" (sane-perl-set-style "Current") t]
     ["Memorized" (sane-perl-set-style-back) sane-perl-old-style])
    ("Micro-docs"
     ["Tips" (describe-variable 'sane-perl-tips) t]
     ["Problems" (describe-variable 'sane-perl-problems) t]
     ["Speed" (describe-variable 'sane-perl-speed) t]
     ["Praise" (describe-variable 'sane-perl-praise) t]
     ["Faces" (describe-variable 'sane-perl-tips-faces) t]
     ["Sane-Perl mode" (describe-function 'sane-perl-mode) t])))

;; These two must be unwound, otherwise take exponential time
(defconst sane-perl-maybe-white-and-comment-rex "[ \t\n]*\\(#[^\n]*\n[ \t\n]*\\)*"
"Regular expression to match optional whitespace with interspersed comments.
Should contain exactly one group.")

;; This one is tricky to unwind; still very inefficient...
(defconst sane-perl-white-and-comment-rex "\\([ \t\n]\\|#[^\n]*\n\\)+"
"Regular expression to match whitespace with interspersed comments.
Should contain exactly one group.")

(defconst sane-perl-keyword-rex "[a-zA-Z_][a-zA-Z_0-9:']*"
  "Regular expression to match a Perl keyword")
(defconst sane-perl-label-rex "[a-zA-Z_][a-zA-Z0-9_]*:[^:]"
  "Regular expression which matches the labels used in goto and next statements")

;;; Perl core keywords and regular expressions
;; The following code allows Emacs to load different
;; keyword sets for fontification / indenting / indexing
;; either automatically or by user command(s).

(defcustom sane-perl-automatic-keyword-sets t
  "If true, then sane-perl-mode will enable keywords for a buffer
when it finds the modules which export them in the buffer's file."
  :type 'boolean
  :group 'sane-perl-keyword-sets)

(defvar sane-perl-core-namespace-declare-keywords
  '("package" "bootstrap")
  "Keywords which introduce a namespace in Perl")

(defvar sane-perl-core-namespace-ref-keywords
  '("require" "use" "no")
  "Keywords which introduce a namespace in Perl")

(defvar sane-perl-core-functions-for-font-lock
  '("CORE" "__FILE__" "__LINE__" "__PACKAGE__" "__SUB__"
    "abs" "accept" "alarm" "and" "atan2"
    "bind" "binmode" "bless" "bootstrap"
    "caller" "chdir" "chmod" "chown" "chr" "chroot" "close" "closedir"
    "cmp" "connect" "continue" "cos" "crypt"
    "dbmclose" "dbmopen" "die" "dump"
    "endgrent" "endhostent" "endnetent" "endprotoent" "endpwent"
    "endservent" "eof" "eq" "exec" "exit" "exp"
    "fc" "fcntl" "fileno" "flock" "fork" "formline"
    "ge" "getc" "getgrent" "getgrgid" "getgrnam" "gethostbyaddr"
    "gethostbyname" "gethostent" "getlogin" "getnetbyaddr" "getnetbyname"
    "getnetent" "getpeername" "getpgrp" "getppid" "getpriority"
    "getprotobyname" "getprotobynumber" "getprotoent"
    "getpwent" "getpwnam" "getpwuid" "getservbyname"
    "getservbyport" "getservent" "getsockname"
    "getsockopt" "glob" "gmtime" "gt"
    "hex"
    "index" "int" "ioctl"
    "join"
    "kill"
    "lc" "lcfirst" "le" "length" "link" "listen" "localtime" "lock" "log"
    "lstat" "lt"
    "mkdir" "msgctl" "msgget" "msgrcv" "msgsnd"
    "ne" "not"
    "oct" "open" "opendir" "or" "ord"
    "pack" "pipe"
    "quotemeta"
    "rand" "read" "readdir" "readline" "readlink" "readpipe" "recv" "ref"
    "rename" "require" "reset" "reverse" "rewinddir" "rindex" "rmdir"
    "seek" "seekdir" "select" "semctl" "semget" "semop" "send" "setgrent"
    "sethostent" "setnetent" "setpgrp" "setpriority" "setprotoent"
    "setpwent" "setservent" "setsockopt" "shmctl" "shmget" "shmread"
    "shmwrite" "shutdown" "sin" "sleep" "socket" "socketpair" "sprintf"
    "sqrt" "srand" "stat" "substr" "symlink" "syscall" "sysopen" "sysread"
    "sysseek" "system" "syswrite"
    "tell" "telldir" "time" "times" "truncate"
    "uc" "ucfirst" "umask" "unlink" "unpack" "utime"
    "values" "vec"
    "wait" "waitpid" "wantarray" "warn" "write"
    "x" "xor")
  "The list of functions to be font-locked")

(defvar sane-perl-core-sub-keywords
  '("sub")
  "Keywords starting a subroutine in Perl core")

(defvar sane-perl-core-sub-ref-keywords nil
  "Keywords referencing a subroutine in Perl core")

(defvar sane-perl-core-block-init-keywords
  '("for" "foreach" "if" "unless" "until" "while")
  "Keywords which start a conditional/loop")

(defvar sane-perl-core-block-continuation-keywords
  '("else" "elsif" "continue")
  "Keywords which continue control flow with another block")

(defvar sane-perl-core-named-block-keywords
  '("BEGIN" "CHECK" "END" "INIT" "UNITCHECK")
  "These keywords introduce a block which ends a statement
   without \\='sub\\=', and without a semicolon")

(defvar sane-perl-core-special-sub-keywords
  '("AUTOLOAD" "DESTROY")
  "Subroutines with predefined names")

(defvar sane-perl-core-declaring-keywords
  '("local" "my" "our" "state")
  "Keywords preceding variable names")

(defvar sane-perl-core-flow-control-keywords
  (append sane-perl-core-sub-keywords
          sane-perl-core-namespace-declare-keywords
          sane-perl-core-declaring-keywords
          sane-perl-core-block-init-keywords
          sane-perl-core-block-continuation-keywords
          sane-perl-core-named-block-keywords
          '(
            "break"
            "catch"
            "default" "die" "do"
            "eval" "evalbytes" "exec" "exit"
            "for" "foreach" "finally"
            "given" "goto"
            "last"
            "next"
            "redo" "require" "return"
            "try"
            "use"
            "when"))
  "Keywords for flow control")

(defvar sane-perl-core-nonoverridable-keywords
  (append sane-perl-core-flow-control-keywords
          sane-perl-core-special-sub-keywords
    '("__END__" "__DATA__"
    "catch" "chop" "chomp"
    "defined" "delete" "each"
    "exists" "format" "finally"
    "grep" "keys" "m" "map"
    "no" "pop" "pos" "print" "printf" "prototype" "push"
    "q" "qq" "qw" "qx" "s" "say" "scalar" "shift"
    "sort" "splice" "split" "study" "sub" "tie" "tied" "tr" "try"
    "undef" "unshift" "untie"
    "y"))
  "Keywords shown as non-overridable (though some of them are)")

(defvar sane-perl-core-after-label-keywords
  '("do" "for" "foreach" "until" "while")
  "Keywords which can follow a label")
(defvar sane-perl-core-before-label-keywords
  '("break" "continue" "goto" "last" "next" "redo")
  "Keywords which require a label as target")

(defvar sane-perl-keyword-set-alist nil
  "Maps regular expressions to keyword sets.
Each element in this list is a two-element list consisting of a
regular expression, and an extra keyword set to be applied if the
regexp is found in the current buffer.")

(defvar-local sane-perl-activated-keyword-sets nil
  "A list of keyword sets which have been activated for the current buffer.")
(put 'sane-perl-activated-keyword-sets 'permanent-local t)

(defvar-local sane-perl-deactivated-keyword-sets nil
  "A list of keyword sets which have been deactivated for the current buffer.")
(put 'sane-perl-deactivated-keyword-sets 'permanent-local t)

(defvar-local sane-perl-active-keyword-sets nil
  "The list of keyword sets which is active in the current buffer")

(defvar-local sane-perl-inactive-keyword-sets nil
  "The list of keyword sets which isn't active in the current buffer")

(defvar-local sane-perl-keywords-plist nil
  "The categorized list of Perl keywords.")

(defvar sane-perl-tags-keywords-plist nil
  "The categorized list of Perl keywords for TAGS.
Unlike sane-perl-keywords-plist, this one is not buffer-local.  TAGS
files contain entries from different sources which might have
different keyword sets.")

;; regexps used in TAGS files are global
(defvar sane-perl--tags-namespace-declare-regexp   nil)
(defvar sane-perl--tags-sub-regexp                 nil)

(defun sane-perl-add-keyword-set (name keyword-set &optional regexp)
  "Define a new KEYWORD-SET to be applied if a buffer matches REGEXP.
A keyword set is a property list matching keyword categories to
lists of keywords.

Example:  (sane-perl-add-keyword-set \"use MooseX::Declare;\"
                                 \\='(:namespace-declare (\"class\")
                                   :sub (\"method\")
                                   :functions (\"has\" \"extends\")))

In this example, for a Perl module
which uses MooseX::Declare: \"class\" introduces a namespace,
\"method\" is treated as starting a subroutine, and \"has\" and
extends are shown like builtin functions."
  (add-to-list 'sane-perl-keyword-set-alist
               (list name
                     (or regexp
                         (concat "^[\t ]*use[\t *]+"
                                 (symbol-name name)
                                 "\\W"))
                     keyword-set))
  (sane-perl-add-keywords sane-perl-tags-keywords-plist keyword-set)
  (setq sane-perl--tags-namespace-declare-regexp
        (regexp-opt (sane-perl-tags-keywords ':namespace-declare))
        sane-perl--tags-sub-regexp
        (regexp-opt (sane-perl-tags-keywords ':sub)))
  ;; etags setup

  ;; Changed from setq to defvar due to warnings from the byte compiler.
  ;; https://emacs.stackexchange.com/questions/21245/dealing-with-warning-assignment-to-free-variable-when-certain-libraries-can-b

  (defvar sane-perl-tags-hier-regexp-list
        (concat
         "^[ \t]*\\("
         "\\("
         sane-perl--tags-namespace-declare-regexp
         "\\)\\>"
         "\\|"
         sane-perl--tags-sub-regexp "\\>[^\n]+::"
         "\\|"
         sane-perl-keyword-rex
	 "(\C-?[^\n]+::" ; XSUB?
         "\\|"
         "[ \t]*BOOT:\C-?[^\n]+::"                 ; BOOT section
         "\\)")))

(defun sane-perl-add-keywords (keywords-plist new-plist)
  "Add to the buffer's keywords according to KEYWORDS-PLIST.
KEYWORDS-PLIST is a property list mapping keyword list categories to their
keyword lists."
  (let ((plist new-plist))
    (while plist
      (let ((category (car plist))
            (keywords (car (cdr plist)))
            (rest     (nthcdr 2 plist)))
        (plist-put keywords-plist
                   category
                   (append (plist-get keywords-plist category) keywords))
        (setq plist rest)))))

(defun sane-perl-apply-keyword-sets ()
  "Apply all appropriate keyword sets to the buffer's set."
  (save-excursion
    (dolist (set sane-perl-keyword-set-alist)
      (goto-char (point-min))
      (let ((name (car set))
            (regexp (nth 1 set))
            (keyword-set (nth 2 set)))
        (if (or (memq name sane-perl-activated-keyword-sets)
                  (and (null (memq name sane-perl-deactivated-keyword-sets))
		       sane-perl-automatic-keyword-sets
                       (re-search-forward regexp nil t)))
            (progn
              (sane-perl-add-keywords sane-perl-keywords-plist keyword-set)
              (cl-pushnew name sane-perl-active-keyword-sets))
          (cl-pushnew name sane-perl-inactive-keyword-sets))))))

(defun sane-perl-deactivate-keyword-set (name)
  "Disable handling of keywords for keyword set NAME."
  (interactive (list (intern-soft (completing-read "Deactivate keyword set: "
                                      sane-perl-active-keyword-sets))))
  (setq sane-perl-activated-keyword-sets
	(delq name sane-perl-activated-keyword-sets))
  (setq sane-perl-deactivated-keyword-sets
	(cl-pushnew name sane-perl-deactivated-keyword-sets))
  (sane-perl-mode))

(defun sane-perl-activate-keyword-set (name)
  "Enable handling of keywords for keyword set NAME."
  (interactive (list (intern-soft (completing-read "Acactivate keyword set: "
                                      sane-perl-inactive-keyword-sets))))
  (setq sane-perl-deactivated-keyword-sets
	(delq name sane-perl-deactivated-keyword-sets))
  (setq sane-perl-activated-keyword-sets
	(cl-pushnew name sane-perl-activated-keyword-sets))
  (sane-perl-mode))

(defun sane-perl-reset-keyword-sets ()
  "Clear lists of explicitly activated and deactivated keyword sets"
  (interactive)
  (setq sane-perl-activated-keyword-sets nil)
  (setq sane-perl-deactivated-keyword-sets nil)
  (sane-perl-mode))

(defun sane-perl--initialize-keywords-plist ()
  "Inititialize the buffer-local plist of keywords.
The initial value contains the keywords from the Perl core."
  (setq sane-perl-keywords-plist
        (list ':namespace-declare  sane-perl-core-namespace-declare-keywords
              ':namespace-ref      sane-perl-core-namespace-ref-keywords
              ':functions          sane-perl-core-functions-for-font-lock
              ':flow-control       sane-perl-core-flow-control-keywords
              ':nonoverridable     sane-perl-core-nonoverridable-keywords
              ':sub                sane-perl-core-sub-keywords
              ':sub-ref            sane-perl-core-sub-ref-keywords
              ':after-label        sane-perl-core-after-label-keywords
              ':before-label       sane-perl-core-before-label-keywords
              ':declaring          sane-perl-core-declaring-keywords
              ':block-init         sane-perl-core-block-init-keywords
              ':block-continuation sane-perl-core-block-continuation-keywords
              ':block              (append sane-perl-core-block-init-keywords
                                           sane-perl-core-block-continuation-keywords)
              ':named-block        sane-perl-core-named-block-keywords
              ':special-sub        sane-perl-core-special-sub-keywords))
  (setq sane-perl-tags-keywords-plist
        (list ':namespace-declare  sane-perl-core-namespace-declare-keywords
              ':sub                sane-perl-core-sub-keywords)))


(defun sane-perl-keywords (category)
  "Return the list of keywords in CATEGORY."
  (plist-get sane-perl-keywords-plist category))

(defun sane-perl-tags-keywords (category)
  "Return the list of keywords in CATEGORY."
  (plist-get sane-perl-tags-keywords-plist category))


(defvar-local sane-perl--namespace-declare-regexp  nil)
(defvar-local sane-perl--namespace-ref-regexp      nil)
(defvar-local sane-perl--namespace-regexp          nil)
(defvar-local sane-perl--functions-regexp          nil)
(defvar-local sane-perl--flow-control-regexp       nil)
(defvar-local sane-perl--nonoverridable-regexp     nil)
(defvar-local sane-perl--sub-regexp                nil)
(defvar-local sane-perl--sub-ref-regexp            nil)
(defvar-local sane-perl--after-label-regexp        nil)
(defvar-local sane-perl--before-label-regexp       nil)
(defvar-local sane-perl--declaring-regexp          nil)
(defvar-local sane-perl--block-init-regexp         nil)
(defvar-local sane-perl--block-continuation-regexp nil)
(defvar-local sane-perl--block-regexp              nil)
(defvar-local sane-perl--named-block-regexp        nil)
(defvar-local sane-perl--special-sub-regexp        nil)

(defvar-local sane-perl-imenu--function-name-regexp-perl nil)
(defvar-local sane-perl-outline-regexp             nil)

(defun sane-perl-collect-keyword-regexps ()
  "Merge and collect buffer-local regexps.
Merge all keyword lists to optimized regular expressions which
will actually be used by `sane-perl-mode'. Then construct regular
expressions which depend on these."
  (sane-perl--initialize-keywords-plist)
  (sane-perl-apply-keyword-sets)
  (setq sane-perl--namespace-declare-regexp      (regexp-opt (sane-perl-keywords ':namespace-declare))
        sane-perl--namespace-ref-regexp          (regexp-opt (sane-perl-keywords ':namespace-ref))
        sane-perl--namespace-regexp              (regexp-opt (append (sane-perl-keywords ':namespace-declare)
                                                                 (sane-perl-keywords ':namespace-ref)))
        sane-perl--functions-regexp              (regexp-opt (sane-perl-keywords ':functions))
        sane-perl--flow-control-regexp           (regexp-opt (append (sane-perl-keywords ':flow-control)
                                                                 (sane-perl-keywords ':sub)
                                                                 (sane-perl-keywords ':namespace-declare)
                                                                 (sane-perl-keywords ':namespace-ref)
                                                                 (sane-perl-keywords ':declaring)))
        sane-perl--nonoverridable-regexp         (regexp-opt (sane-perl-keywords ':nonoverridable))
        sane-perl--sub-regexp                    (regexp-opt (sane-perl-keywords ':sub))
        sane-perl--sub-ref-regexp                (regexp-opt (sane-perl-keywords ':sub-ref))
        sane-perl--after-label-regexp            (regexp-opt (sane-perl-keywords ':after-label))
        sane-perl--before-label-regexp           (regexp-opt (sane-perl-keywords ':before-label))
        sane-perl--declaring-regexp              (regexp-opt (sane-perl-keywords ':declaring))
        sane-perl--block-init-regexp             (regexp-opt (sane-perl-keywords ':block-init))
        sane-perl--block-continuation-regexp     (regexp-opt (sane-perl-keywords ':block-continuation))
        sane-perl--block-regexp                  (regexp-opt (sane-perl-keywords ':block))
        sane-perl--named-block-regexp            (regexp-opt (sane-perl-keywords ':named-block))
        sane-perl--special-sub-regexp            (regexp-opt (sane-perl-keywords ':special-sub)))
  ;; imenu setup for the current buffer
  ;; Details of groups in this are used in `sane-perl-imenu--create-perl-index'
  ;;  and `sane-perl-outline-level'.
  ;; Was: 2=sub|package; now 2=package-group, 5=package-name 8=sub-name (+3)
  (setq sane-perl-imenu--function-name-regexp-perl
        (concat
         "^\\("                               ; 1 = all
         "\\([ \t]*"                          ; 2 = package-group
         sane-perl--namespace-declare-regexp
         "\\("                                 ; 3 = package-name-group
         sane-perl-white-and-comment-rex ; 4 = pre-package-name
         "\\([a-zA-Z_0-9:']+\\)\\)?\\)" ; 5 = package-name
         "\\|"
         "[ \t]*"
         sane-perl--sub-regexp
         (sane-perl-after-sub-regexp 'named nil) ; 8=name 11=proto 14=attr-start
         sane-perl-maybe-white-and-comment-rex     ; 15=pre-block
         "\\|"
         "=head\\([1-4]\\)[ \t]+"           ; 16=level
         "\\([^\n]+\\)$"                    ; 17=text
         "\\)"))
  ;; outline setup
  (setq sane-perl-outline-regexp
        (concat sane-perl-imenu--function-name-regexp-perl "\\|" "\\`"))

  (set (make-local-variable 'outline-regexp) sane-perl-outline-regexp)
  (set (make-local-variable 'outline-level) 'sane-perl-outline-level)
  (set (make-local-variable 'add-log-current-defun-function)
        (lambda ()
          (save-excursion
            (if (re-search-backward "^sub[ \t]+\\([^({ \t\n]+\\)" nil t)
                (match-string-no-properties 1)))))

  (set (make-local-variable 'paragraph-start) (concat "^$\\|" page-delimiter))
  (set (make-local-variable 'paragraph-separate) paragraph-start)
  (set (make-local-variable 'paragraph-ignore-fill-prefix) t)
  (set (make-local-variable 'indent-line-function) #'sane-perl-indent-line)
  (set (make-local-variable 'require-final-newline) mode-require-final-newline)
  (set (make-local-variable 'comment-start) "# ")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'comment-column) sane-perl-comment-column)
  (set (make-local-variable 'comment-start-skip) "#+ *"))

;; Is incorporated in `sane-perl-imenu--function-name-regexp-perl'
;; `sane-perl-outline-regexp', `defun-prompt-regexp'.
;; Details of groups in this may be used in several functions; see comments
;; near mentioned above variable(s)...
;; sub($$):lvalue{}  sub:lvalue{} Both allowed...

;; Changed from defsubst to defun due to warnings from the byte compiler.
;; https://emacs.stackexchange.com/questions/32038/eval-when-compile-defsubst-vs-defmacro-vs-define-inline
(defun sane-perl-after-sub-regexp (named attr) ; 9 groups without attr...
  "Match the text after `sub' in a subroutine declaration.
If NAMED is nil, allows anonymous subroutines.  Matches up to the first \":\"
of attributes (if present), or end of the name or prototype (whatever is
the last)."
  (concat				; Assume n groups before this...
   "\\("				; n+1=name-group
     sane-perl-white-and-comment-rex	; n+2=pre-name
     "\\(::[a-zA-Z_0-9:']+\\|"
     sane-perl-keyword-rex
     "\\)" ; n+3=name
   "\\)"				; END n+1=name-group
   (if named "" "?")
   "\\("				; n+4=proto-group
     sane-perl-maybe-white-and-comment-rex	; n+5=pre-proto
     "\\(([^()]*)\\)"			; n+6=prototype
   "\\)?"				; END n+4=proto-group
   "\\("				; n+7=attr-group
     sane-perl-maybe-white-and-comment-rex	; n+8=pre-attr
     "\\("				; n+9=start-attr
        ":"
	(if attr (concat
		  "\\("
		     sane-perl-maybe-white-and-comment-rex ; whitespace-comments
		     "\\(\\sw\\|_\\)+"	; attr-name
		     ;; attr-arg (1 level of internal parens allowed!)
		     "\\((\\(\\\\.\\|[^\\()]\\|([^\\()]*)\\)*)\\)?"
		     "\\("		; optional : (XXX allows trailing???)
		        sane-perl-maybe-white-and-comment-rex ; whitespace-comments
		     ":\\)?"
		  "\\)+")
	  "[^:]")
     "\\)"
   "\\)?"				; END n+6=proto-group
   ))

;; (defvar sane-perl-outline-regexp
;;   (concat sane-perl-imenu--function-name-regexp-perl "\\|" "\\`"))

(defvar sane-perl-mode-syntax-table nil
  "Syntax table in use in Sane-Perl mode buffers.")

(defvar sane-perl-string-syntax-table nil
  "Syntax table in use in Sane-Perl mode string-like chunks.")

(defsubst sane-perl-1- (p)
  (max (point-min) (1- p)))

(defsubst sane-perl-1+ (p)
  (min (point-max) (1+ p)))

(if sane-perl-mode-syntax-table
    ()
  (setq sane-perl-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?\\ "\\" sane-perl-mode-syntax-table)
  (modify-syntax-entry ?/ "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?* "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?+ "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?- "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?= "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?% "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?< "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?> "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?& "." sane-perl-mode-syntax-table)
  (modify-syntax-entry ?$ "\\" sane-perl-mode-syntax-table)
  (modify-syntax-entry ?\n ">" sane-perl-mode-syntax-table)
  (modify-syntax-entry ?# "<" sane-perl-mode-syntax-table)
  (modify-syntax-entry ?' "\"" sane-perl-mode-syntax-table)
  (modify-syntax-entry ?` "\"" sane-perl-mode-syntax-table)
  (modify-syntax-entry ?: "_" sane-perl-mode-syntax-table)
  (modify-syntax-entry ?| "." sane-perl-mode-syntax-table)
  (setq sane-perl-string-syntax-table (copy-syntax-table sane-perl-mode-syntax-table))
  (modify-syntax-entry ?$ "." sane-perl-string-syntax-table)
  (modify-syntax-entry ?\{ "." sane-perl-string-syntax-table)
  (modify-syntax-entry ?\} "." sane-perl-string-syntax-table)
  (modify-syntax-entry ?\" "." sane-perl-string-syntax-table)
  (modify-syntax-entry ?' "." sane-perl-string-syntax-table)
  (modify-syntax-entry ?` "." sane-perl-string-syntax-table)
  (modify-syntax-entry ?# "." sane-perl-string-syntax-table)) ; (?# comment )



(defvar sane-perl-faces-init nil)
(make-variable-buffer-local 'sane-perl-faces-init)
;; Fix for msb.el
(defvar sane-perl-msb-fixed nil)
(defvar sane-perl-use-major-mode 'sane-perl-mode)
(defvar sane-perl-font-locking nil)

;; NB as it stands the code in sane-perl-mode assumes this only has
;; one element. Since XEmacs 19 support has been dropped, this could
;; all be simplified.
(defvar sane-perl-compilation-error-regexp-alist
  '(("^[^\n]* \\(file\\|at\\) \\([^ \t\n]+\\) [^\n]*line \\([0-9]+\\)[\\., \n]"
     2 3))
  "Alist that specifies how to match errors in perl output.")

(defvar compilation-error-regexp-alist)

;;; sane-perl-mode
;;;###autoload
(define-derived-mode sane-perl-mode prog-mode "Sane-Perl"
  "Major mode for editing Perl code.
Expression and list commands understand all C brackets.
Press the tab key to indent the current line.
Use M-x indent-region to indent several lines.

Various characters in Perl almost always come in pairs: {}, (),
[], sometimes <>.  When the user types the first, she does not
get the second as well, with optional special formatting done on
{}.  (Disabled by default.)  You can always quote (with
\\[quoted-insert]) the left \"paren\" to avoid the expansion.
The processing of < is special, since most the time you mean
\"less\".  Sane-Perl mode tries to guess whether you want to type
a pair <>, and does not insert it if it is appropriate.  You can
set `sane-perl-electric-parens-string' to the string that
contains the parens from the above list you want to be
electrical.  Electricity of parens is controlled by
`sane-perl-electric-parens'.  You may also set
`sane-perl-electric-parens-mark' to have electric parens look for
active mark and \"embrace\" a region if possible.'

Sane-Perl mode provides expansion of the Perl control constructs:

   if, else, elsif, unless, while, until, continue, do,
   for, foreach, formy and foreachmy.

and POD directives (disabled by default, see `sane-perl-electric-keywords'.)

The user types the keyword immediately followed by a space, which
causes the construct to be expanded, and the point is positioned where
she is most likely to want to be.  E.g., when the user types a space
following \"if\" the following appears in the buffer: if () { or if ()
} { } and the cursor is between the parentheses.  The user can then
type some boolean expression within the parens.  Having done that,
typing \\[sane-perl-linefeed] places you - appropriately indented - on a
new line between the braces (if you typed \\[sane-perl-linefeed] in a POD
directive line, then appropriate number of new lines is inserted).

If Sane-Perl decides that you want to insert \"English\" style construct like

            bite if angry;

it will not do any expansion.  See also help on variable
`sane-perl-extra-newline-before-brace'.  Switch the help message
on expansion by setting `sane-perl-message-electric-keyword' to
nil.

\\[sane-perl-linefeed] is a convenience replacement for typing carriage
return.  It places you in the next line with proper indentation, or if
you type it inside the inline block of control construct, like

            foreach (@lines) {print; print}

and you are on a boundary of a statement inside braces, it will
transform the construct into a multiline and will place you into an
appropriately indented blank line.  If you need a usual
`newline-and-indent' behavior, it is on \\[newline-and-indent],
see documentation on `sane-perl-electric-linefeed'.

Use \\[sane-perl-invert-if-unless] to change a construction of the form

	    if (A) { B }

into

            B if A;

\\{sane-perl-mode-map}

Setting the variable 
`sane-perl-electric-lbrace-space' to t switches on electric space
between $ and {, `sane-perl-electric-parens-string' is the string
that contains parentheses that should be electric in Sane-Perl
\(see also `sane-perl-electric-parens-mark' and
`sane-perl-electric-parens'), setting
`sane-perl-electric-keywords' enables electric expansion of
control structures in Sane-Perl.  `sane-perl-electric-linefeed'
governs which one of two linefeed behavior is preferable.  You
can enable all these options simultaneously (recommended mode of
use) by setting `sane-perl-hairy' to t.  In this case you can
switch separate options off by setting them to `null'.  Note that
one may undo the extra whitespace inserted by semis and braces in
`auto-newline'-mode by consequent
\\[sane-perl-electric-backspace].

If you have perl5 documentation in info format, you can use
commands \\[sane-perl-info-on-current-command] and
\\[sane-perl-info-on-command] to access it.  These keys run
commands `sane-perl-info-on-current-command' and
`sane-perl-info-on-command', which one is which is controlled by
variable `sane-perl-info-on-command-no-prompt' and
`sane-perl-clobber-lisp-bindings' \(in turn affected by
`sane-perl-hairy').

Even if you have no info-format documentation, short one-line
help is available on \\[sane-perl-get-help], and one can run
perldoc or man via menu.

It is possible to show this help automatically after some idle time.
This is regulated by variable `sane-perl-lazy-help-time'.  Default with
`sane-perl-hairy' (if the value of `sane-perl-lazy-help-time' is nil) is 5
secs idle time .  It is also possible to switch this on/off from the
menu, or via \\[sane-perl-toggle-autohelp].

Use \\[sane-perl-lineup] to vertically lineup some construction - put the
beginning of the region at the start of construction, and make region
span the needed amount of lines.

Variables `sane-perl-pod-here-scan', `sane-perl-pod-here-fontify',
`sane-perl-pod-face', `sane-perl-pod-head-face' control processing of POD and
here-docs sections.  With capable Emaxen results of scan are used
for indentation too, otherwise they are used for highlighting only.

Variables controlling indentation style:
 `sane-perl-tab-always-indent'
    Non-nil means TAB in Sane-Perl mode should always reindent the current line,
    regardless of where in the line point is when the TAB command is used.
 `sane-perl-indent-left-aligned-comments'
    Non-nil means that the comment starting in leftmost column should indent.
 `sane-perl-auto-newline'
    Non-nil means automatically newline before and after braces,
    and after colons and semicolons, inserted in Perl code.  The following
    \\[sane-perl-electric-backspace] will remove the inserted whitespace.
    Insertion after colons requires both this variable and
    `sane-perl-auto-newline-after-colon' set.
 `sane-perl-auto-newline-after-colon'
    Non-nil means automatically newline even after colons.
    Subject to `sane-perl-auto-newline' setting.
 `sane-perl-indent-level'
    Indentation of Perl statements within surrounding block.
    The surrounding block's indentation is the indentation
    of the line on which the open-brace appears.
 `sane-perl-continued-statement-offset'
    Extra indentation given to a substatement, such as the
    then-clause of an if, or body of a while, or just a statement continuation.
 `sane-perl-continued-brace-offset'
    Extra indentation given to a brace that starts a substatement.
    This is in addition to `sane-perl-continued-statement-offset'.
 `sane-perl-brace-offset'
    Extra indentation for line if it starts with an open brace.
 `sane-perl-brace-imaginary-offset'
    An open brace following other text is treated as if it the line started
    this far to the right of the actual line indentation.
 `sane-perl-label-offset'
    Extra indentation for line that is a label.
 `sane-perl-min-label-indent'
    Minimal indentation for line that is a label.

Settings for classic indent-styles:
+-----------+-----+-----+-----+-----+-----+------+------+------+
|           | BSD | C++ | GNU | K&R | PBP | Perl | Sane | Whit |
| b-o       |   0 |   0 |   0 |   0 |   0 |    0 |    0 |    4 |
| c-b-o     |  -4 |  -4 |   2 |  -5 |   0 |    0 |    0 |    0 |
| c-s-o     |   4 |   4 |   2 |   5 |   4 |    4 |    2 |    0 |
| e-n-b-b   |   t |   t |   t | nil | nil |  nil |  nil |    t |
| e-n-b-b-m | nil |   t |   t | nil | nil |  nil |  nil |  nil |
| i-l       |   4 |   4 |   2 |   5 |   4 |    4 |    2 |    0 |
| i-p-a-b   | nil | nil | nil | nil |   t |  nil |  nil |  nil |
| l-o       |  -4 |  -4 |  -2 |  -5 |  -2 |   -4 |   -2 |   -4 |
| m-t-e     | nil | nil | nil |   t | nil |    t |    t |  nil |
| t-a-i     | nil | nil | nil | nil |   t |  nil |  nil |  nil |
+-----------+-----+-----+-----+-----+-----+------+------+------+
b-o = sane-perl-brace-offset
c-b-o = sane-perl-continued-brace-offset
c-s-o = sane-perl-continued-statement-offset
e-n-b-b = sane-perl-extra-newline-before-brace
e-n-b-b-m = sane-perl-extra-newline-before-brace-multiline
i-l = sane-perl-indent-level
i-p-a-b = sane-perl-indent-parens-as-block
l-o = sane-perl-label-offset
m-t-e = sane-perl-merge-trailing-else
t-a-i = sane-perl-tab-always-indent

Sane-Perl knows several indentation styles, and may bulk set the
corresponding variables.  Use \\[sane-perl-set-style] to do this.  Use
\\[sane-perl-set-style-back] to restore the memorized preexisting values
\(both available from menu).  See examples in `sane-perl-style-examples'.

Part of the indentation style is how different parts of if/elsif/else
statements are broken into lines; in Sane-Perl, this is reflected on how
templates for these constructs are created (controlled by
`sane-perl-extra-newline-before-brace'), and how reflow-logic should treat
\"continuation\" blocks of else/elsif/continue, controlled by the same
variable, and by `sane-perl-extra-newline-before-brace-multiline',
`sane-perl-merge-trailing-else', `sane-perl-indent-region-fix-constructs'.

If `sane-perl-indent-level' is 0, the statement after opening brace in
column 0 is indented on
`sane-perl-brace-offset'+`sane-perl-continued-statement-offset'.

Turning on Sane-Perl mode calls the hooks in the variable
`sane-perl-mode-hook' with no args.

Do not forget to read micro-docs (available from `Perl' menu)
or as help on variables `sane-perl-tips', `sane-perl-problems',
`sane-perl-praise', `sane-perl-speed'."
  (if (sane-perl-val 'sane-perl-electric-linefeed)
      (progn
	(local-set-key "\C-J" 'sane-perl-linefeed)
	(local-set-key "\C-C\C-J" 'newline-and-indent)))
  (if (and
       (sane-perl-val 'sane-perl-clobber-lisp-bindings)
       (sane-perl-val 'sane-perl-info-on-command-no-prompt))
      (progn
	;; don't clobber the backspace binding:
	(define-key sane-perl-mode-map "\C-hf" 'sane-perl-info-on-current-command)
	(define-key sane-perl-mode-map "\C-c\C-hf" 'sane-perl-info-on-command)))
  (setq local-abbrev-table sane-perl-mode-abbrev-table)
  (if (sane-perl-val 'sane-perl-electric-keywords)
      (abbrev-mode 1))
  (set-syntax-table sane-perl-mode-syntax-table)
  ;; haj 2020-07-09: Autodetect keywords - now a bit better
  (sane-perl-collect-keyword-regexps)
  ;;  haj 2020-07-09: Autodetect keywords - end of hack
  ;; Until Emacs is multi-threaded, we do not actually need it local:
  (make-local-variable 'sane-perl-font-locking)

;;       "[ \t]*sub"
;;	  (sane-perl-after-sub-regexp 'named nil) ; 8=name 11=proto 14=attr-start
;;	  sane-perl-maybe-white-and-comment-rex	; 15=pre-block
  (set (make-local-variable 'defun-prompt-regexp)
       (concat "^[ \t]*\\("
	       sane-perl--sub-regexp
	       (sane-perl-after-sub-regexp 'named 'attr-groups)
	       "\\|"			; per toke.c
	       sane-perl--named-block-regexp
	       sane-perl--special-sub-regexp
	       "\\)"
	       sane-perl-maybe-white-and-comment-rex))
  (set (make-local-variable 'comment-indent-function) #'sane-perl-comment-indent)
  (set (make-local-variable 'fill-paragraph-function)
       #'sane-perl-fill-paragraph)
  (set (make-local-variable 'parse-sexp-ignore-comments) t)
  (set (make-local-variable 'indent-region-function) #'sane-perl-indent-region)
  (set (make-local-variable 'imenu-create-index-function)
       #'sane-perl-imenu--create-perl-index)
  (set (make-local-variable 'imenu-sort-function) nil)
  (cond ((boundp 'compilation-error-regexp-alist-alist);; xemacs 20.x
	 (set (make-local-variable 'compilation-error-regexp-alist-alist)
	      (cons (cons 'sane-perl (car sane-perl-compilation-error-regexp-alist))
		    compilation-error-regexp-alist-alist))
	 (if (fboundp 'compilation-build-compilation-error-regexp-alist)
	     (let ((f 'compilation-build-compilation-error-regexp-alist))
	       (funcall f))
	   (make-local-variable 'compilation-error-regexp-alist)
	   (push 'sane-perl compilation-error-regexp-alist)))
	((boundp 'compilation-error-regexp-alist);; xemacs 19.x
	 (set (make-local-variable 'compilation-error-regexp-alist)
	       (append sane-perl-compilation-error-regexp-alist
		       compilation-error-regexp-alist))))
  (set (make-local-variable 'font-lock-defaults)
	'((sane-perl-load-font-lock-keywords
	   sane-perl-load-font-lock-keywords-1
	   sane-perl-load-font-lock-keywords-2) nil nil ((?_ . "w"))))
  ;; Reset syntaxification cache.
  (set (make-local-variable 'sane-perl-syntax-state) nil)
  (if sane-perl-use-syntax-table-text-property
      (if (eval-when-compile (fboundp 'syntax-propertize-rules))
          (progn
            ;; Reset syntaxification cache.
            (set (make-local-variable 'sane-perl-syntax-done-to) nil)
            (set (make-local-variable 'syntax-propertize-function)
                 (lambda (start end)
                   (goto-char start)
                   ;; Even if sane-perl-fontify-syntaxically has already gone
                   ;; beyond `start', syntax-propertize has just removed
                   ;; syntax-table properties between start and end, so we have
                   ;; to re-apply them.
                   (setq sane-perl-syntax-done-to start)
                   (sane-perl-fontify-syntaxically end))))
	;; Do not introduce variable if not needed, we check it!
	(set (make-local-variable 'parse-sexp-lookup-properties) t)
	;; Our: just a plug for wrong font-lock
	(set (make-local-variable 'font-lock-unfontify-region-function)
             ;; not present with old Emacs
	     #'sane-perl-font-lock-unfontify-region-function)
	;; Reset syntaxification cache.
	(set (make-local-variable 'sane-perl-syntax-done-to) nil)
	(set (make-local-variable 'font-lock-syntactic-keywords)
	      (if sane-perl-syntaxify-by-font-lock
		  '((sane-perl-fontify-syntaxically))
                ;; unless font-lock-syntactic-keywords, font-lock (pre-22.1)
                ;;  used to ignore syntax-table text-properties.  (t) is a hack
                ;;  to make font-lock think that font-lock-syntactic-keywords
                ;;  are defined.
                '(t)))))
  (set (make-local-variable 'font-lock-fontify-region-function)
       ;; not present with old Emacs
       #'sane-perl-font-lock-fontify-region-function)
  (set (make-local-variable 'font-lock-fontify-region-function)
       #'sane-perl-font-lock-fontify-region-function)
  (make-local-variable 'sane-perl-old-style)
  (set (make-local-variable 'normal-auto-fill-function)
       #'sane-perl-do-auto-fill)
  (if (sane-perl-val 'sane-perl-font-lock)
      (progn (or sane-perl-faces-init (sane-perl-init-faces))
	     (font-lock-mode 1))
    (font-lock-mode -1))
  (set (make-local-variable 'facemenu-add-face-function)
       #'sane-perl-facemenu-add-face-function)
  (and (boundp 'msb-menu-cond)
       (not sane-perl-msb-fixed)
       (sane-perl-msb-fix))
  (if (fboundp 'easy-menu-add)
      (easy-menu-add sane-perl-menu))	; A NOP in Emacs.
  (if sane-perl-hook-after-change
      (add-hook 'after-change-functions #'sane-perl-after-change-function nil t))
  ;; After hooks since fontification will break this
  (when (and sane-perl-pod-here-scan
             (not sane-perl-syntaxify-by-font-lock))
    (sane-perl-find-pods-heres))
  ;; Setup Flymake
  (add-hook 'flymake-diagnostic-functions #'perl-flymake nil t))

;; Fix for perldb - make default reasonable
(defun sane-perl-db ()
  (interactive)
  (require 'gud)
  ;; FIXME: Use `read-string' or `read-shell-command'?
  (perldb (read-from-minibuffer "Run perldb (like this): "
				(if (consp gud-perldb-history)
				    (car gud-perldb-history)
				  (concat "perl -d "
					  (buffer-file-name)))
				nil nil
				'(gud-perldb-history . 1))))

(defun sane-perl-msb-fix ()
  ;; Adds perl files to msb menu, supposes that msb is already loaded
  (setq sane-perl-msb-fixed t)
  (let* ((l (length msb-menu-cond))
	 (last (nth (1- l) msb-menu-cond))
	 (precdr (nthcdr (- l 2) msb-menu-cond)) ; cdr of this is last
	 (handle (1- (nth 1 last))))
    (setcdr precdr (list
		    (list
		     '(memq major-mode '(sane-perl-mode perl-mode))
		     handle
		     "Perl Files (%d)")
		    last))))

;; This is used by indent-for-comment
;; to decide how much to indent a comment in Sane-Perl code
;; based on its context.  Do fallback if comment is found wrong.

(defvar sane-perl-wrong-comment)
(defvar sane-perl-st-cfence '(14))		; Comment-fence
(defvar sane-perl-st-sfence '(15))		; String-fence
(defvar sane-perl-st-punct '(1))
(defvar sane-perl-st-word '(2))
(defvar sane-perl-st-bra '(4 . ?\>))
(defvar sane-perl-st-ket '(5 . ?\<))


(defun sane-perl-comment-indent ()		; called at point at supposed comment
  (let ((p (point)) (c (current-column)) was phony)
    (if (and (not sane-perl-indent-comment-at-column-0)
	     (looking-at "^#"))
	0	; Existing comment at bol stays there.
      ;; Wrong comment found
      (save-excursion
	(setq was (sane-perl-to-comment-or-eol)
	      phony (eq (get-text-property (point) 'syntax-table)
			sane-perl-st-cfence))
	(if phony
	    (progn			; Too naive???
	      (re-search-forward "#\\|$") ; Hmm, what about embedded #?
	      (if (eq (preceding-char) ?\#)
		  (forward-char -1))
	      (setq was nil)))
	(if (= (point) p)		; Our caller found a correct place
	    (progn
	      (skip-chars-backward " \t")
	      (setq was (current-column))
	      (if (eq was 0)
		  comment-column
		(max (1+ was) ; Else indent at comment column
		     comment-column)))
	  ;; No, the caller found a random place; we need to edit ourselves
	  (if was nil
	    (insert comment-start)
	    (backward-char (length comment-start)))
	  (setq sane-perl-wrong-comment t)
	  (sane-perl-make-indent comment-column 1) ; Indent min 1
	  c)))))

(defun sane-perl-indent-for-comment ()
  "Substitute for `indent-for-comment' in Sane-Perl."
  (interactive)
  (let (sane-perl-wrong-comment)
    (indent-for-comment)
    (if sane-perl-wrong-comment		; set by `sane-perl-comment-indent'
	(progn (sane-perl-to-comment-or-eol)
	       (forward-char (length comment-start))))))

(defun sane-perl-comment-region (b e arg)
  "Comment or uncomment each line in the region in Sane-Perl mode.
See `comment-region'."
  (interactive "r\np")
  (let ((comment-start "#"))
    (comment-region b e arg)))

(defun sane-perl-uncomment-region (b e arg)
  "Uncomment or comment each line in the region in Sane-Perl mode.
See `comment-region'."
  (interactive "r\np")
  (let ((comment-start "#"))
    (comment-region b e (- arg))))

(defvar sane-perl-brace-recursing nil)

(defun sane-perl-electric-brace (arg &optional only-before)
  "Insert character and correct line's indentation.
If ONLY-BEFORE and `sane-perl-auto-newline', will insert newline before the
place (even in empty line), but not after.  If after \")\" and the inserted
char is \"{\", insert extra newline before only if
`sane-perl-extra-newline-before-brace'."
  (interactive "P")
  (let (insertpos
	(other-end (if (and sane-perl-electric-parens-mark
			    (region-active-p)
			    (< (mark) (point)))
		       (mark)
		     nil)))
    (if (and other-end
	     (not sane-perl-brace-recursing)
	     (sane-perl-val 'sane-perl-electric-parens)
	     (>= (save-excursion (sane-perl-to-comment-or-eol) (point)) (point)))
	;; Need to insert a matching pair
	(progn
	  (save-excursion
	    (setq insertpos (point-marker))
	    (goto-char other-end)
	    (setq last-command-event ?\{)
	    (sane-perl-electric-lbrace arg insertpos))
	  (forward-char 1))
      ;; Check whether we close something "usual" with `}'
      (if (and (eq last-command-event ?\})
	       (not
		(condition-case nil
		    (save-excursion
		      (up-list (- (prefix-numeric-value arg)))
		      ;;(sane-perl-after-block-p (point-min))
		      (or (sane-perl-after-expr-p nil "{;)")
			  ;; after sub, else, continue
			  (sane-perl-after-block-p nil 'pre)))
		  (error nil))))
	  ;; Just insert the guy
	  (self-insert-command (prefix-numeric-value arg))
	(if (and (not arg)		; No args, end (of empty line or auto)
		 (eolp)
		 (or (and (null only-before)
			  (save-excursion
			    (skip-chars-backward " \t")
			    (bolp)))
		     (and (eq last-command-event ?\{) ; Do not insert newline
			  ;; if after ")" and `sane-perl-extra-newline-before-brace'
			  ;; is nil, do not insert extra newline.
			  (not sane-perl-extra-newline-before-brace)
			  (save-excursion
			    (skip-chars-backward " \t")
			    (eq (preceding-char) ?\))))
		     (if sane-perl-auto-newline
			 (progn (sane-perl-indent-line) (newline) t) nil)))
	    (progn
	      (self-insert-command (prefix-numeric-value arg))
	      (sane-perl-indent-line)
	      (if sane-perl-auto-newline
		  (setq insertpos (1- (point))))
	      (if (and sane-perl-auto-newline (null only-before))
		  (progn
		    (newline)
		    (sane-perl-indent-line)))
	      (save-excursion
		(if insertpos (progn (goto-char insertpos)
				     (search-forward (make-string
						      1 last-command-event))
				     (setq insertpos (1- (point)))))
		(delete-char -1))))
	(if insertpos
	    (save-excursion
	      (goto-char insertpos)
	      (self-insert-command (prefix-numeric-value arg)))
	  (self-insert-command (prefix-numeric-value arg)))))))

(defun sane-perl-electric-lbrace (arg &optional end)
  "Insert character, correct line's indentation, correct quoting by space."
  (interactive "P")
  (let ((sane-perl-brace-recursing t)
	(sane-perl-auto-newline sane-perl-auto-newline)
	(other-end (or end
		       (if (and sane-perl-electric-parens-mark
				(region-active-p)
				(> (mark) (point)))
			   (save-excursion
			     (goto-char (mark))
			     (point-marker))
			 nil)))
	pos)
    (and (sane-perl-val 'sane-perl-electric-lbrace-space)
	 (eq (preceding-char) ?$)
	 (save-excursion
	   (skip-chars-backward "$")
	   (looking-at "\\(\\$\\$\\)*\\$\\([^\\$]\\|$\\)"))
	 (insert ?\s))
    ;; Check whether we are in comment
    (if (and
	 (save-excursion
	   (beginning-of-line)
	   (not (looking-at "[ \t]*#")))
	 (sane-perl-after-expr-p nil "{;)"))
	nil
      (setq sane-perl-auto-newline nil))
    (sane-perl-electric-brace arg)
    (and (sane-perl-val 'sane-perl-electric-parens)
	 (eq last-command-event ?{)
	 (memq last-command-event
	       (append sane-perl-electric-parens-string nil))
	 (or (if other-end (goto-char (marker-position other-end)))
	     t)
	 (setq last-command-event ?} pos (point))
	 (progn (sane-perl-electric-brace arg t)
		(goto-char pos)))))

(defun sane-perl-electric-paren (arg)
  "Insert an opening parenthesis or a matching pair of parentheses.
See `sane-perl-electric-parens'."
  (interactive "P")
  (let ((other-end (if (and sane-perl-electric-parens-mark
			    (region-active-p)
			    (> (mark) (point)))
		       (save-excursion
			 (goto-char (mark))
			 (point-marker))
		     nil)))
    (if (and (sane-perl-val 'sane-perl-electric-parens)
	     (memq last-command-event
		   (append sane-perl-electric-parens-string nil))
	     (>= (save-excursion (sane-perl-to-comment-or-eol) (point)) (point))
	     (if (eq last-command-event ?<)
		 (progn
		   ;; This code is too electric, see Bug#3943.
		   ;; (and abbrev-mode ; later it is too late, may be after `for'
		   ;; 	(expand-abbrev))
		   (sane-perl-after-expr-p nil "{;(,:="))
	       1))
	(progn
	  (self-insert-command (prefix-numeric-value arg))
	  (if other-end (goto-char (marker-position other-end)))
	  (insert (make-string
		   (prefix-numeric-value arg)
		   (cdr (assoc last-command-event '((?{ .?})
						   (?\[ . ?\])
						   (?\( . ?\))
						   (?< . ?>))))))
	  (forward-char (- (prefix-numeric-value arg))))
      (self-insert-command (prefix-numeric-value arg)))))

(defun sane-perl-electric-rparen (arg)
  "Insert a matching pair of parentheses if marking is active.
If not, or if we are not at the end of marking range, would self-insert.
Affected by `sane-perl-electric-parens'."
  (interactive "P")
  (let ((other-end (if (and sane-perl-electric-parens-mark
			    (sane-perl-val 'sane-perl-electric-parens)
			    (memq last-command-event
				  (append sane-perl-electric-parens-string nil))
			    (region-active-p)
			    (< (mark) (point)))
		       (mark)
		     nil))
	p)
    (if (and other-end
	     (sane-perl-val 'sane-perl-electric-parens)
	     (memq last-command-event '( ?\) ?\] ?\} ?\> ))
	     (>= (save-excursion (sane-perl-to-comment-or-eol) (point)) (point)))
	(progn
	  (self-insert-command (prefix-numeric-value arg))
	  (setq p (point))
	  (if other-end (goto-char other-end))
	  (insert (make-string
		   (prefix-numeric-value arg)
		   (cdr (assoc last-command-event '((?\} . ?\{)
						   (?\] . ?\[)
						   (?\) . ?\()
						   (?\> . ?\<))))))
	  (goto-char (1+ p)))
      (self-insert-command (prefix-numeric-value arg)))))

(defun sane-perl-electric-keyword ()
  "Insert a construction appropriate after a keyword.
Help message may be switched off by setting `sane-perl-message-electric-keyword'
to nil."
  (let ((beg (line-beginning-position))
	(dollar (and (eq last-command-event ?$)
		     (eq this-command 'self-insert-command)))
	(delete (and (memq last-command-event '(?\s ?\n ?\t ?\f))
		     (memq this-command '(self-insert-command newline))))
	my do)
    (and (save-excursion
	   (condition-case nil
	       (progn
		 (backward-sexp 1)
		 (setq do (looking-at "do\\>")))
	     (error nil))
	   (sane-perl-after-expr-p nil "{;:"))
	 (save-excursion
	   (not
	    (re-search-backward
	     "[#\"'`]\\|\\<q\\(\\|[wqxr]\\)\\>"
	     beg t)))
	 (save-excursion (or (not (re-search-backward "^=" nil t))
			     (or
			      (looking-at "=cut")
			      (looking-at "=end")
			      (and sane-perl-use-syntax-table-text-property
				   (not (eq (get-text-property (point)
							       'syntax-type)
					    'pod))))))
	 (save-excursion (forward-sexp -1)
			 (not (memq (following-char) (append "$@%&*" nil))))
	 (progn
	   (and (eq (preceding-char) ?y)
		(progn			; "foreachmy"
		  (forward-char -2)
		  (insert " ")
		  (forward-char 2)
		  (setq my t dollar t
			delete
			(memq this-command '(self-insert-command newline)))))
	   (and dollar (insert " $"))
	   (sane-perl-indent-line)
 	   (cond
 	    (sane-perl-extra-newline-before-brace
 	     (insert (if do "\n" " ()\n"))
 	     (insert "{")
 	     (sane-perl-indent-line)
 	     (insert "\n")
 	     (sane-perl-indent-line)
 	     (insert "\n}")
	     (and do (insert " while ();")))
 	    (t
 	     (insert (if do " {\n} while ();" " () {\n}"))))
	   (or (looking-at "[ \t]\\|$") (insert " "))
	   (sane-perl-indent-line)
	   (if dollar (progn (search-backward "$")
			     (if my
				 (forward-char 1)
			       (delete-char 1)))
	     (search-backward ")")
	     (if (eq last-command-event ?\()
		 (progn			; Avoid "if (())"
		   (delete-char -1)
		   (delete-char 1))))
	   (if delete
	       (sane-perl-putback-char sane-perl-del-back-ch))
	   (if sane-perl-message-electric-keyword
	       (message "Precede char by C-q to avoid expansion"))))))

(defun sane-perl-ensure-newlines (n &optional pos)
  "Make sure there are N newlines after the point."
  (or pos (setq pos (point)))
  (if (looking-at "\n")
      (forward-char 1)
    (insert "\n"))
  (if (> n 1)
      (sane-perl-ensure-newlines (1- n) pos)
    (goto-char pos)))

(defun sane-perl-electric-pod ()
  "Insert a POD chunk appropriate after a =POD directive."
  (let ((delete (and (memq last-command-event '(?\s ?\n ?\t ?\f))
		     (memq this-command '(self-insert-command newline))))
	head1 notlast name p really-delete over)
    (and (save-excursion
	   (forward-word-strictly -1)
	   (and
	    (eq (preceding-char) ?=)
	    (progn
	      (setq head1 (looking-at "head1\\>[ \t]*$"))
	      (setq over (and (looking-at "over\\>[ \t]*$")
			      (not (looking-at "over[ \t]*\n\n\n*=item\\>"))))
	      (forward-char -1)
	      (bolp))
	    (or
	     (get-text-property (point) 'in-pod)
	     (sane-perl-after-expr-p nil "{;:")
	     (and (re-search-backward "\\(\\`\n?\\|^\n\\)=\\sw+" (point-min) t)
		  (not (or (looking-at "\n*=cut") (looking-at "\n*=end")))
		  (or (not sane-perl-use-syntax-table-text-property)
		      (eq (get-text-property (point) 'syntax-type) 'pod))))))
	 (progn
	   (save-excursion
	     (setq notlast (re-search-forward "^\n=" nil t)))
	   (or notlast
	       (progn
		 (insert "\n\n=cut")
		 (sane-perl-ensure-newlines 2)
		 (forward-word-strictly -2)
		 (if (and head1
			  (not
			   (save-excursion
			     (forward-char -1)
			     (re-search-backward "\\(\\`\n?\\|\n\n\\)=head1\\>"
						 nil t)))) ; Only one
		     (progn
		       (forward-word-strictly 1)
		       (setq name (file-name-base (buffer-file-name))
			     p (point))
		       (insert " NAME\n\n" name
			       " - \n\n=head1 SYNOPSIS\n\n\n\n"
			       "=head1 DESCRIPTION")
		       (sane-perl-ensure-newlines 4)
		       (goto-char p)
		       (forward-word-strictly 2)
		       (end-of-line)
		       (setq really-delete t))
		   (forward-word-strictly 1))))
	   (if over
	       (progn
		 (setq p (point))
		 (insert "\n\n=item \n\n\n\n"
			 "=back")
		 (sane-perl-ensure-newlines 2)
		 (goto-char p)
		 (forward-word-strictly 1)
		 (end-of-line)
		 (setq really-delete t)))
	   (if (and delete really-delete)
	       (sane-perl-putback-char sane-perl-del-back-ch))))))

(defun sane-perl-electric-else ()
  "Insert a construction appropriate after a keyword.
Help message may be switched off by setting `sane-perl-message-electric-keyword'
to nil."
  (let ((beg (line-beginning-position)))
    (and (save-excursion
	   (backward-sexp 1)
	   (sane-perl-after-expr-p nil "{;:"))
	 (save-excursion
	   (not
	    (re-search-backward
	     "[#\"'`]\\|\\<q\\(\\|[wqxr]\\)\\>"
	     beg t)))
	 (save-excursion (or (not (re-search-backward "^=" nil t))
			     (looking-at "=cut")
			     (looking-at "=end")
			     (and sane-perl-use-syntax-table-text-property
				  (not (eq (get-text-property (point)
							      'syntax-type)
					   'pod)))))
	 (progn
	   (sane-perl-indent-line)
 	   (cond
 	    (sane-perl-extra-newline-before-brace
 	     (insert "\n")
 	     (insert "{")
 	     (sane-perl-indent-line)
 	     (insert "\n\n}"))
 	    (t
 	     (insert " {\n\n}")))
	   (or (looking-at "[ \t]\\|$") (insert " "))
	   (sane-perl-indent-line)
	   (forward-line -1)
	   (sane-perl-indent-line)
	   (sane-perl-putback-char sane-perl-del-back-ch)
	   (setq this-command 'sane-perl-electric-else)
	   (if sane-perl-message-electric-keyword
	       (message "Precede char by C-q to avoid expansion"))))))

(defun sane-perl-linefeed ()
  "Go to end of line, open a new line and indent appropriately.
If in POD, insert appropriate lines."
  (interactive)
  (let ((beg (line-beginning-position))
	(end (line-end-position))
	(pos (point)) start over cut res)
    (if (and				; Check if we need to split:
					; i.e., on a boundary and inside "{...}"
	 (save-excursion (sane-perl-to-comment-or-eol)
			 (>= (point) pos)) ; Not in a comment
	 (or (save-excursion
	       (skip-chars-backward " \t" beg)
	       (forward-char -1)
	       (looking-at "[;{]"))     ; After { or ; + spaces
	     (looking-at "[ \t]*}")	; Before }
	     (re-search-forward "\\=[ \t]*;" end t)) ; Before spaces + ;
	 (save-excursion
	   (and
	    (eq (car (parse-partial-sexp pos end -1)) -1)
					; Leave the level of parens
	    (looking-at "[,; \t]*\\($\\|#\\)") ; Comma to allow anon subr
					; Are at end
	    (sane-perl-after-block-p (point-min))
	    (progn
	      (backward-sexp 1)
	      (setq start (point-marker))
	      (<= start pos)))))	; Redundant?  Are after the
					; start of parens group.
	(progn
	  (skip-chars-backward " \t")
	  (or (memq (preceding-char) (append ";{" nil))
	      (insert ";"))
	  (insert "\n")
	  (forward-line -1)
	  (sane-perl-indent-line)
	  (goto-char start)
	  (or (looking-at "{[ \t]*$")	; If there is a statement
					; before, move it to separate line
	      (progn
		(forward-char 1)
		(insert "\n")
		(sane-perl-indent-line)))
	  (forward-line 1)		; We are on the target line
	  (sane-perl-indent-line)
	  (beginning-of-line)
	  (or (looking-at "[ \t]*}[,; \t]*$") ; If there is a statement
					; after, move it to separate line
	      (progn
		(end-of-line)
		(search-backward "}" beg)
		(skip-chars-backward " \t")
		(or (memq (preceding-char) (append ";{" nil))
		    (insert ";"))
		(insert "\n")
		(sane-perl-indent-line)
		(forward-line -1)))
	  (forward-line -1)		; We are on the line before target
	  (end-of-line)
	  (newline-and-indent))
      (end-of-line)			; else - no splitting
      (cond
       ((and (looking-at "\n[ \t]*{$")
	     (save-excursion
	       (skip-chars-backward " \t")
	       (eq (preceding-char) ?\)))) ; Probably if () {} group
					; with an extra newline.
	(forward-line 2)
	(sane-perl-indent-line))
       ((save-excursion			; In POD header
	  (forward-paragraph -1)
	  ;; (re-search-backward "\\(\\`\n?\\|\n\n\\)=head1\\b")
	  ;; We are after \n now, so look for the rest
	  (if (looking-at "\\(\\`\n?\\|\n\\)=\\sw+")
	      (progn
		(setq cut (looking-at "\\(\\`\n?\\|\n\\)=\\(cut\\|end\\)\\>"))
		(setq over (looking-at "\\(\\`\n?\\|\n\\)=over\\>"))
		t)))
	(if (and over
		 (progn
		   (forward-paragraph -1)
		   (forward-word-strictly 1)
		   (setq pos (point))
		   (setq cut (buffer-substring (point) (line-end-position)))
		   (delete-char (- (line-end-position) (point)))
		   (setq res (expand-abbrev))
		   (save-excursion
		     (goto-char pos)
		     (insert cut))
		   res))
	    nil
	  (sane-perl-ensure-newlines (if cut 2 4))
	  (forward-line 2)))
       ((get-text-property (point) 'in-pod) ; In POD section
	(sane-perl-ensure-newlines 4)
	(forward-line 2))
       ((looking-at "\n[ \t]*$")	; Next line is empty - use it.
        (forward-line 1)
	(sane-perl-indent-line))
       (t
	(newline-and-indent))))))

(defun sane-perl-electric-semi (arg)
  "Insert character and correct line's indentation."
  (interactive "P")
  (if sane-perl-auto-newline
      (sane-perl-electric-terminator arg)
    (self-insert-command (prefix-numeric-value arg))
    (if sane-perl-autoindent-on-semi
	(sane-perl-indent-line))))

(defun sane-perl-electric-terminator (arg)
  "Insert character and correct line's indentation."
  (interactive "P")
  (let ((end (point))
	(auto (and sane-perl-auto-newline
		   (or (not (eq last-command-event ?:))
		       sane-perl-auto-newline-after-colon)))
	insertpos)
    (if (and ;;(not arg)
	     (eolp)
	     (not (save-excursion
		    (beginning-of-line)
		    (skip-chars-forward " \t")
		    (or
		     ;; Ignore in comment lines
		     (= (following-char) ?#)
		     ;; Colon is special only after a label
		     ;; So quickly rule out most other uses of colon
		     ;; and do no indentation for them.
		     (and (eq last-command-event ?:)
			  (save-excursion
			    (forward-word-strictly 1)
			    (skip-chars-forward " \t")
			    (and (< (point) end)
				 (progn (goto-char (- end 1))
					(not (looking-at ":"))))))
		     (progn
		       (beginning-of-defun)
		       (let ((pps (parse-partial-sexp (point) end)))
			 (or (nth 3 pps) (nth 4 pps) (nth 5 pps))))))))
	(progn
	  (self-insert-command (prefix-numeric-value arg))
	  (if auto (setq insertpos (point-marker)))
	  (sane-perl-indent-line)
	  (if auto
	      (progn
		(newline)
		(sane-perl-indent-line)))
	  (save-excursion
	    (if insertpos (goto-char (1- (marker-position insertpos)))
	      (forward-char -1))
	    (delete-char 1))))
    (if insertpos
	(save-excursion
	  (goto-char insertpos)
	  (self-insert-command (prefix-numeric-value arg)))
      (self-insert-command (prefix-numeric-value arg)))))

(defun sane-perl-electric-backspace (arg)
  "Backspace, or remove whitespace around the point inserted by an electric key.
Will untabify if `sane-perl-electric-backspace-untabify' is non-nil."
  (interactive "p")
  (if (and sane-perl-auto-newline
	   (memq last-command '(sane-perl-electric-semi
				sane-perl-electric-terminator
				sane-perl-electric-lbrace))
	   (memq (preceding-char) '(?\s ?\t ?\n)))
      (let (p)
	(if (eq last-command 'sane-perl-electric-lbrace)
	    (skip-chars-forward " \t\n"))
	(setq p (point))
	(skip-chars-backward " \t\n")
	(delete-region (point) p))
    (and (eq last-command 'sane-perl-electric-else)
	 ;; We are removing the whitespace *inside* sane-perl-electric-else
	 (setq this-command 'sane-perl-electric-else-really))
    (if (and sane-perl-auto-newline
	     (eq last-command 'sane-perl-electric-else-really)
	     (memq (preceding-char) '(?\s ?\t ?\n)))
	(let (p)
	  (skip-chars-forward " \t\n")
	  (setq p (point))
	  (skip-chars-backward " \t\n")
	  (delete-region (point) p))
      (if sane-perl-electric-backspace-untabify
	  (backward-delete-char-untabify arg)
	(call-interactively 'delete-backward-char)))))

(put 'sane-perl-electric-backspace 'delete-selection 'supersede)

(defun sane-perl-inside-parens-p ()		;; NOT USED????
  (condition-case ()
      (save-excursion
	(save-restriction
	  (narrow-to-region (point)
			    (progn (beginning-of-defun) (point)))
	  (goto-char (point-max))
	  (= (char-after (or (scan-lists (point) -1 1) (point-min))) ?\()))
    (error nil)))

(defun sane-perl-indent-command (&optional whole-exp)
  "Indent current line as Perl code, or in some cases insert a tab character.
If `sane-perl-tab-always-indent' is non-nil (the default), always indent current
line.  Otherwise, indent the current line only if point is at the left margin
or in the line's indentation; otherwise insert a tab.

A numeric argument, regardless of its value,
means indent rigidly all the lines of the expression starting after point
so that this line becomes properly indented.
The relative indentation among the lines of the expression are preserved."
  (interactive "P")
  (sane-perl-update-syntaxification (point) (point))
  (if whole-exp
      ;; If arg, always indent this line as Perl
      ;; and shift remaining lines of expression the same amount.
      (let ((shift-amt (sane-perl-indent-line))
	    beg end)
	(save-excursion
	  (if sane-perl-tab-always-indent
	      (beginning-of-line))
	  (setq beg (point))
	  (forward-sexp 1)
	  (setq end (point))
	  (goto-char beg)
	  (forward-line 1)
	  (setq beg (point)))
	(if (and shift-amt (> end beg))
	    (indent-code-rigidly beg end shift-amt "#")))
    (if (and (not sane-perl-tab-always-indent)
	     (save-excursion
	       (skip-chars-backward " \t")
	       (not (bolp))))
	(insert-tab)
      (sane-perl-indent-line))))

(defun sane-perl-indent-line (&optional parse-data)
  "Indent current line as Perl code.
Return the amount the indentation changed by."
  (let ((case-fold-search nil)
	(pos (- (point-max) (point)))
	indent i shift-amt)
    (setq indent (sane-perl-calculate-indent parse-data)
	  i indent)
    (beginning-of-line)
    (cond ((or (eq indent nil) (eq indent t))
	   (setq indent (current-indentation) i nil))
	  ;;((eq indent t)    ; Never?
	  ;; (setq indent (sane-perl-calculate-indent-within-comment)))
	  ;;((looking-at "[ \t]*#")
	  ;; (setq indent 0))
	  (t
	   (skip-chars-forward " \t")
	   (if (listp indent) (setq indent (car indent)))
	   (cond ((and (looking-at sane-perl-label-rex)
		       (not (looking-at "[smy]:\\|tr:")))
		  (and (> indent 0)
		       (setq indent (max sane-perl-min-label-indent
					 (+ indent sane-perl-label-offset)))))
		 ((= (following-char) ?})
		  (setq indent (- indent sane-perl-indent-level)))
		 ((memq (following-char) '(?\) ?\])) ; To line up with opening paren.
		  (setq indent (+ indent sane-perl-close-paren-offset)))
		 ((= (following-char) ?{)
		  (setq indent (+ indent sane-perl-brace-offset))))))
    (skip-chars-forward " \t")
    (setq shift-amt (and i (- indent (current-column))))
    (if (or (not shift-amt)
	    (zerop shift-amt))
	(if (> (- (point-max) pos) (point))
	    (goto-char (- (point-max) pos)))
      ;;(delete-region beg (point))
      ;;(indent-to indent)
      (sane-perl-make-indent indent)
      ;; If initial point was within line's indentation,
      ;; position after the indentation.  Else stay at same point in text.
      (if (> (- (point-max) pos) (point))
	  (goto-char (- (point-max) pos))))
    shift-amt))

(defun sane-perl-after-label ()
  ;; Returns true if the point is after label.  Does not do save-excursion.
  (and (eq (preceding-char) ?:)
       (memq (char-syntax (char-after (- (point) 2)))
	     '(?w ?_))
       (progn
	 (backward-sexp)
	 (looking-at sane-perl-label-rex))))

(defun sane-perl-get-state (&optional parse-start start-state)
  "Return list (START STATE DEPTH PRESTART),
START is a good place to start parsing, or equal to
PARSE-START if preset,
STATE is what is returned by `parse-partial-sexp'.
DEPTH is true is we are immediately after end of block
which contains START.
PRESTART is the position basing on which START was found."
  (save-excursion
    (let ((start-point (point)) depth state start prestart)
      (if (and parse-start
	       (<= parse-start start-point))
	  (goto-char parse-start)
	(beginning-of-defun)
	(setq start-state nil))
      (setq prestart (point))
      (if start-state nil
	;; Try to go out, if sub is not on the outermost level
	(while (< (point) start-point)
	  (setq start (point) parse-start start depth nil
		state (parse-partial-sexp start start-point -1))
	  (if (> (car state) -1) nil
	    ;; The current line could start like }}}, so the indentation
	    ;; corresponds to a different level than what we reached
	    (setq depth t)
	    (beginning-of-line 2)))	; Go to the next line.
	(if start (goto-char start)))	; Not at the start of file
      (setq start (point))
      (or state (setq state (parse-partial-sexp start start-point -1 nil start-state)))
      (list start state depth prestart))))

(defvar sane-perl-look-for-prop '((pod in-pod) (here-doc-delim here-doc-group)))

(defun sane-perl-beginning-of-property (p prop &optional lim)
  "Given that P has a property PROP, find where the property starts.
Will not look before LIM."
  (or (previous-single-property-change (sane-perl-1+ p) prop lim)
      (point-min))
  )

;; Compute the indents of the currently-examined lines.

(defun sane-perl-sniff-for-indent (&optional parse-data) ; was parse-start
  ;; the sniffer logic to understand what the current line MEANS.
  (sane-perl-update-syntaxification (point) (point))
  (let ((res (get-text-property (point) 'syntax-type)))
    (save-excursion
      (cond
       ((and (memq res '(pod here-doc here-doc-delim format))
	     (not (get-text-property (point) 'indentable)))
	(vector res))
       ;; before start of POD - whitespace found since do not have 'pod!
       ((looking-at "[ \t]*\n=")
	(error "Spaces before POD section!"))
       ((and (not sane-perl-indent-left-aligned-comments)
	     (looking-at "^#"))
	[comment-special:at-beginning-of-line])
       ((get-text-property (point) 'in-pod)
	[in-pod])
       (t
	(beginning-of-line)
	(let* ((indent-point (point))
	       (char-after-pos (save-excursion
				 (skip-chars-forward " \t")
				 (point)))
	       (char-after (char-after char-after-pos))
	       (pre-indent-point (point))
	       p prop look-prop is-block delim)
	  (save-excursion		; Know we are not in POD, find appropriate pos before
	    (sane-perl-backward-to-noncomment nil)
	    (setq p (max (point-min) (1- (point)))
		  prop (get-text-property p 'syntax-type)
		  look-prop (or (nth 1 (assoc prop sane-perl-look-for-prop))
				'syntax-type))
	    (if (memq prop '(pod here-doc format here-doc-delim))
		(progn
		  (goto-char (sane-perl-beginning-of-property p look-prop))
		  (beginning-of-line)
		  (setq pre-indent-point (point)))))
	  (goto-char pre-indent-point)	; Orig line skipping preceding pod/etc
	  (let* ((case-fold-search nil)
		 (s-s (sane-perl-get-state (car parse-data) (nth 1 parse-data)))
		 (start (or (nth 2 parse-data) ; last complete sexp terminated
			    (nth 0 s-s))) ; Good place to start parsing
		 (state (nth 1 s-s))
		 (containing-sexp (car (cdr state)))
		 old-indent)
	    (if (and
		 ;;containing-sexp		;; We are buggy at toplevel :-(
		 parse-data)
		(progn
		  (setcar parse-data pre-indent-point)
		  (setcar (cdr parse-data) state)
		  (or (nth 2 parse-data)
		      (setcar (cddr parse-data) start))
		  ;; Before this point: end of statement
		  (setq old-indent (nth 3 parse-data))))
	    (cond ((get-text-property (point) 'indentable)
		   ;; indent to "after" the surrounding open
		   ;; (same offset as `sane-perl-beautify-regexp-piece'),
		   ;; skip blanks if we do not close the expression.
		   (setq delim		; We do not close the expression
			 (get-text-property
			  (sane-perl-1+ char-after-pos) 'indentable)
			 p (1+ (sane-perl-beginning-of-property
				(point) 'indentable))
			 is-block	; misused for: preceding line in REx
			 (save-excursion ; Find preceding line
			   (sane-perl-backward-to-noncomment p)
			   (beginning-of-line)
			   (if (<= (point) p)
			       (progn	; get indent from the first line
				 (goto-char p)
				 (skip-chars-forward " \t")
				 (if (memq (char-after (point))
					   (append "#\n" nil))
				     nil ; Can't use indentation of this line...
				   (point)))
			     (skip-chars-forward " \t")
			     (point)))
			 prop (parse-partial-sexp p char-after-pos))
		   (cond ((not delim)	; End the REx, ignore is-block
			  (vector 'indentable 'terminator p is-block))
			 (is-block	; Indent w.r.t. preceding line
			  (vector 'indentable 'cont-line char-after-pos
				  is-block char-after p))
			 (t		; No preceding line...
			  (vector 'indentable 'first-line p))))
		  ((get-text-property char-after-pos 'REx-part2)
		   (vector 'REx-part2 (point)))
		  ((nth 4 state)
		   [comment])
		  ((nth 3 state)
		   [string])
		  ;; XXXX Do we need to special-case this?
		  ((null containing-sexp)
		   ;; Line is at top level.  May be data or function definition,
		   ;; or may be function argument declaration.
		   ;; Indent like the previous top level line
		   ;; unless that ends in a closeparen without semicolon,
		   ;; in which case this line is the first argument decl.
		   (skip-chars-forward " \t")
		   (sane-perl-backward-to-noncomment (or old-indent (point-min)))
		   (setq state
			 (or (bobp)
			     (eq (point) old-indent) ; old-indent was at comment
			     (eq (preceding-char) ?\;)
			     ;;  Had ?\) too
			     (and (eq (preceding-char) ?\})
				  (sane-perl-after-block-and-statement-beg
				   (point-min))) ; Was start - too close
			     (memq char-after (append ")]}" nil))
			     (and (eq (preceding-char) ?\:) ; label
				  (progn
				    (forward-sexp -1)
				    (skip-chars-backward " \t")
				    (looking-at "[ \t]*[a-zA-Z_][a-zA-Z_0-9]*[ \t]*:")))
			     (get-text-property (point) 'first-format-line)))

		   ;; Look at previous line that's at column 0
		   ;; to determine whether we are in top-level decls
		   ;; or function's arg decls.  Set basic-indent accordingly.
		   ;; Now add a little if this is a continuation line.
		   (and state
			parse-data
			(not (eq char-after ?\C-j))
			(setcdr (cddr parse-data)
				(list pre-indent-point)))
		   (vector 'toplevel start char-after state (nth 2 s-s)))
		  ((not
		    (or (setq is-block
			      (and (setq delim (= (char-after containing-sexp) ?{))
				   (save-excursion ; Is it a hash?
				     (goto-char containing-sexp)
				     (sane-perl-block-p))))
			sane-perl-indent-parens-as-block))
		   ;; group is an expression, not a block:
		   ;; indent to just after the surrounding open parens,
		   ;; skip blanks if we do not close the expression.
		   (goto-char (1+ containing-sexp))
		   (or (memq char-after
			     (append (if delim "}" ")]}") nil))
		       (looking-at "[ \t]*\\(#\\|$\\)")
		       (skip-chars-forward " \t"))
		   (setq old-indent (point)) ; delim=is-brace
		   (vector 'in-parens char-after (point) delim containing-sexp))
		  (t
		   ;; Statement level.  Is it a continuation or a new statement?
		   ;; Find previous non-comment character.
		   (goto-char pre-indent-point) ; Skip one level of POD/etc
		   (sane-perl-backward-to-noncomment containing-sexp)
		   ;; Back up over label lines, since they don't
		   ;; affect whether our line is a continuation.
		   ;; (Had \, too)
		   (while;;(or (eq (preceding-char) ?\,)
		       (and (eq (preceding-char) ?:)
			    (or;;(eq (char-after (- (point) 2)) ?\') ; ????
			     (memq (char-syntax (char-after (- (point) 2)))
				   '(?w ?_))))
		     ;;)
		     ;; This is always FALSE?
		     (if (eq (preceding-char) ?\,)
			 ;; Will go to beginning of line, essentially.
			 ;; Will ignore embedded sexpr XXXX.
			 (sane-perl-backward-to-start-of-continued-exp containing-sexp))
		     (beginning-of-line)
		     (sane-perl-backward-to-noncomment containing-sexp))
		   ;; Now we get non-label preceding the indent point
		   (if (not (or (eq (1- (point)) containing-sexp)
                                (and sane-perl-indent-parens-as-block
                                     (not is-block))
				(memq (preceding-char)
				      (append (if is-block " ;{" " ,;{") '(nil)))
				(and (eq (preceding-char) ?\})
				     (sane-perl-after-block-and-statement-beg
				      containing-sexp))
				(get-text-property (point) 'first-format-line)))
		       ;; This line is continuation of preceding line's statement;
		       ;; indent  `sane-perl-continued-statement-offset'  more than the
		       ;; previous line of the statement.
		       ;;
		       ;; There might be a label on this line, just
		       ;; consider it bad style and ignore it.
		       (progn
			 (sane-perl-backward-to-start-of-continued-exp containing-sexp)
			 (vector 'continuation (point) char-after is-block delim))
		     ;; This line starts a new statement.
		     ;; Position following last unclosed open brace
		     (goto-char containing-sexp)
		     ;; Is line first statement after an open-brace?
		     (or
		      ;; If no, find that first statement and indent like
		      ;; it.  If the first statement begins with label, do
		      ;; not believe when the indentation of the label is too
		      ;; small.
		      (save-excursion
			(forward-char 1)
			(let ((colon-line-end 0))
			  (while
			      (progn (skip-chars-forward " \t\n")
				     ;; s: foo : bar :x is NOT label
				     (and (looking-at "#\\|\\([a-zA-Z0-9_$]+\\):[^:]\\|=[a-zA-Z]")
					  (not (looking-at "[sym]:\\|tr:"))))
			    ;; Skip over comments and labels following openbrace.
			    (cond ((= (following-char) ?\#)
				   (forward-line 1))
				  ((= (following-char) ?\=)
				   (goto-char
				    (or (next-single-property-change (point) 'in-pod)
					(point-max)))) ; do not loop if no syntaxification
				  ;; label:
				  (t
				   (setq colon-line-end (line-end-position))
				   (search-forward ":"))))
			  ;; We are at beginning of code (NOT label or comment)
			  ;; First, the following code counts
			  ;; if it is before the line we want to indent.
			  (and (< (point) indent-point)
			       (vector 'have-prev-sibling (point) colon-line-end
				       containing-sexp))))
		      (progn
			;; If no previous statement,
			;; indent it relative to line brace is on.

			;; For open-braces not the first thing in a line,
			;; add in sane-perl-brace-imaginary-offset.

			;; If first thing on a line:  ?????
			;; Move back over whitespace before the openbrace.
			(setq		; brace first thing on a line
			 old-indent (progn (skip-chars-backward " \t") (bolp)))
			;; Should we indent w.r.t. earlier than start?
			;; Move to start of control group, possibly on a different line
			(or sane-perl-indent-wrt-brace
			    (sane-perl-backward-to-noncomment (point-min)))
			;; If the openbrace is preceded by a parenthesized exp,
			;; move to the beginning of that;
			(if (eq (preceding-char) ?\))
			    (progn
			      (forward-sexp -1)
			      (sane-perl-backward-to-noncomment (point-min))))
			;; In the case it starts a subroutine, indent with
			;; respect to `sub', not with respect to the
			;; first thing on the line, say in the case of
			;; anonymous sub in a hash.
			(if (and;; Is it a sub in group starting on this line?
                             sane-perl-indent-subs-specially
			     (cond ((get-text-property (point) 'attrib-group)
				    (goto-char (sane-perl-beginning-of-property
						(point) 'attrib-group)))
				   ((eq (preceding-char) ?b)
				    (forward-sexp -1)
				    (looking-at (concat sane-perl--sub-regexp "\\>"))))
			     (setq p (nth 1 ; start of innermost containing list
					  (parse-partial-sexp
					   (line-beginning-position)
					   (point)))))
			    (progn
			      (goto-char (1+ p)) ; enclosing block on the same line
			      (skip-chars-forward " \t")
			      (vector 'code-start-in-block containing-sexp char-after
				      (and delim (not is-block)) ; is a HASH
				      old-indent ; brace first thing on a line
				      t (point) ; have something before...
				      )
			      ;;(current-column)
			      )
			  ;; Get initial indentation of the line we are on.
			  ;; If line starts with label, calculate label indentation
			  (vector 'code-start-in-block containing-sexp char-after
				  (and delim (not is-block)) ; is a HASH
				  old-indent ; brace first thing on a line
				  nil (point))))))))))))))) ; nothing interesting before

(defvar sane-perl-indent-rules-alist
  '((pod nil)				; via `syntax-type' property
    (here-doc nil)			; via `syntax-type' property
    (here-doc-delim nil)		; via `syntax-type' property
    (format nil)			; via `syntax-type' property
    (in-pod nil)			; via `in-pod' property
    (comment-special:at-beginning-of-line nil)
    (string t)
    (comment nil))
  "Alist of indentation rules for Sane-Perl mode.
The values mean:
  nil: do not indent;
  FUNCTION: a function to compute the indentation to use.
    Takes a single argument which provides the currently computed indentation
    context, and should return the column to which to indent.
  NUMBER: add this amount of indentation.")

(defun sane-perl-calculate-indent (&optional parse-data) ; was parse-start
  "Return appropriate indentation for current line as Perl code.
In usual case returns an integer: the column to indent to.
Returns nil if line starts inside a string, t if in a comment.

Will not correct the indentation for labels, but will correct it for braces
and closing parentheses and brackets."
  ;; This code is still a broken architecture: in some cases we need to
  ;; compensate for some modifications which `sane-perl-indent-line' will add later
  (save-excursion
    (let ((i (sane-perl-sniff-for-indent parse-data)) what p)
      (cond
       ((vectorp i)
	(setq what (assoc (elt i 0) sane-perl-indent-rules-alist))
	(cond
         (what
          (let ((action (cadr what)))
            (cond ((functionp action) (apply action (list i parse-data)))
                  ((numberp action) (+ action (current-indentation)))
                  (t action))))
	 ;;
	 ;; Indenters for regular expressions with //x and qw()
	 ;;
	 ((eq 'REx-part2 (elt i 0)) ;; [self start] start of /REP in s//REP/x
	  (goto-char (elt i 1))
	  (condition-case nil	; Use indentation of the 1st part
	      (forward-sexp -1))
	  (current-column))
	 ((eq 'indentable (elt i 0))	; Indenter for REGEXP, qw(), etc.
	  (cond		       ;;; [indentable terminator start-pos is-block]
	   ;; At the end of the qw expression
	   ((eq 'terminator (elt i 1)) ; Lone terminator of "indentable string"
	    (goto-char (elt i 2))	; After opening parens
	    (if sane-perl-indentable-indent
		;; Far-right indent
                (1- (current-column))
	      ;; Not doing the far-right indent
	      (cond ((eq what ?\) )
		     (- sane-perl-close-paren-offset)) ; compensate
		    ((eq what ?\| )
		     (- (or sane-perl-regexp-indent-step sane-perl-indent-level)))
		    (t (current-indentation)))
	      )
	    )
	   ((eq 'first-line (elt i 1)); [indentable first-line start-pos]
	    (goto-char (elt i 2))
	    (+ (or sane-perl-regexp-indent-step sane-perl-indent-level)
	       (if sane-perl-indentable-indent (current-column) (sane-perl-calculate-indent))))
	   ((eq 'cont-line (elt i 1)); [indentable cont-line pos prev-pos first-char start-pos]
	    ;; Indent as the level after closing parens
	    (goto-char (elt i 2))	; indent line
	    (skip-chars-forward " \t)") ; Skip closing parens
	    (setq p (point))
	    (goto-char (elt i 3))	; previous line
	    (skip-chars-forward " \t)") ; Skip closing parens
	    ;; Number of parens in between:
	    (setq p (nth 0 (parse-partial-sexp (point) p))
		  what (elt i 4))	; First char on current line
	    (goto-char (elt i 3))	; previous line
	    (+ (* p (or sane-perl-regexp-indent-step sane-perl-indent-level))
	       (cond ((eq what ?\) )
		      (- sane-perl-close-paren-offset)) ; compensate
		     ((eq what ?\| )
		      (- (or sane-perl-regexp-indent-step sane-perl-indent-level)))
		     (t 0))
	       (if (eq (following-char) ?\| )
		   (or sane-perl-regexp-indent-step sane-perl-indent-level)
		 0)
	       (current-column)))
	   (t
	    (error "Unrecognized value of indent: %s" i))))
	 ;;
	 ;; Indenter for stuff at toplevel
	 ;;
	 ((eq 'toplevel (elt i 0)) ;; [toplevel start char-after state immed-after-block]
	  (+ (save-excursion		; To beg-of-defun, or end of last sexp
	       (goto-char (elt i 1))	; start = Good place to start parsing
	       (- (current-indentation) ;
		  (if (elt i 4) sane-perl-indent-level 0)))	; immed-after-block
	     (if (eq (elt i 2) ?{) sane-perl-continued-brace-offset 0) ; char-after
	     ;; Look at previous line that's at column 0
	     ;; to determine whether we are in top-level decls
	     ;; or function's arg decls.  Set basic-indent accordingly.
	     ;; Now add a little if this is a continuation line.

; Commenting out the following three lines fixed the "indent bug", but
; it's not clear yet if commenting these out will cause other
; failures. 2021-01-19 23:08:29

	     ;; (if (elt i 3)		; state (XXX What is the semantic???)
	     ;; 	 0
	     ;;   sane-perl-continued-statement-offset)
	     ))
	 ;;
	 ;; Indenter for stuff in "parentheses" (or brackets, braces-as-hash)
	 ;;
	 ((eq 'in-parens (elt i 0))
	  ;; in-parens char-after old-indent-point is-brace containing-sexp

	  ;; group is an expression, not a block:
	  ;; indent to just after the surrounding open parens,
	  ;; skip blanks if we do not close the expression.
	  (+ (progn
	       (goto-char (elt i 2))		; old-indent-point
	       (current-column))
	     (if (and (elt i 3)		; is-brace
		      (eq (elt i 1) ?\})) ; char-after
		 ;; Correct indentation of trailing ?\}
		 (+ sane-perl-indent-level sane-perl-close-paren-offset)
	       0)))
	 ;;
	 ;; Indenter for continuation lines
	 ;;
	 ((eq 'continuation (elt i 0))
	  ;; [continuation statement-start char-after is-block is-brace]
	  (goto-char (elt i 1))		; statement-start
	  (+ (if (or (memq (elt i 2) (append "}])" nil)) ; char-after
                     (eq 'continuation ; do not stagger continuations
                         (elt (sane-perl-sniff-for-indent parse-data) 0)))
		 0 ; Closing parenthesis or continuation of a continuation
	       sane-perl-continued-statement-offset)
	     (if (or (elt i 3)		; is-block
		     (not (elt i 4))		; is-brace
		     (not (eq (elt i 2) ?\}))) ; char-after
		 0
	       ;; Now it is a hash reference
	       (+ sane-perl-indent-level sane-perl-close-paren-offset))
	     ;; Labels do not take :: ...
	     (if (looking-at "\\(\\w\\|_\\)+[ \t]*:")
		 (if (> (current-indentation) sane-perl-min-label-indent)
		     (- (current-indentation) sane-perl-label-offset)
		   ;; Do not move `parse-data', this should
		   ;; be quick anyway (this comment comes
		   ;; from different location):
		   (sane-perl-calculate-indent))
	       (current-column))
	     (if (eq (elt i 2) ?\{)	; char-after
		 sane-perl-continued-brace-offset 0)))
	 ;;
	 ;; Indenter for lines in a block which are not leading lines
	 ;;
	 ((eq 'have-prev-sibling (elt i 0))
	  ;; [have-prev-sibling sibling-beg colon-line-end block-start]
	  (goto-char (elt i 1))		; sibling-beg
	  (if (> (elt i 2) (point)) ; colon-line-end; have label before point
	      (if (> (current-indentation)
		     sane-perl-min-label-indent)
		  (- (current-indentation) sane-perl-label-offset)
		;; Do not believe: `max' was involved in calculation of indent
		(+ sane-perl-indent-level
		   (save-excursion
		     (goto-char (elt i 3)) ; block-start
		     (current-indentation))))
	    (current-column)))
	 ;;
	 ;; Indenter for the first line in a block
	 ;;
	 ((eq 'code-start-in-block (elt i 0))
	  ;;[code-start-in-block before-brace char-after
	  ;; is-a-HASH-ref brace-is-first-thing-on-a-line
	  ;; group-starts-before-start-of-sub start-of-control-group]
	  (goto-char (elt i 1))
	  ;; For open brace in column zero, don't let statement
	  ;; start there too.  If sane-perl-indent-level=0,
	  ;; use sane-perl-brace-offset + sane-perl-continued-statement-offset instead.
	  (+ (if (and (bolp) (zerop sane-perl-indent-level))
		 (+ sane-perl-brace-offset sane-perl-continued-statement-offset)
	       sane-perl-indent-level)
	     (if (and (elt i 3)	; is-a-HASH-ref
		      (eq (elt i 2) ?\})) ; char-after: End of a hash reference
		 (+ sane-perl-indent-level sane-perl-close-paren-offset)
	       0)
	     ;; Unless openbrace is the first nonwhite thing on the line,
	     ;; add the sane-perl-brace-imaginary-offset.
	     (if (elt i 4) 0		; brace-is-first-thing-on-a-line
	       sane-perl-brace-imaginary-offset)
	     (progn
	       (goto-char (elt i 6))	; start-of-control-group
	       (if (elt i 5)		; group-starts-before-start-of-sub
		   (current-column)
		 ;; Get initial indentation of the line we are on.
		 ;; If line starts with label, calculate label indentation
		 (if (save-excursion
		       (beginning-of-line)
		       (looking-at (concat "[ \t]*" sane-perl-label-rex)))
		     (if (> (current-indentation) sane-perl-min-label-indent)
			 (- (current-indentation) sane-perl-label-offset)
		       ;; Do not move `parse-data', this should
		       ;; be quick anyway:
		       (sane-perl-calculate-indent))
		   (current-indentation))))))
	 (t
	  (error "Unrecognized value of indent: %s" i))))
       (t
	(error "Got strange value of indent: %s" i))))))

(defun sane-perl-calculate-indent-within-comment ()
  "Return the indentation amount for line, assuming that
the current line is to be regarded as part of a block comment."
  (let (end)
    (save-excursion
      (beginning-of-line)
      (skip-chars-forward " \t")
      (setq end (point))
      (and (= (following-char) ?#)
	   (forward-line -1)
	   (sane-perl-to-comment-or-eol)
	   (setq end (point)))
      (goto-char end)
      (current-column))))


(defun sane-perl-to-comment-or-eol ()
  "Go to position before comment on the current line, or to end of line.
Returns true if comment is found.  In POD will not move the point."
  ;; If the line is inside other syntax groups (qq-style strings, HERE-docs)
  ;; then looks for literal # or end-of-line.
  (let (state stop-in cpoint (lim (line-end-position)) pr e)
    (or sane-perl-font-locking
	(sane-perl-update-syntaxification lim lim))
    (beginning-of-line)
    (if (setq pr (get-text-property (point) 'syntax-type))
	(setq e (next-single-property-change (point) 'syntax-type nil (point-max))))
    (if (or (eq pr 'pod)
	    (if (or (not e) (> e lim))	; deep inside a group
		(re-search-forward "\\=[ \t]*\\(#\\|$\\)" lim t)))
	(if (eq (preceding-char) ?\#) (progn (backward-char 1) t))
      ;; Else - need to do it the hard way
      (and (and e (<= e lim))
	   (goto-char e))
      (while (not stop-in)
	(setq state (parse-partial-sexp (point) lim nil nil nil t))
					; stop at comment
	;; If fails (beginning-of-line inside sexp), then contains not-comment
	(if (nth 4 state)		; After `#';
					; (nth 2 state) can be
					; beginning of m,s,qq and so
					; on
	    (if (nth 2 state)
		(progn
		  (setq cpoint (point))
		  (goto-char (nth 2 state))
		  (cond
		   ((looking-at "\\(s\\|tr\\)\\>")
		    (or (re-search-forward
			 "\\=\\w+[ \t]*#\\([^\n\\#]\\|\\\\[\\#]\\)*#\\([^\n\\#]\\|\\\\[\\#]\\)*"
			 lim 'move)
			(setq stop-in t)))
		   ((looking-at "\\(m\\|q\\([qxwr]\\)?\\)\\>")
		    (or (re-search-forward
			 "\\=\\w+[ \t]*#\\([^\n\\#]\\|\\\\[\\#]\\)*#"
			 lim 'move)
			(setq stop-in t)))
		   (t			; It was fair comment
		    (setq stop-in t)	; Finish
		    (goto-char (1- cpoint)))))
	      (setq stop-in t)		; Finish
	      (forward-char -1))
	  (setq stop-in t)))		; Finish
      (nth 4 state))))

(defsubst sane-perl-modify-syntax-type (at how)
  (if (< at (point-max))
      (progn
	(put-text-property at (1+ at) 'syntax-table how)
	(put-text-property at (1+ at) 'rear-nonsticky '(syntax-table)))))

(defun sane-perl-protect-defun-start (s e)
  ;; C code looks for "^\\s(" to skip comment backward in "hard" situations
  (save-excursion
    (goto-char s)
    (while (re-search-forward "^\\s(" e 'to-end)
      (put-text-property (1- (point)) (point) 'syntax-table sane-perl-st-punct))))

(defun sane-perl-commentify (bb e string &optional noface)
  (if sane-perl-use-syntax-table-text-property
      (if (eq noface 'n)		; Only immediate
	  nil
	;; We suppose that e is _after_ the end of construction, as after eol.
	(setq string (if string sane-perl-st-sfence sane-perl-st-cfence))
	(if (> bb (- e 2))
	    ;; one-char string/comment?!
	    (sane-perl-modify-syntax-type bb sane-perl-st-punct)
	  (sane-perl-modify-syntax-type bb string)
	  (sane-perl-modify-syntax-type (1- e) string))
	(if (and (eq string sane-perl-st-sfence) (> (- e 2) bb))
	    (put-text-property (1+ bb) (1- e)
			       'syntax-table sane-perl-string-syntax-table))
	(sane-perl-protect-defun-start bb e))
    ;; Fontify
    (or noface
	(not sane-perl-pod-here-fontify)
	(put-text-property bb e 'face (if string 'font-lock-string-face
					'font-lock-comment-face)))))

(defvar sane-perl-starters '(( ?\( . ?\) )
			 ( ?\[ . ?\] )
			 ( ?\{ . ?\} )
			 ( ?\< . ?\> )))

(defun sane-perl-cached-syntax-table (st)
  "Get a syntax table cached in ST, or create and cache into ST a syntax table.
All the entries of the syntax table are \".\", except for a backslash, which
is quoting."
  (if (car-safe st)
      (car st)
    (setcar st (make-syntax-table))
    (setq st (car st))
    (let ((i 0))
      (while (< i 256)
	(modify-syntax-entry i "." st)
	(setq i (1+ i))))
    (modify-syntax-entry ?\\ "\\" st)
    st))

(defun sane-perl-forward-re (lim end is-2arg st-l err-l argument
			     &optional ostart)
"Find the end of a regular expression or a stringish construct (q[] etc).
The point should be before the starting delimiter.

Goes to LIM if none is found.  If IS-2ARG is non-nil, assumes that it
is s/// or tr/// like expression.  If END is nil, generates an error
message if needed.  If SET-ST is non-nil, will use (or generate) a
cached syntax table in ST-L.  If ERR-L is non-nil, will store the
error message in its CAR (unless it already contains some error
message).  ARGUMENT should be the name of the construct (used in error
messages).  OSTART may be set in recursive calls when processing
the second argument of 2ARG construct.

Works *before* syntax recognition is done.  In IS-2ARG situation may
modify syntax-type text property if the situation is too hard."
  (let (b starter ender st i i2 go-forward reset-st set-st)
    (skip-chars-forward " \t")
    ;; ender means matching-char matcher.
    (setq b (point)
	  starter (if (eobp) 0 (char-after b))
	  ender (cdr (assoc starter sane-perl-starters)))
    ;; What if starter == ?\\  ????
    (setq st (sane-perl-cached-syntax-table st-l))
    (setq set-st t)
    ;; Whether we have an intermediate point
    (setq i nil)
    ;; Prepare the syntax table:
    (if (not ender)		; m/blah/, s/x//, s/x/y/
	(modify-syntax-entry starter "$" st)
      (modify-syntax-entry starter (concat "(" (list ender)) st)
      (modify-syntax-entry ender  (concat ")" (list starter)) st))
    (condition-case nil
	(progn
	  ;; We use `$' syntax class to find matching stuff, but $$
	  ;; is recognized the same as $, so we need to check this manually.
	  (if (and (eq starter (char-after (sane-perl-1+ b)))
		   (not ender))
	      ;; $ has TeXish matching rules, so $$ equiv $...
	      (forward-char 2)
	    (setq reset-st (syntax-table))
	    (set-syntax-table st)
	    (forward-sexp 1)
	    (if (<= (point) (1+ b))
		(error "Unfinished regular expression"))
	    (set-syntax-table reset-st)
	    (setq reset-st nil)
	    ;; Now the problem is with m;blah;;
	    (and (not ender)
		 (eq (preceding-char)
		     (char-after (- (point) 2)))
		 (save-excursion
		   (forward-char -2)
		   (= 0 (% (skip-chars-backward "\\\\") 2)))
		 (forward-char -1)))
	  ;; Now we are after the first part.
	  (and is-2arg			; Have trailing part
	       (not ender)
	       (eq (following-char) starter) ; Empty trailing part
	       (progn
		 (or (eq (char-syntax (following-char)) ?.)
		     ;; Make trailing letter into punctuation
		     (sane-perl-modify-syntax-type (point) sane-perl-st-punct))
		 (setq is-2arg nil go-forward t))) ; Ignore the tail
	  (if is-2arg			; Not number => have second part
	      (progn
		(setq i (point) i2 i)
		(if ender
		    (if (memq (following-char) '(?\s ?\t ?\n ?\f))
			(progn
			  (if (looking-at "[ \t\n\f]+\\(#[^\n]*\n[ \t\n\f]*\\)+")
			      (goto-char (match-end 0))
			    (skip-chars-forward " \t\n\f"))
			  (setq i2 (point))))
		  (forward-char -1))
		(modify-syntax-entry starter (if (eq starter ?\\) "\\" ".") st)
		(if ender (modify-syntax-entry ender "." st))
		(setq set-st nil)
		(setq ender (sane-perl-forward-re lim end nil st-l err-l
					      argument starter)
		      ender (nth 2 ender)))))
      (error (goto-char lim)
	     (setq set-st nil)
	     (if reset-st
		 (set-syntax-table reset-st))
	     (or end
		 (and sane-perl-brace-recursing
		      (or (eq ostart  ?\{)
			  (eq starter ?\{)))
		 (or (car err-l) (setcar err-l b)))))
    (if set-st
	(progn
	  (modify-syntax-entry starter (if (eq starter ?\\) "\\" ".") st)
	  (if ender (modify-syntax-entry ender "." st))))
    ;; i: have 2 args, after end of the first arg
    ;; i2: start of the second arg, if any (before delim if `ender').
    ;; ender: the last arg bounded by parens-like chars, the second one of them
    ;; starter: the starting delimiter of the first arg
    ;; go-forward: has 2 args, and the second part is empty
    (list i i2 ender starter go-forward)))

(defun sane-perl-forward-group-in-re (&optional st-l)
  "Find the end of a group in a REx.
Return the error message (if any).  Does not work if delimiter is `)'.
Works before syntax recognition is done."
  ;; Works *before* syntax recognition is done
  (or st-l (setq st-l (list nil)))	; Avoid overwriting '()
  (let (st result reset-st)
    (condition-case err
	(progn
	  (setq st (sane-perl-cached-syntax-table st-l))
	  (modify-syntax-entry ?\( "()" st)
	  (modify-syntax-entry ?\) ")(" st)
	  (setq reset-st (syntax-table))
	  (set-syntax-table st)
	  (forward-sexp 1))
      (error (setq result err)))
    ;; now restore the initial state
    (if st
	(progn
	  (modify-syntax-entry ?\( "." st)
	  (modify-syntax-entry ?\) "." st)))
    (if reset-st
	(set-syntax-table reset-st))
    result))


(defsubst sane-perl-postpone-fontification (b e type val &optional now)
  ;; Do after syntactic fontification?
  (if sane-perl-syntaxify-by-font-lock
      (or now (put-text-property b e 'sane-perl-postpone (cons type val)))
    (put-text-property b e type val)))

;; Here is how the global structures (those which cannot be
;; recognized locally) are marked:
;;	a) PODs:
;;		Start-to-end is marked `in-pod' ==> t
;;		Each non-literal part is marked `syntax-type' ==> `pod'
;;		Each literal part is marked `syntax-type' ==> `in-pod'
;;	b) HEREs:
;;		Start-to-end is marked `here-doc-group' ==> t
;;		The body is marked `syntax-type' ==> `here-doc'
;;		The delimiter is marked `syntax-type' ==> `here-doc-delim'
;;	c) FORMATs:
;;		First line (to =) marked `first-format-line' ==> t
;;		After-this--to-end is marked `syntax-type' ==> `format'
;;	d) 'Q'uoted string:
;;		part between markers inclusive is marked `syntax-type' ==> `string'
;;		part between `q' and the first marker is marked `syntax-type' ==> `prestring'
;;		second part of s///e is marked `syntax-type' ==> `multiline'
;;	e) Attributes of subroutines: `attrib-group' ==> t
;;		(or 0 if declaration); up to `{' or ';': `syntax-type' => `sub-decl'.
;;      f) Multiline my/our declaration lists etc: `syntax-type' => `multiline'

;; In addition, some parts of RExes may be marked as `REx-interpolated'
;; (value: 0 in //o, 1 if "interpolated variable" is whole-REx, t otherwise).

(defun sane-perl-unwind-to-safe (before &optional end)
  ;; if BEFORE, go to the previous start-of-line on each step of unwinding
  (let ((pos (point)))
    (while (and pos (progn
		      (beginning-of-line)
		      (get-text-property (setq pos (point)) 'syntax-type)))
      (setq pos (sane-perl-beginning-of-property pos 'syntax-type))
      (if (eq pos (point-min))
	  (setq pos nil))
      (if pos
	  (if before
	      (progn
		(goto-char (sane-perl-1- pos))
		(beginning-of-line)
		(setq pos (point)))
	    (goto-char (setq pos (sane-perl-1- pos))))
	;; Up to the start
	(goto-char (point-min))))
    ;; Skip empty lines
    (and (looking-at "\n*=")
	 (/= 0 (skip-chars-backward "\n"))
	 (forward-char))
    (setq pos (point))
    (if end
	;; Do the same for end, going small steps
	(save-excursion
	  (while (and end (< end (point-max))
		      (get-text-property end 'syntax-type))
	    (setq pos end
		  end (next-single-property-change end 'syntax-type nil (point-max)))
	    (if end (progn (goto-char end)
			   (or (bolp) (forward-line 1))
			   (setq end (point)))))
	  (or end pos)))))

(defun sane-perl-find-sub-attrs (&optional st-l b-fname e-fname pos)
  "Syntactically mark (and fontify) attributes of a subroutine.
Should be called with the point before leading colon of an attribute."
  ;; Works *before* syntax recognition is done
  (or st-l (setq st-l (list nil)))	; Avoid overwriting '()
  (let (st p reset-st after-first (start (point)) start1 end1)
    (condition-case b
	(while (looking-at
		(concat
		 "\\("			; 1=optional? colon
		   ":" sane-perl-maybe-white-and-comment-rex ; 2=whitespace/comment?
		 "\\)"
		 (if after-first "?" "")
		 ;; No space between name and paren allowed...
		 "\\(\\sw+\\)"		; 3=name
		 "\\((\\)?"))		; 4=optional paren
	  (and (match-beginning 1)
	       (sane-perl-postpone-fontification
		(match-beginning 0) (sane-perl-1+ (match-beginning 0))
		'face font-lock-constant-face))
	  (setq start1 (match-beginning 3) end1 (match-end 3))
	  (sane-perl-postpone-fontification start1 end1
					'face font-lock-constant-face)
	  (goto-char end1)		; end or before `('
	  (if (match-end 4)		; Have attribute arguments...
	      (progn
		(if st nil
		  (setq st (sane-perl-cached-syntax-table st-l))
		  (modify-syntax-entry ?\( "()" st)
		  (modify-syntax-entry ?\) ")(" st))
		(setq reset-st (syntax-table) p (point))
		(set-syntax-table st)
		(forward-sexp 1)
		(set-syntax-table reset-st)
		(setq reset-st nil)
		(sane-perl-commentify p (point) t))) ; mark as string
	  (forward-comment (buffer-size))
	  (setq after-first t))
      (error (message
	      "L%d: attribute `%s': %s"
	      (count-lines (point-min) (point))
	      (and start1 end1 (buffer-substring start1 end1)) b)
	     (setq start nil)))
    (and start
	 (progn
	   (put-text-property start (point)
			      'attrib-group (if (looking-at "{") t 0))
	   (and pos
		(< 1 (count-lines (+ 3 pos) (point))) ; end of `sub'
		;; Apparently, we do not need `multiline': faces added now
		(put-text-property (+ 3 pos) (sane-perl-1+ (point))
				   'syntax-type 'sub-decl))
	   (and b-fname			; Fontify here: the following condition
		(sane-perl-postpone-fontification ; is too hard to determine by
		 b-fname e-fname 'face ; a REx, so do it here
		(if (looking-at "{")
		    font-lock-function-name-face
		  font-lock-variable-name-face)))))
    ;; now restore the initial state
    (if st
	(progn
	  (modify-syntax-entry ?\( "." st)
	  (modify-syntax-entry ?\) "." st)))
    (if reset-st
	(set-syntax-table reset-st))))

(defsubst sane-perl-look-at-leading-count (is-x-REx e)
  (if (and
       (< (point) e)
       (re-search-forward (concat "\\=" (if is-x-REx "[ \t\n]*" "") "[{?+*]")
			  (1- e) t))	; return nil on failure, no moving
      (if (eq ?\{ (preceding-char)) nil
	(sane-perl-postpone-fontification
	 (1- (point)) (point)
	 'face font-lock-warning-face))))

;; Do some smarter-highlighting
;; XXXX Currently ignores alphanum/dash delims,
(defsubst sane-perl-highlight-charclass (endbracket dashface bsface onec-space)
  (let ((l '(1 5 7)) ll lle lll
	;; 2 groups, the first takes the whole match (include \[trnfabe])
	(singleChar (concat "\\(" "[^\\]" "\\|" "\\\\[^cdg-mo-qsu-zA-Z0-9_]" "\\|" "\\\\c." "\\|" "\\\\x" "\\([[:xdigit:]][[:xdigit:]]?\\|\\={[[:xdigit:]]+}\\)" "\\|" "\\\\0?[0-7][0-7]?[0-7]?" "\\|" "\\\\N{[^{}]*}" "\\)")))
    (while				; look for unescaped - between non-classes
	(re-search-forward
	 ;; On 19.33, certain simplifications lead
	 ;; to bugs (as in  [^a-z] \\| [trnfabe]  )
	 (concat	       		; 1: SingleChar (include \[trnfabe])
	  singleChar
	  ;;"\\(" "[^\\]" "\\|" "\\\\[^cdg-mo-qsu-zA-Z0-9_]" "\\|" "\\\\c." "\\|" "\\\\x" "\\([[:xdigit:]][[:xdigit:]]?\\|\\={[[:xdigit:]]+}\\)" "\\|" "\\\\0?[0-7][0-7]?[0-7]?" "\\|" "\\\\N{[^{}]*}" "\\)"
	  "\\("				; 3: DASH SingleChar (match optionally)
	    "\\(-\\)"			; 4: DASH
	    singleChar			; 5: SingleChar
	    ;;"\\(" "[^\\]" "\\|" "\\\\[^cdg-mo-qsu-zA-Z0-9_]" "\\|" "\\\\c." "\\|" "\\\\x" "\\([[:xdigit:]][[:xdigit:]]?\\|\\={[[:xdigit:]]+}\\)" "\\|" "\\\\0?[0-7][0-7]?[0-7]?" "\\|" "\\\\N{[^{}]*}" "\\)"
	  "\\)?"
	  "\\|"
	  "\\("				; 7: other escapes
	    "\\\\[pP]" "\\([^{]\\|{[^{}]*}\\)"
	    "\\|" "\\\\[^pP]" "\\)")
	 endbracket 'toend)
      (if (match-beginning 4)
	  (sane-perl-postpone-fontification
	   (match-beginning 4) (match-end 4)
	   'face dashface))
      ;; save match data (for looking-at)
      (setq lll (mapcar (function (lambda (elt) (cons (match-beginning elt)
						 (match-end elt))))
                        l))
      (while lll
	(setq ll (car lll))
	(setq lle (cdr ll)
	      ll (car ll))
	;; (message "Got %s of %s" ll l)
	(if (and ll (eq (char-after ll) ?\\ ))
	    (save-excursion
	      (goto-char ll)
	      (sane-perl-postpone-fontification ll (1+ ll)
	       'face bsface)
	      (if (looking-at "\\\\[a-zA-Z0-9]")
		  (sane-perl-postpone-fontification (1+ ll) lle
		   'face onec-space))))
	(setq lll (cdr lll))))
    (goto-char endbracket)		; just in case something misbehaves???
    t))


(defconst quoted-construct 10)
(defconst special-construct 11)
(defconst dollar-brace 18)

;; Debugging this may require (setq max-specpdl-size 2000)...
(defun sane-perl-find-pods-heres (&optional min max non-inter end ignore-max end-of-here-doc)
  "Scans the buffer for hard-to-parse Perl constructions.
If `sane-perl-pod-here-fontify' is not-nil after evaluation, will fontify
the sections using `sane-perl-pod-head-face', `sane-perl-pod-face',
`sane-perl-here-face'."
  (interactive)
  (or min (setq min (point-min)
		sane-perl-syntax-state nil
		sane-perl-syntax-done-to min))
  (or max (setq max (point-max)))
  (let* ((sane-perl-pod-here-fontify (eval sane-perl-pod-here-fontify)) go tmpend
	 face head-face here-face b e bb b4 d p tag qtag b1 e1 argument i c tail tb
	 is-REx is-x-REx REx-subgr-start REx-subgr-end was-subgr i2 hairy-RE
	 (case-fold-search nil) (inhibit-read-only t) (buffer-undo-list t)
	 (modified (buffer-modified-p)) overshoot is-o-REx name
	 (inhibit-modification-hooks t)
	 (sane-perl-font-locking t)
	 (use-syntax-state (and sane-perl-syntax-state
				(>= min (car sane-perl-syntax-state))))
	 (state-point (if use-syntax-state
			  (car sane-perl-syntax-state)
			(point-min)))
	 (state (if use-syntax-state
		    (cdr sane-perl-syntax-state)))
	 ;; (st-l '(nil)) (err-l '(nil)) ; Would overwrite - propagates from a function call to a function call!
	 (st-l (list nil)) (err-l (list nil))
	 ;; Somehow font-lock may be not loaded yet...
	 ;; (e.g., when building TAGS via command-line call)
	 (font-lock-string-face (if (boundp 'font-lock-string-face)
				    font-lock-string-face
				  'font-lock-string-face))
	 (my-sane-perl-delimiters-face (if (boundp 'font-lock-constant-face)
				      font-lock-constant-face
				    'font-lock-constant-face))
	 (my-sane-perl-REx-spec-char-face	; [] ^.$ and wrapper-of ({})
	  (if (boundp 'font-lock-function-name-face)
	      font-lock-function-name-face
	    'font-lock-function-name-face))
	 (font-lock-variable-name-face	; interpolated vars and ({})-code
	  (if (boundp 'font-lock-variable-name-face)
	      font-lock-variable-name-face
	    'font-lock-variable-name-face))
	 (font-lock-function-name-face	; used in `sane-perl-find-sub-attrs'
	  (if (boundp 'font-lock-function-name-face)
	      font-lock-function-name-face
	    'font-lock-function-name-face))
	 (font-lock-constant-face	; used in `sane-perl-find-sub-attrs'
	  (if (boundp 'font-lock-constant-face)
	      font-lock-constant-face
	    'font-lock-constant-face))
	 (my-sane-perl-REx-0length-face ; 0-length, (?:)etc, non-literal \
	  (if (boundp 'font-lock-builtin-face)
	      font-lock-builtin-face
	    'font-lock-builtin-face))
	 (font-lock-comment-face
	  (if (boundp 'font-lock-comment-face)
	      font-lock-comment-face
	    'font-lock-comment-face))
	 (font-lock-warning-face
	  (if (boundp 'font-lock-warning-face)
	      font-lock-warning-face
	    'font-lock-warning-face))
	 (my-sane-perl-REx-ctl-face		; (|)
	  (if (boundp 'font-lock-keyword-face)
	      font-lock-keyword-face
	    'font-lock-keyword-face))
	 (my-sane-perl-REx-modifiers-face	; //gims
	  (if (boundp 'sane-perl-nonoverridable-face)
	      sane-perl-nonoverridable-face
	    'sane-perl-nonoverridable-face))
	 (my-sane-perl-REx-length1-face	; length=1 escaped chars, POSIX classes
	  (if (boundp 'font-lock-type-face)
	      font-lock-type-face
	    'font-lock-type-face))
	 (stop-point (if ignore-max
			 (point-max)
		       max))
	 (search
	  (concat
	   "\\(\\`\n?\\|^\n\\)="	; 0=POD
	   "\\|"
	   ;; One extra () before this:
	   "<<\\(~?\\)"		 ; 1=HERE-DOC, indented-p = capture 2
	   "\\("			; 2 + 1
	   ;; First variant "BLAH" or just ``.
	   "[ \t]*"			; Yes, whitespace is allowed!
	   "\\([\"'`]\\)"		; 3 + 1 = 4
	   "\\([^\"'`\n]*\\)"		; 4 + 1
	   "\\4"
	   "\\|"
	   ;; Second variant: Identifier or \ID (same as 'ID') or empty
	   "\\\\?\\(\\([a-zA-Z_][a-zA-Z_0-9]*\\)?\\)" ; 5 + 1, 6 + 1
	   ;; Do not have <<= or << 30 or <<30 or << $blah.
	   ;; "\\([^= \t0-9$@%&]\\|[ \t]+[^ \t\n0-9$@%&]\\)" ; 6 + 1
	   "\\)"
	   "\\|"
	   ;; 1+6 extra () before this:
	   "^[ \t]*\\(format\\)[ \t]*\\([a-zA-Z0-9_]+\\)?[ \t]*=[ \t]*$" ;FRMAT
	   (if sane-perl-use-syntax-table-text-property
	       (concat
		"\\|"
		;; 1+6+2=9 extra () before this:
		"\\<\\(q[wxqr]?\\|[msy]\\|tr\\)\\>" ; QUOTED CONSTRUCT
		"\\|"
		;; 1+6+2+1=10 extra () before this:
		"\\([?/<]\\)"	; /blah/ or ?blah? or <file*glob>
		"\\|"
		;; 1+6+2+1+1=11 extra () before this
		"\\<" sane-perl--sub-regexp "\\>" ;  sub with proto/attr
		"\\("
		   sane-perl-white-and-comment-rex
		   "\\(::[a-zA-Z_:'0-9]*\\|[a-zA-Z_'][a-zA-Z_:'0-9]*\\)\\)?" ; name
		"\\("
		   sane-perl-maybe-white-and-comment-rex
		   "\\(([^()]*)\\|:[^:]\\)\\)" ; prototype or attribute start
		"\\|"
		;; 1+6+2+1+1+6=17 extra () before this:
		"\\$\\(['{]\\)"		; $' or ${foo}
		"\\|"
		;; 1+6+2+1+1+6+1=18 extra () before this (old pack'var syntax;
		;; we do not support intervening comments...):
		"\\(\\<" sane-perl--sub-regexp "[ \t\n\f]+\\|[&*$@%]\\)[a-zA-Z0-9_]*'"
		;; 1+6+2+1+1+6+1+1=19 extra () before this:
		"\\|"
		"__\\(END\\|DATA\\)__"	; __END__ or __DATA__
		;; 1+6+2+1+1+6+1+1+1=20 extra () before this:
		"\\|"
		"\\\\\\(['`\"($]\\)")	; BACKWACKED something-hairy
	     ""))))
    (unwind-protect
	(progn
	  (save-excursion
	    (or non-inter
		(message "Scanning for \"hard\" Perl constructions..."))
	    (and sane-perl-pod-here-fontify
		 ;; We had evals here, do not know why...
		 (setq face sane-perl-pod-face
		       head-face sane-perl-pod-head-face
		       here-face sane-perl-here-face))
	    (remove-text-properties min max
				    '(syntax-type t in-pod t syntax-table t
						  attrib-group t
						  REx-interpolated t
						  sane-perl-postpone t
						  syntax-subtype t
						  rear-nonsticky t
						  front-sticky t
						  here-doc-group t
						  first-format-line t
						  REx-part2 t
						  indentable t))
	    ;; Need to remove face as well...
	    (goto-char min)
	    (while (and
		    (< (point) max)
		    (re-search-forward search max t))
	      (setq tmpend nil)		; Valid for most cases
	      (setq b (match-beginning 0)
		    state (save-excursion (parse-partial-sexp
					   state-point b nil nil state))
		    state-point b)
	      (cond
	       ;; 1+6+2+1+1+6=17 extra () before this:
	       ;;    "\\$\\(['{]\\)"
	       ((match-beginning dollar-brace) ; $' or ${foo}
		(if (eq (preceding-char) ?\') ; $'
		    (progn
		      (setq b (1- (point))
			    state (parse-partial-sexp
				   state-point (1- b) nil nil state)
			    state-point (1- b))
		      (if (nth 3 state)	; in string
			  (sane-perl-modify-syntax-type (1- b) sane-perl-st-punct))
		      (goto-char (1+ b)))
		  ;; else: ${
		  (setq bb (match-beginning 0))
		  (sane-perl-modify-syntax-type bb sane-perl-st-punct)))
	       ;; No processing in strings/comments beyond this point:
	       ((or (nth 3 state) (nth 4 state))
		t)			; Do nothing in comment/string
	       ((match-beginning 1)	; POD section
		;;  "\\(\\`\n?\\|^\n\\)="
		(setq b (match-beginning 0)
		      state (parse-partial-sexp
			     state-point b nil nil state)
		      state-point b)
		(if (or (nth 3 state) (nth 4 state)
			(looking-at "\\(cut\\|end\\)\\>"))
		    (if (or (nth 3 state) (nth 4 state) ignore-max)
			nil		; Doing a chunk only
		      (message "=cut is not preceded by a POD section")
		      (or (car err-l) (setcar err-l (point))))
		  (beginning-of-line)

		  (setq b (point)
			bb b
			tb (match-beginning 0)
			b1 nil)		; error condition
		  ;; We do not search to max, since we may be called from
		  ;; some hook of fontification, and max is random
		  (or (re-search-forward "^\n=\\(cut\\|end\\)\\>" stop-point 'toend)
		      (progn
			(goto-char b)
			(if (re-search-forward "\n=\\(cut\\|end\\)\\>" stop-point 'toend)
			    (progn
			      (message "=cut is not preceded by an empty line")
			      (setq b1 t)
			      (or (car err-l) (setcar err-l b))))))
		  (beginning-of-line 2)	; An empty line after =cut is not POD!
		  (setq e (point))
		  (and (> e max)
		       (progn
			 (remove-text-properties
			  max e '(syntax-type t in-pod t syntax-table t
					      attrib-group t
					      REx-interpolated t
					      sane-perl-postpone t
					      syntax-subtype t
					      here-doc-group t
					      rear-nonsticky t
					      front-sticky t
					      first-format-line t
					      REx-part2 t
					      indentable t))
			 (setq tmpend tb)))
		  (put-text-property b e 'in-pod t)
		  (put-text-property b e 'syntax-type 'in-pod)
		  (goto-char b)
		  (while (re-search-forward "\n\n[ \t]" e t)
		    ;; We start 'pod 1 char earlier to include the preceding line
		    (beginning-of-line)
		    (put-text-property (sane-perl-1- b) (point) 'syntax-type 'pod)
		    (sane-perl-put-do-not-fontify b (point) t)
		    ;; mark the non-literal parts as PODs
		    (if sane-perl-pod-here-fontify
			(sane-perl-postpone-fontification b (point) 'face face t))
		    (re-search-forward "\n\n[^ \t\f\n]" e 'toend)
		    (beginning-of-line)
		    (setq b (point)))
		  (put-text-property (sane-perl-1- (point)) e 'syntax-type 'pod)
		  (sane-perl-put-do-not-fontify (point) e t)
		  (if sane-perl-pod-here-fontify
		      (progn
			;; mark the non-literal parts as PODs
			(sane-perl-postpone-fontification (point) e 'face face t)
			(goto-char bb)
			(if (looking-at
			     "=[a-zA-Z0-9_]+\\>[ \t]*\\(\\(\n?[^\n]\\)+\\)$")
			    ;; mark the headers
			    (sane-perl-postpone-fontification
			     (match-beginning 1) (match-end 1)
			     'face head-face))
			(while (re-search-forward
				;; One paragraph
				"^\n=[a-zA-Z0-9_]+\\>[ \t]*\\(\\(\n?[^\n]\\)+\\)$"
				e 'toend)
			  ;; mark the headers
			  (sane-perl-postpone-fontification
			   (match-beginning 1) (match-end 1)
			   'face head-face))))
		  (sane-perl-commentify bb e nil)
		  (goto-char e)
		  (or (eq e (point-max))
		      (forward-char -1)))) ; Prepare for immediate POD start.
	       ;; Here document
	       ;; We can do many here-per-line;
	       ;; but multiline quote on the same line as <<HERE confuses us...
               ;; ;; One extra () before this:
	       ;;"<<"
	       ;;  "\\("			; 1 + 1
	       ;;  ;; First variant "BLAH" or just ``.
	       ;;     "[ \t]*"			; Yes, whitespace is allowed!
	       ;;     "\\([\"'`]\\)"	; 2 + 1
	       ;;     "\\([^\"'`\n]*\\)"	; 3 + 1
	       ;;     "\\3"
	       ;;  "\\|"
	       ;;  ;; Second variant: Identifier or \ID or empty
	       ;;    "\\\\?\\(\\([a-zA-Z_][a-zA-Z_0-9]*\\)?\\)" ; 4 + 1, 5 + 1
	       ;;    ;; Do not have <<= or << 30 or <<30 or << $blah.
	       ;;    ;; "\\([^= \t0-9$@%&]\\|[ \t]+[^ \t\n0-9$@%&]\\)" ; 6 + 1
	       ;;    "\\(\\)"		; To preserve count of pars :-( 6 + 1
	       ;;  "\\)"
	       ((match-beginning 3)     ; 1 + 1
		(setq b (point)
		      tb (match-beginning 0)
		      c (and		; not HERE-DOC
			 (match-beginning 6)
			 (save-match-data
			   (or (looking-at "[ \t]*(") ; << function_call()
			       (save-excursion ; 1 << func_name, or $foo << 10
				 (condition-case nil
				     (progn
				       (goto-char tb)
	       ;;; XXX What to do: foo <<bar ???
	       ;;; XXX Need to support print {a} <<B ???
				       (forward-sexp -1)
				       (save-match-data
					; $foo << b; $f .= <<B;
					; ($f+1) << b; a($f) . <<B;
					; foo 1, <<B; $x{a} <<b;
					 (cond
					  ((looking-at "[0-9$({]")
					   (forward-sexp 1)
					   (and
					    (looking-at "[ \t]*<<")
					    (condition-case nil
						;; print $foo <<EOF
						(progn
						  (forward-sexp -2)
						  (not
						   (looking-at "\\(printf?\\|say\\|system\\|exec\\|sort\\)\\>")))
						(error t)))))))
				   (error nil))) ; func(<<EOF)
			       (and (not (match-beginning 7)) ; Empty
				    (looking-at
				     "[ \t]*[=0-9$@%&(]"))))))
		(if c			; Not here-doc
		    nil			; Skip it.
		  (setq c (match-end 3)) ; 2 + 1
		  (if (match-beginning 6) ;5 + 1
		      (setq b1 (match-beginning 6) ; 5 + 1
			    e1 (match-end 6)) ; 5 + 1
		    (setq b1 (match-beginning 5) ; 4 + 1
			  e1 (match-end 5))) ; 4 + 1
		  (setq tag (buffer-substring b1 e1)
			qtag (regexp-quote tag))
		  (cond (sane-perl-pod-here-fontify
			 ;; Highlight the starting delimiter
			 (sane-perl-postpone-fontification
			  b1 e1 'face my-sane-perl-delimiters-face)
			 (sane-perl-put-do-not-fontify b1 e1 t)))
		  (forward-line)
		  (setq i (point))
		  (if end-of-here-doc
		      (goto-char end-of-here-doc))
		  (setq b (point))
		  ;; We do not search to max, since we may be called from
		  ;; some hook of fontification, and max is random
		  (or (and (re-search-forward
			    (concat "^" (when (equal (match-string 2) "~") "[ \t]*")
				    qtag "$")
			    stop-point 'toend)
			   ;;;(eq (following-char) ?\n) ; XXXX WHY???
			   )
		    (progn		; Pretend we matched at the end
		      (goto-char (point-max))
		      (re-search-forward "\\'")
		      (message "End of here-document `%s' not found." tag)
		      (or (car err-l) (setcar err-l b))))
		  (if sane-perl-pod-here-fontify
		      (progn
			;; Highlight the ending delimiter
			(sane-perl-postpone-fontification
			 (match-beginning 0) (match-end 0)
			 'face my-sane-perl-delimiters-face)
			(sane-perl-put-do-not-fontify b (match-end 0) t)
			;; Highlight the HERE-DOC
			(sane-perl-postpone-fontification b (match-beginning 0)
						      'face here-face)))
		  (setq e1 (sane-perl-1+ (match-end 0)))
		  (put-text-property b (match-beginning 0)
				     'syntax-type 'here-doc)
		  (put-text-property (match-beginning 0) e1
				     'syntax-type 'here-doc-delim)
		  (put-text-property b e1 'here-doc-group t)
		  ;; This makes insertion at the start of HERE-DOC update
		  ;; the whole construct:
		  (put-text-property b (sane-perl-1+ b) 'front-sticky '(syntax-type))
		  (sane-perl-commentify b e1 nil)
		  (sane-perl-put-do-not-fontify b (match-end 0) t)
		  ;; Cache the syntax info...
		  (setq sane-perl-syntax-state (cons state-point state))
		  ;; ... and process the rest of the line...
		  (setq overshoot
			(elt		; non-inter ignore-max
			 (sane-perl-find-pods-heres c i t end t e1) 1))
		  (if (and overshoot (> overshoot (point)))
		      (goto-char overshoot)
		    (setq overshoot e1))
		  (if (> e1 max)
		      (setq tmpend tb))))
	       ;; format
	       ((match-beginning 8)
		;; 1+6=7 extra () before this:
		;;"^[ \t]*\\(format\\)[ \t]*\\([a-zA-Z0-9_]+\\)?[ \t]*=[ \t]*$"
		(setq b (point)
		      name (if (match-beginning 8) ; 7 + 1
			       (buffer-substring (match-beginning 8) ; 7 + 1
						 (match-end 8)) ; 7 + 1
			     "")
		      tb (match-beginning 0))
		(setq argument nil)
		(put-text-property (line-beginning-position) b 'first-format-line 't)
		(if sane-perl-pod-here-fontify
		    (while (and (eq (forward-line) 0)
				(not (looking-at "^[.;]$")))
		      (cond
		       ((looking-at "^#")) ; Skip comments
		       ((and argument	; Skip argument multi-lines
			     (looking-at "^[ \t]*{"))
			(forward-sexp 1)
			(setq argument nil))
		       (argument	; Skip argument lines
			(setq argument nil))
		       (t		; Format line
			(setq b1 (point))
			(setq argument (looking-at "^[^\n]*[@^]"))
			(end-of-line)
			;; Highlight the format line
			(sane-perl-postpone-fontification b1 (point)
						      'face font-lock-string-face)
			(sane-perl-commentify b1 (point) nil)
			(sane-perl-put-do-not-fontify b1 (point) t))))
		  ;; We do not search to max, since we may be called from
		  ;; some hook of fontification, and max is random
		  (re-search-forward "^[.;]$" stop-point 'toend))
		(beginning-of-line)
		(if (looking-at "^\\.$") ; ";" is not supported yet
		    (progn
		      ;; Highlight the ending delimiter
		      (sane-perl-postpone-fontification (point) (+ (point) 2)
						    'face font-lock-string-face)
		      (sane-perl-commentify (point) (+ (point) 2) nil)
		      (sane-perl-put-do-not-fontify (point) (+ (point) 2) t))
		  (message "End of format `%s' not found." name)
		  (or (car err-l) (setcar err-l b)))
		(forward-line)
		(if (> (point) max)
		    (setq tmpend tb))
		(put-text-property b (point) 'syntax-type 'format))
	       ;; qq-like String or Regexp:
	       ((or (match-beginning quoted-construct)
		    (match-beginning special-construct))
		;; 1+6+2=9 extra () before this:
		;; "\\<\\(q[wxqr]?\\|[msy]\\|tr\\)\\>"
		;; "\\|"
		;; "\\([?/<]\\)"	; /blah/ or ?blah? or <file*glob>
		(setq b1 (if (match-beginning quoted-construct)
			     quoted-construct special-construct)
		      p (match-beginning b1)
		      argument (buffer-substring p (match-end b1))
		      b (point)		; end of qq etc
		      i b
		      c (char-after p)
		      b4 (char-after (1- p))
		      d (char-after (- p 2))
		      ;; bb == "Not a stringy"
		      bb (if (eq b1 quoted-construct) ; user variables/whatever
			     (or
			      ;; false positive: "y_" has no word boundary
                              (save-match-data (looking-at "_"))
			      (and (memq b4 (append "$@%*#_:-&>" nil)) ; $#y)
				  (cond ((eq b4 ?-) (eq c ?s)) ; -s file test
					((eq b4 ?\:) ; $opt::s
					 (eq d ?\:))
					((eq b4 ?\>) ; $foo->s
					 (eq d ?\-))
					((eq b4 ?\&) ; &&m/blah/
					 (not (eq d ?\&)))
					(t t))))
			   ;; <file> or <$file>
			   (and (eq c ?\<)
				;; Do not stringify <FH>, <$fh> :
				(save-match-data
				  (looking-at
				   "\\$?\\([_a-zA-Z:][_a-zA-Z0-9:]*\\)?>"))))
		      tb (match-beginning 0))
		(goto-char (match-beginning b1))
		(sane-perl-backward-to-noncomment (point-min))
		(or bb
		    (if (eq b1 special-construct)	; bare /blah/ or ?blah? or <foo>
			(setq argument ""
			      b1 nil
			      bb	; Not a regexp?
			      (not
			       ;; What is below: regexp-p?
			       (and
				(or (memq (preceding-char)
					  (append (if (memq c '(?\? ?\<))
						      ;; $a++ ? 1 : 2
						      "~{(=|&*!,;:["
						    "~{(=|&+-*!,;:[") nil))
				    (and (eq (preceding-char) ?\})
					 (sane-perl-after-block-p (point-min)))
				    (and (eq (char-syntax (preceding-char)) ?w)
					 (progn
					   (forward-sexp -1)
					   ;; After these keywords `/' starts a RE.
					   ;; One should add all the
					   ;; functions/builtins which expect an
					   ;; argument, but ...
					   (if (eq (preceding-char) ?-)
					       ;; -d ?foo? is a RE
					       (looking-at "[a-zA-Z]\\>")
					     (and
					      (not (memq (preceding-char)
							 '(?$ ?@ ?& ?%)))
					      (looking-at
					       "\\(while\\|if\\|unless\\|until\\|and\\|or\\|not\\|xor\\|split\\|grep\\|map\\|print\\|say\\)\\>")))))
				    (and (eq (preceding-char) ?.)
					 (eq (char-after (- (point) 2)) ?.))
				    (bobp))
				;; { $a++ / $b } doesn't start a regex, nor does $a--
				(not (and (memq (preceding-char) '(?+ ?-))
					  (eq (preceding-char) (char-before (1- (point))))))
				;;  m|blah| ? foo : bar;
				(not
				 (and (eq c ?\?)
				      sane-perl-use-syntax-table-text-property
				      (not (bobp))
				      (progn
					(forward-char -1)
					(looking-at "\\s|"))))))
			      b (1- b))
		      ;; s y tr m
		      ;; Check for $a -> y
		      (setq b1 (preceding-char)
			    go (point))
		      (if (and (eq b1 ?>)
			       (eq (char-after (- go 2)) ?-))
			  ;; Not a regexp
			  (setq bb t))))
		(or bb
		    (progn
		      (goto-char b)
		      (if (looking-at "[ \t\n\f]+\\(#[^\n]*\n[ \t\n\f]*\\)+")
			  (goto-char (match-end 0))
			(skip-chars-forward " \t\n\f"))
		      (cond ((and (eq (following-char) ?\})
				  (eq b1 ?\{))
			     ;; Check for $a[23]->{ s }, @{s} and *{s::foo}
			     (goto-char (1- go))
			     (skip-chars-backward " \t\n\f")
			     (if (memq (preceding-char) (append "$@%&*" nil))
				 (setq bb t) ; @{y}
			       (condition-case nil
				   (forward-sexp -1)
				 (error nil)))
			     (if (or bb
				     (looking-at ; $foo -> {s}
				      "[$@]\\$*\\([a-zA-Z0-9_:]+\\|[^{]\\)\\([ \t\n]*->\\)?[ \t\n]*{")
				     (and ; $foo[12] -> {s}
				      (memq (following-char) '(?\{ ?\[))
				      (progn
					(forward-sexp 1)
					(looking-at "\\([ \t\n]*->\\)?[ \t\n]*{"))))
				 (setq bb t)
			       (goto-char b)))
			    ((and (eq (following-char) ?=)
				  (eq (char-after (1+ (point))) ?\>))
			     ;; Check for { foo => 1, s => 2 }
			     ;; Apparently s=> is never a substitution...
			     (setq bb t))
			    ((and (eq (following-char) ?:)
				  (eq b1 ?\{) ; Check for $ { s::bar }
				  (looking-at "::[a-zA-Z0-9_:]*[ \t\n\f]*}")
				  (progn
				    (goto-char (1- go))
				    (skip-chars-backward " \t\n\f")
				    (memq (preceding-char)
					  (append "$@%&*" nil))))
			     (setq bb t))
			    ((eobp)
			     (setq bb t)))))
		(if bb
		    (goto-char i)
		  ;; Skip whitespace and comments...
		  (if (looking-at "[ \t\n\f]+\\(#[^\n]*\n[ \t\n\f]*\\)+")
		      (goto-char (match-end 0))
		    (skip-chars-forward " \t\n\f"))
		  (if (> (point) b)
		      (put-text-property b (point) 'syntax-type 'prestring))
		  ;; qtag means two-arg matcher, may be reset to
		  ;;   2 or 3 later if some special quoting is needed.
		  ;; e1 means matching-char matcher.
		  (setq b (point)	; before the first delimiter
			;; has 2 args
			i2 (string-match "^\\([sy]\\|tr\\)$" argument)
			;; We do not search to max, since we may be called from
			;; some hook of fontification, and max is random
			i (sane-perl-forward-re stop-point end
					    i2
					    st-l err-l argument)
			;; If `go', then it is considered as 1-arg, `b1' is nil
			;; as in s/foo//x; the point is before final "slash"
			b1 (nth 1 i)	; start of the second part
			tag (nth 2 i)	; ender-char, true if second part
					; is with matching chars []
			go (nth 4 i)	; There is a 1-char part after the end
			i (car i)	; intermediate point
			e1 (point)	; end
			;; Before end of the second part if non-matching: ///
			tail (if (and i (not tag))
				 (1- e1))
			e (if i i e1)	; end of the first part
			qtag nil	; need to preserve backslashitis
			is-x-REx nil is-o-REx nil); REx has //x //o modifiers
		  ;; If s{} (), then b/b1 are at "{", "(", e1/i after ")", "}"
		  ;; Commenting \\ is dangerous, what about ( ?
		  (and i tail
		       (eq (char-after i) ?\\)
		       (setq qtag t))
		  (and (if go (looking-at ".\\sw*x")
			 (looking-at "\\sw*x")) ; qr//x
		       (setq is-x-REx t))
		  (and (if go (looking-at ".\\sw*o")
			 (looking-at "\\sw*o")) ; //o
		       (setq is-o-REx t))
		  (if (null i)
		      ;; Considered as 1arg form
		      (progn
			(sane-perl-commentify b (point) t)
			(put-text-property b (point) 'syntax-type 'string)
			(if (or is-x-REx
				;; ignore other text properties:
				(string-match "^qw$" argument))
			    (put-text-property b (point) 'indentable t))
			(and go
			     (setq e1 (sane-perl-1+ e1))
			     (or (eobp)
				 (forward-char 1))))
		    (sane-perl-commentify b i t)
		    (if (looking-at "\\sw*e") ; s///e
			(progn
			  ;; Cache the syntax info...
			  (setq sane-perl-syntax-state (cons state-point state))
			  (and
			   ;; silent:
			   (car (sane-perl-find-pods-heres b1 (1- (point)) t end))
			   ;; Error
			   (goto-char (1+ max)))
			  (if (and tag (eq (preceding-char) ?\>))
			      (progn
				(sane-perl-modify-syntax-type (1- (point)) sane-perl-st-ket)
				(sane-perl-modify-syntax-type i sane-perl-st-bra)))
			  (put-text-property b i 'syntax-type 'string)
			  (put-text-property i (point) 'syntax-type 'multiline)
			  (if is-x-REx
			      (put-text-property b i 'indentable t)))
		      (sane-perl-commentify b1 (point) t)
		      (put-text-property b (point) 'syntax-type 'string)
		      (if is-x-REx
			  (put-text-property b i 'indentable t))
		      (if qtag
			  (sane-perl-modify-syntax-type (1+ i) sane-perl-st-punct))
		      (setq tail nil)))
		  ;; Now: tail: if the second part is non-matching without ///e
		  (if (eq (char-syntax (following-char)) ?w)
		      (progn
			(forward-word-strictly 1) ; skip modifiers s///s
			(if tail (sane-perl-commentify tail (point) t))
			(sane-perl-postpone-fontification
			 e1 (point) 'face my-sane-perl-REx-modifiers-face)))
		  ;; Check whether it is m// which means "previous match"
		  ;; and highlight differently
		  (setq is-REx
			(and (string-match "^\\([sm]?\\|qr\\)$" argument)
			     (or (not (= (length argument) 0))
				 (not (eq c ?\<)))))
		  (if (and is-REx
			   (eq e (+ 2 b))
			   ;; split // *is* using zero-pattern
			   (save-excursion
			     (condition-case nil
				 (progn
				   (goto-char tb)
				   (forward-sexp -1)
				   (not (looking-at "split\\>")))
			       (error t))))
		      (sane-perl-postpone-fontification
		       b e 'face font-lock-warning-face)
		    (if (or i2		; Has 2 args
			    (and sane-perl-fontify-m-as-s
				 (or
				  (string-match "^\\(m\\|qr\\)$" argument)
				  (and (eq 0 (length argument))
				       (not (eq ?\< (char-after b)))))))
			(progn
			  (sane-perl-postpone-fontification
			   b (sane-perl-1+ b) 'face my-sane-perl-delimiters-face)
			  (sane-perl-postpone-fontification
			   (1- e) e 'face my-sane-perl-delimiters-face)))
		    (if (and is-REx sane-perl-regexp-scan)
			;; Process RExen: embedded comments, charclasses and ]
;;;/\3333\xFg\x{FFF}a\ppp\PPP\qqq\C\99f(?{  foo  })(??{  foo  })/;
;;;/a\.b[^a[:ff:]b]x$ab->$[|$,$ab->[cd]->[ef]|$ab[xy].|^${a,b}{c,d}/;
;;;/(?<=foo)(?<!bar)(x)(?:$ab|\$\/)$|\\\b\x888\776\[\:$/xxx;
;;;m?(\?\?{b,a})? + m/(??{aa})(?(?=xx)aa|bb)(?#aac)/;
;;;m$(^ab[c]\$)$ + m+(^ab[c]\$\+)+ + m](^ab[c\]$|.+)] + m)(^ab[c]$|.+\));
;;;m^a[\^b]c^ + m.a[^b]\.c.;
			(save-excursion
			  (goto-char (1+ b))
			  ;; First
			  (sane-perl-look-at-leading-count is-x-REx e)
			  (setq hairy-RE
				(concat
				 (if is-x-REx
				     (if (eq (char-after b) ?\#)
					 "\\((\\?\\\\#\\)\\|\\(\\\\#\\)"
				       "\\((\\?#\\)\\|\\(#\\)")
				   ;; keep the same count: add a fake group
				   (if (eq (char-after b) ?\#)
				       "\\((\\?\\\\#\\)\\(\\)"
				     "\\((\\?#\\)\\(\\)"))
				 "\\|"
				    "\\(\\[\\)" ; 3=[
				 "\\|"
				    "\\(]\\)" ; 4=]
				 "\\|"
				 ;; XXXX Will not be able to use it in s)))
				 (if (eq (char-after b) ?\) )
				     "\\())))\\)" ; Will never match
				   (if (eq (char-after b) ?? )
				       ;;"\\((\\\\\\?\\(\\\\\\?\\)?{\\)"
				       "\\((\\\\\\?\\\\\\?{\\|()\\\\\\?{\\)"
				     "\\((\\?\\??{\\)")) ; 5= (??{ (?{
				 "\\|"	; 6= 0-length, 7: name, 8,9:code, 10:group
				    "\\(" ;; XXXX 1-char variables, exc. |()\s
				       "[$@]"
				       "\\("
				          "[_a-zA-Z:][_a-zA-Z0-9:]*"
				       "\\|"
				          "{[^{}]*}" ; only one-level allowed
				       "\\|"
				          "[^{(|) \t\r\n\f]"
				       "\\)"
				       "\\(" ;;8,9:code part of array/hash elt
				          "\\(" "->" "\\)?"
				          "\\[[^][]*\\]"
					  "\\|"
				          "{[^{}]*}"
				       "\\)*"
				    ;; XXXX: what if u is delim?
				    "\\|"
				       "[)^|$.*?+]"
				    "\\|"
				       "{[0-9]+}"
				    "\\|"
				       "{[0-9]+,[0-9]*}"
				    "\\|"
				       "\\\\[luLUEQbBAzZGvVhHR]"
				    "\\|"
				       "(" ; Group opener
				       "\\(" ; 10 group opener follower
				          "\\?\\((\\?\\)" ; 11: in (?(?=C)A|B)
				       "\\|"
				          "\\?[:=!>?{]"	; "?" something
				       "\\|"
				          "\\?[-imsx]+[:)]" ; (?i) (?-s:.)
				       "\\|"
				          "\\?([0-9]+)"	; (?(1)foo|bar)
				       "\\|"
					  "\\?<[=!]"
				       "\\|"
					  "\\?<.*?>"
				       "\\|"
					  "\\?'.*?'"
				       ;;;"\\|"
				       ;;;   "\\?"
				       "\\)?"
				    "\\)"
				 "\\|"
				    "\\\\\\(.\\)" ; 12=\SYMBOL
				 ))
			  (while
			      (and (< (point) (1- e))
				   (re-search-forward hairy-RE (1- e) 'to-end))
			    (goto-char (match-beginning 0))
			    (setq REx-subgr-start (point)
				  was-subgr (following-char))
			    (cond
			     ((match-beginning 6) ; 0-length builtins, groups
			      (goto-char (match-end 0))
			      (if (match-beginning 11)
				  (goto-char (match-beginning 11)))
			      (if (>= (point) e)
				  (goto-char (1- e)))
			      (sane-perl-postpone-fontification
			       (match-beginning 0) (point)
			       'face
			       (cond
				((eq was-subgr ?\) )
				 (condition-case nil
				     (save-excursion
				       (forward-sexp -1)
				       (if (> (point) b)
					   (if (if (eq (char-after b) ?? )
						   (looking-at "(\\\\\\?")
						 (eq (char-after (1+ (point))) ?\?))
					       my-sane-perl-REx-0length-face
					     my-sane-perl-REx-ctl-face)
					 font-lock-warning-face))
				   (error font-lock-warning-face)))
				((eq was-subgr ?\| )
				 my-sane-perl-REx-ctl-face)
				((eq was-subgr ?\$ )
				 (if (> (point) (1+ REx-subgr-start))
				     (progn
				       (put-text-property
					(match-beginning 0) (point)
					'REx-interpolated
					(if is-o-REx 0
					    (if (and (eq (match-beginning 0)
							 (1+ b))
						     (eq (point)
							 (1- e))) 1 t)))
				       font-lock-variable-name-face)
				   my-sane-perl-REx-spec-char-face))
				((memq was-subgr (append "^." nil) )
				 my-sane-perl-REx-spec-char-face)
				((eq was-subgr ?\( )
				 (if (not (match-beginning 10))
				     my-sane-perl-REx-ctl-face
				   my-sane-perl-REx-0length-face))
				(t my-sane-perl-REx-0length-face)))
			      (if (and (memq was-subgr (append "(|" nil))
				       (not (string-match "(\\?[-imsx]+)"
							  (match-string 0))))
				  (sane-perl-look-at-leading-count is-x-REx e))
			      (setq was-subgr nil)) ; We do stuff here
			     ((match-beginning 12) ; \SYMBOL
			      (forward-char 2)
			      (if (>= (point) e)
				  (goto-char (1- e))
				;; How many chars to not highlight:
				;; 0-len special-alnums in other branch =>
				;; Generic:  \non-alnum (1), \alnum (1+face)
				;; Is-delim: \non-alnum (1/spec-2) alnum-1 (=what hai)
				(setq REx-subgr-start (point)
				      qtag (preceding-char))
				(sane-perl-postpone-fontification
				 (- (point) 2) (- (point) 1) 'face
				 (if (memq qtag
					   (append "ghijkmoqvFHIJKMORTVY" nil))
				     font-lock-warning-face
				   my-sane-perl-REx-0length-face))
				(if (and (eq (char-after b) qtag)
					 (memq qtag (append ".])^$|*?+" nil)))
				    (progn
				      (if (and sane-perl-use-syntax-table-text-property
					       (eq qtag ?\) ))
					  (put-text-property
					   REx-subgr-start (1- (point))
					   'syntax-table sane-perl-st-punct))
				      (sane-perl-postpone-fontification
				       (1- (point)) (point) 'face
					; \] can't appear below
				       (if (memq qtag (append ".]^$" nil))
					   'my-sane-perl-REx-spec-char-face
					 (if (memq qtag (append "*?+" nil))
					     'my-sane-perl-REx-0length-face
					   'my-sane-perl-REx-ctl-face))))) ; )|
				;; Test for arguments:
				(cond
				 ;; This is not pretty: the 5.8.7 logic:
				 ;; \0numx  -> octal (up to total 3 dig)
				 ;; \DIGIT  -> backref unless \0
				 ;; \DIGITs -> backref if valid
				 ;;	     otherwise up to 3 -> octal
				 ;; Do not try to distinguish, we guess
				 ((or (and (memq qtag (append "01234567" nil))
					   (re-search-forward
					    "\\=[01234567]?[01234567]?"
					    (1- e) 'to-end))
				      (and (memq qtag (append "89" nil))
					   (re-search-forward
					    "\\=[0123456789]*" (1- e) 'to-end))
				      (and (eq qtag ?x)
					   (re-search-forward
					    "\\=[[:xdigit:]][[:xdigit:]]?\\|\\={[[:xdigit:]]+}"
					    (1- e) 'to-end))
				      (and (memq qtag (append "pPN" nil))
					   (re-search-forward "\\={[^{}]+}\\|."
					    (1- e) 'to-end))
				      (eq (char-syntax qtag) ?w))
				  (sane-perl-postpone-fontification
				   (1- REx-subgr-start) (point)
				   'face my-sane-perl-REx-length1-face))))
			      (setq was-subgr nil)) ; We do stuff here
			     ((match-beginning 3) ; [charclass]
			      ;; Highlight leader, trailer, POSIX classes
			      (forward-char 1)
			      (if (eq (char-after b) ?^ )
				  (and (eq (following-char) ?\\ )
				       (eq (char-after (sane-perl-1+ (point)))
					   ?^ )
				       (forward-char 2))
				(and (eq (following-char) ?^ )
				     (forward-char 1)))
			      (setq argument b ; continue? & end of last POSIX
				    tag nil ; list of POSIX classes
				    qtag (point)) ; after leading ^ if present
			      (if (eq (char-after b) ?\] )
				  (and (eq (following-char) ?\\ )
				       (eq (char-after (sane-perl-1+ (point)))
					   ?\] )
				       (setq qtag (1+ qtag))
				       (forward-char 2))
				(and (eq (following-char) ?\] )
				     (forward-char 1)))
			      (setq REx-subgr-end qtag)	;End smart-highlighted
			      ;; Apparently, I can't put \] into a charclass
			      ;; in m]]: m][\\\]\]] produces [\\]]
			      ;;   POSIX?  [:word:] [:^word:] only inside []
			      ;;	    "\\=\\(\\\\.\\|[^][\\]\\|\\[:\\^?\sw+:]\\|\\[[^:]\\)*]")
			      (while    ; look for unescaped ]
				  (and argument
				       (re-search-forward
					(if (eq (char-after b) ?\] )
					    "\\=\\(\\\\[^]]\\|[^]\\]\\)*\\\\]"
					  "\\=\\(\\\\.\\|[^]\\]\\)*]")
					(1- e) 'toend))
				;; Is this ] an end of POSIX class?
				(if (save-excursion
				      (and
				       (search-backward "[" argument t)
				       (< REx-subgr-start (point))
				       (setq argument (point)) ; POSIX-start
				       (or ; Should work with delim = \
					(not (eq (preceding-char) ?\\ ))
					;; XXXX Double \\ is needed with 19.33
					(= (% (skip-chars-backward "\\\\") 2) 0))
				       (looking-at
					(cond
					 ((eq (char-after b) ?\] )
					  "\\\\*\\[:\\^?\\sw+:\\\\\\]")
					 ((eq (char-after b) ?\: )
					  "\\\\*\\[\\\\:\\^?\\sw+\\\\:]")
					 ((eq (char-after b) ?^ )
					  "\\\\*\\[:\\(\\\\\\^\\)?\\sw+:]")
					 ((eq (char-syntax (char-after b))
					      ?w)
					  (concat
					   "\\\\*\\[:\\(\\\\\\^\\)?\\(\\\\"
					   (char-to-string (char-after b))
					   "\\|\\sw\\)+:]"))
					 (t "\\\\*\\[:\\^?\\sw*:]")))
				       (goto-char REx-subgr-end)
				       (sane-perl-highlight-charclass
					argument my-sane-perl-REx-spec-char-face
					my-sane-perl-REx-0length-face my-sane-perl-REx-length1-face)))
				    (setq tag (cons (cons argument (point))
						    tag)
					  argument (point)
					  REx-subgr-end argument) ; continue
				  (setq argument nil)))
			      (and argument
				   (message "Couldn't find end of charclass in a REx, pos=%s"
					    REx-subgr-start))
			      (setq argument (1- (point)))
			      (goto-char REx-subgr-end)
			      (sane-perl-highlight-charclass
			       argument my-sane-perl-REx-spec-char-face
			       my-sane-perl-REx-0length-face my-sane-perl-REx-length1-face)
			      (forward-char 1)
			      ;; Highlight starter, trailer, POSIX
			      (if (and sane-perl-use-syntax-table-text-property
				       (> (- (point) 2) REx-subgr-start))
				  (put-text-property
				   (1+ REx-subgr-start) (1- (point))
				   'syntax-table sane-perl-st-punct))
			      (sane-perl-postpone-fontification
			       REx-subgr-start qtag
			       'face my-sane-perl-REx-spec-char-face)
			      (sane-perl-postpone-fontification
			       (1- (point)) (point) 'face
			       my-sane-perl-REx-spec-char-face)
			      (if (eq (char-after b) ?\] )
				  (sane-perl-postpone-fontification
				   (- (point) 2) (1- (point))
				   'face my-sane-perl-REx-0length-face))
			      (while tag
				(sane-perl-postpone-fontification
				 (car (car tag)) (cdr (car tag))
				 'face font-lock-variable-name-face) ;my-sane-perl-REx-length1-face
				(setq tag (cdr tag)))
			      (setq was-subgr nil)) ; did facing already
			     ;; Now rare stuff:
			     ((and (match-beginning 2) ; #-comment
				   (/= (match-beginning 2) (match-end 2)))
			      (beginning-of-line 2)
			      (if (> (point) e)
				  (goto-char (1- e))))
			     ((match-beginning 4) ; character "]"
			      (setq was-subgr nil) ; We do stuff here
			      (goto-char (match-end 0))
			      (if sane-perl-use-syntax-table-text-property
				  (put-text-property
				   (1- (point)) (point)
				   'syntax-table sane-perl-st-punct))
			      (sane-perl-postpone-fontification
			       (1- (point)) (point)
			       'face font-lock-warning-face))
			     ((match-beginning 5) ; before (?{}) (??{})
			      (setq tag (match-end 0))
			      (if (or (setq qtag
					    (sane-perl-forward-group-in-re st-l))
				      (and (>= (point) e)
					   (setq qtag "no matching `)' found"))
				      (and (not (eq (char-after (- (point) 2))
						    ?\} ))
					   (setq qtag "Can't find })")))
				  (progn
				    (goto-char (1- e))
				    (message "%s" qtag))
				(sane-perl-postpone-fontification
				 (1- tag) (1- (point))
				 'face font-lock-variable-name-face)
				(sane-perl-postpone-fontification
				 REx-subgr-start (1- tag)
				 'face my-sane-perl-REx-spec-char-face)
				(sane-perl-postpone-fontification
				 (1- (point)) (point)
				 'face my-sane-perl-REx-spec-char-face)
				(if sane-perl-use-syntax-table-text-property
				    (progn
				      (put-text-property
				       (- (point) 2) (1- (point))
				       'syntax-table sane-perl-st-cfence)
				      (put-text-property
				       (+ REx-subgr-start 2)
				       (+ REx-subgr-start 3)
				       'syntax-table sane-perl-st-cfence))))
			      (setq was-subgr nil))
			     (t		; (?#)-comment
			      ;; Inside "(" and "\" aren't special in any way
			      ;; Works also if the outside delimiters are ().
			      (or;;(if (eq (char-after b) ?\) )
			       ;;(re-search-forward
			       ;; "[^\\]\\(\\\\\\\\\\)*\\\\)"
			       ;; (1- e) 'toend)
			       (search-forward ")" (1- e) 'toend)
			       ;;)
			       (message
				"Couldn't find end of (?#...)-comment in a REx, pos=%s"
				REx-subgr-start))))
			    (if (>= (point) e)
				(goto-char (1- e)))
			    (cond
			     (was-subgr
			      (setq REx-subgr-end (point))
			      (sane-perl-commentify
			       REx-subgr-start REx-subgr-end nil)
			      (sane-perl-postpone-fontification
			       REx-subgr-start REx-subgr-end
			       'face font-lock-comment-face))))))
		    (if (and is-REx is-x-REx)
			(put-text-property (1+ b) (1- e)
					   'syntax-subtype 'x-REx)))
		  (if (and i2 e1 (or (not b1) (> e1 b1)))
		      (progn		; No errors finding the second part...
			(sane-perl-postpone-fontification
			 (1- e1) e1 'face my-sane-perl-delimiters-face)
			(if (and (not (eobp))
				 (assoc (char-after b) sane-perl-starters))
			    (progn
			      (sane-perl-postpone-fontification
			       b1 (1+ b1) 'face my-sane-perl-delimiters-face)
			      (put-text-property b1 (1+ b1)
					   'REx-part2 t)))))
		  (if (> (point) max)
		      (setq tmpend tb))))
	       ((match-beginning 17)	; sub with prototype or attribute
		;; 1+6+2+1+1=11 extra () before this (sub with proto/attr):
		;;"\\<sub\\>\\("			;12
		;;   sane-perl-white-and-comment-rex	;13
		;;   "\\([a-zA-Z_:'0-9]+\\)\\)?" ; name	;14
		;;"\\(" sane-perl-maybe-white-and-comment-rex	;15,16
		;;   "\\(([^()]*)\\|:[^:]\\)\\)" ; 17:proto or attribute start
		(setq b1 (match-beginning 14) e1 (match-end 14))
		(if (memq (char-after (1- b))
			  '(?\$ ?\@ ?\% ?\& ?\*))
		    nil
		  (goto-char b)
		  (if (eq (char-after (match-beginning 17)) ?\( )
		      (progn
			(sane-perl-commentify ; Prototypes; mark as string
			 (match-beginning 17) (match-end 17) t)
			(goto-char (match-end 0))
			;; Now look for attributes after prototype:
			(forward-comment (buffer-size))
			(and (looking-at ":[^:]")
			     (sane-perl-find-sub-attrs st-l b1 e1 b)))
		    ;; treat attributes without prototype
		    (goto-char (match-beginning 17))
		    (sane-perl-find-sub-attrs st-l b1 e1 b))))
	       ;; 1+6+2+1+1+6+1=18 extra () before this:
	       ;;    "\\(\\<sub[ \t\n\f]+\\|[&*$@%]\\)[a-zA-Z0-9_]*'")
	       ((match-beginning 19)	; old $abc'efg syntax
		(setq bb (match-end 0))
		;;;(if (nth 3 state) nil	; in string
		(put-text-property (1- bb) bb 'syntax-table sane-perl-st-word)
		(goto-char bb))
	       ;; 1+6+2+1+1+6+1+1=19 extra () before this:
	       ;; "__\\(END\\|DATA\\)__"
	       ((match-beginning 20)	; __END__, __DATA__
		(setq bb (match-end 0))
		;; (put-text-property b (1+ bb) 'syntax-type 'pod) ; Cheat
		(sane-perl-commentify b bb nil)
		(setq end t))
	       ;; "\\\\\\(['`\"($]\\)"
	       ((match-beginning 21)
		;; Trailing backslash; make non-quoting outside string/comment
		(setq bb (match-end 0))
		(goto-char b)
		(skip-chars-backward "\\\\")
		;;;(setq i2 (= (% (skip-chars-backward "\\\\") 2) -1))
		(sane-perl-modify-syntax-type b sane-perl-st-punct)
		(goto-char bb))
	       (t (error "Error in regexp of the sniffer")))
	      (if (> (point) stop-point)
		  (progn
		    (if end
			(message "Garbage after __END__/__DATA__ ignored")
		      (message "Unbalanced syntax found while scanning")
		      (or (car err-l) (setcar err-l b)))
		    (goto-char stop-point))))
	    (setq sane-perl-syntax-state (cons state-point state)
		  ;; Do not mark syntax as done past tmpend???
		  sane-perl-syntax-done-to (or tmpend (max (point) max)))
	    ;;(message "state-at=%s, done-to=%s" state-point sane-perl-syntax-done-to)
	    )
	  (if (car err-l) (goto-char (car err-l))
	    (or non-inter
		(message "Scanning for \"hard\" Perl constructions... done"))))
      (and (buffer-modified-p)
	   (not modified)
	   (set-buffer-modified-p nil))
      )
    (list (car err-l) overshoot)))

(defun sane-perl-find-pods-heres-region (min max)
  (interactive "r")
  (sane-perl-find-pods-heres min max))

(defun sane-perl-backward-to-noncomment (lim)
  ;; Stops at lim or after non-whitespace that is not in comment
  ;; XXXX Wrongly understands end-of-multiline strings with # as comment
  (let (stop p pr)
    (while (and (not stop) (> (point) (or lim (point-min))))
      (skip-chars-backward " \t\n\f" lim)
      (setq p (point))
      (beginning-of-line)
      (if (memq (setq pr (get-text-property (point) 'syntax-type))
		'(pod here-doc here-doc-delim))
	  (progn
	    (sane-perl-unwind-to-safe nil)
	    (setq pr (get-text-property (point) 'syntax-type))))
      (or (and (looking-at "^[ \t]*\\(#\\|$\\)")
	       (not (memq pr '(string prestring))))
	  (progn (sane-perl-to-comment-or-eol) (bolp))
	  (progn
	    (skip-chars-backward " \t")
	    (if (< p (point)) (goto-char p))
	    (setq stop t))))))

;; Used only in `sane-perl-calculate-indent'...
(defun sane-perl-block-p ()
  "Point is before ?\\{.  Checks whether it starts a block."
  ;; No save-excursion!  This is more a distinguisher of a block/hash ref...
  (sane-perl-backward-to-noncomment (point-min))
  (or (memq (preceding-char) (append ";){}$@&%\C-@" nil)) ; Or label!  \C-@ at bobp
					; Label may be mixed up with `$blah :'
      (save-excursion (sane-perl-after-label))
      (get-text-property (sane-perl-1- (point)) 'attrib-group)
      (and (memq (char-syntax (preceding-char)) '(?w ?_))
	   (progn
	     (backward-sexp)
	     ;; sub {BLK}, print {BLK} $data, but NOT `bless', `return', `tr', `constant'
	     (or (and (looking-at "[a-zA-Z0-9_:]+[ \t\n\f]*[{#]") ; Method call syntax
		      (not (looking-at "\\(bless\\|return\\|q[wqrx]?\\|tr\\|[smy]\\|constant\\)\\>")))
		 ;; sub bless::foo {}
		 (progn
		   (sane-perl-backward-to-noncomment (point-min))
		   (and (eq (preceding-char) ?b)
			(progn
			  (forward-sexp -1)
			  (looking-at (concat sane-perl--sub-regexp "[ \t\n\f#]"))))))))))

;; What is the difference of (sane-perl-after-block-p lim t) and (sane-perl-block-p)?
;; No save-excursion; condition-case ...  In (sane-perl-block-p) the block
;; may be a part of an in-statement construct, such as
;;   ${something()}, print {FH} $data.
;; Moreover, one takes positive approach (looks for else,grep etc)
;; another negative (looks for bless,tr etc)
(defun sane-perl-after-block-p (lim &optional pre-block)
  "Return true if the preceding } (if PRE-BLOCK, following {) delimits a block.
Would not look before LIM.  Assumes that LIM is a good place to begin a
statement.  The kind of block we treat here is one after which a new
statement would start; thus the block in ${func()} does not count."
  (save-excursion
    (condition-case nil
	(progn
	  (or pre-block (forward-sexp -1))
	  (sane-perl-backward-to-noncomment lim)
	  (or (eq (point) lim)
	      ;; if () {}   // sub f () {}   // sub f :a(') {}
	      (eq (preceding-char) ?\) )
	      ;; label: {}
	      (save-excursion (sane-perl-after-label))
	      ;; sub :attr {}
	      (get-text-property (sane-perl-1- (point)) 'attrib-group)
	      (if (memq (char-syntax (preceding-char)) '(?w ?_)) ; else {}
		  (save-excursion
		    (forward-sexp -1)
		    ;; else {}     but not    else::func {}
		    (or (and (looking-at
			      (concat "\\(" sane-perl--named-block-regexp
			      "\\|\\(else\\|catch\\|try\\|continue\\|grep\\|map\\)\\)\\>"))
			     (not (looking-at "\\(\\sw\\|_\\)+::")))
			;; sub f {}   or package My::Package { }
			(progn
			  (sane-perl-backward-to-noncomment lim)
			  (and (string-match "[[:alpha:]]" (string (preceding-char)))
			       (progn
				 (forward-sexp -1)
				 (looking-at
				  (concat "\\(?:" sane-perl--sub-regexp
					  "\\|" sane-perl--namespace-declare-regexp
					  "\\)[ \t\n\f#]")))))))
		;; What precedes is not word...  XXXX Last statement in sub???
		(sane-perl-after-expr-p lim))))
      (error nil))))

(defun sane-perl-after-expr-p (&optional lim chars test)
  "Return true if the position is good for start of expression.
TEST is the expression to evaluate at the found position.  If absent,
CHARS is a string that contains good characters to have before us (however,
`}' is treated \"smartly\" if it is not in the list)."
  (let ((lim (or lim (point-min)))
	stop p)
    (sane-perl-update-syntaxification (point) (point))
    (save-excursion
      (while (and (not stop) (> (point) lim))
	(skip-chars-backward " \t\n\f" lim)
	(setq p (point))
	(beginning-of-line)
	;;(memq (setq pr (get-text-property (point) 'syntax-type))
	;;      '(pod here-doc here-doc-delim))
	(if (get-text-property (point) 'here-doc-group)
	    (progn
	      (goto-char
	       (sane-perl-beginning-of-property (point) 'here-doc-group))
	      (beginning-of-line 0)))
	(if (get-text-property (point) 'in-pod)
	    (progn
	      (goto-char
	       (sane-perl-beginning-of-property (point) 'in-pod))
	      (beginning-of-line 0)))
	(if (looking-at "^[ \t]*\\(#\\|$\\)") nil ; Only comment, skip
	  ;; Else: last iteration, or a label
	  (sane-perl-to-comment-or-eol)	; Will not move past "." after a format
	  (skip-chars-backward " \t")
	  (if (< p (point)) (goto-char p))
	  (setq p (point))
	  (if (and (eq (preceding-char) ?:)
		   (progn
		     (forward-char -1)
		     (skip-chars-backward " \t\n\f" lim)
		     (memq (char-syntax (preceding-char)) '(?w ?_))))
	      (forward-sexp -1)		; Possibly label.  Skip it
	    (goto-char p)
	    (setq stop t))))
      (or (bobp)			; ???? Needed
	  (eq (point) lim)
	  (looking-at "[ \t]*__\\(END\\|DATA\\)__") ; After this anything goes
	  (progn
	    (if test (eval test)
	      (or (memq (preceding-char) (append (or chars "{;") nil))
		  (and (eq (preceding-char) ?\})
		       (sane-perl-after-block-p lim))
		  (and (eq (following-char) ?.)	; in format: see comment above
		       (eq (get-text-property (point) 'syntax-type)
			   'format)))))))))

(defun sane-perl-backward-to-start-of-expr (&optional lim)
  (condition-case nil
      (progn
	(while (and (or (not lim)
			(> (point) lim))
		    (not (sane-perl-after-expr-p lim)))
	  (forward-sexp -1)
	  ;; May be after $, @, $# etc of a variable
	  (skip-chars-backward "$@%#")))
    (error nil)))

(defun sane-perl-at-end-of-expr (&optional lim)
  ;; Since the SEXP approach below is very fragile, do some overengineering
  (or (looking-at (concat sane-perl-maybe-white-and-comment-rex "[;}]"))
      (condition-case nil
	  (save-excursion
	    ;; If nothing interesting after, does as (forward-sexp -1);
	    ;; otherwise fails, or ends at a start of following sexp.
	    ;; XXXX PROBLEMS: if what follows (after ";") @FOO, or ${bar}
	    ;; may be stuck after @ or $; just put some stupid workaround now:
	    (let ((p (point)))
	      (forward-sexp 1)
	      (forward-sexp -1)
	      (while (memq (preceding-char) (append "%&@$*" nil))
		(forward-char -1))
	      (or (< (point) p)
		  (sane-perl-after-expr-p lim))))
	(error t))))

(defun sane-perl-forward-to-end-of-expr (&optional lim)
  (condition-case nil
      (progn
	(while (and (< (point) (or lim (point-max)))
		    (not (sane-perl-at-end-of-expr)))
	  (forward-sexp 1)))
    (error nil)))

(defun sane-perl-backward-to-start-of-continued-exp (lim)
  (if (memq (preceding-char) (append ")]}\"'`" nil))
      (forward-sexp -1))
  (beginning-of-line)
  (if (<= (point) lim)
      (goto-char (1+ lim)))
  (skip-chars-forward " \t"))

(defun sane-perl-after-block-and-statement-beg (lim)
  ;; We assume that we are after ?\}
  (and
   (sane-perl-after-block-p lim)
   (save-excursion
     (forward-sexp -1)
     (sane-perl-backward-to-noncomment (point-min))
     (or (bobp)
	 (eq (point) lim)
	 (not (= (char-syntax (preceding-char)) ?w))
	 (progn
	   (forward-sexp -1)
	   (not
	    (looking-at
	     "\\(map\\|grep\\|say\\|printf?\\|system\\|exec\\|tr\\|s\\)\\>")))))))


(defun sane-perl-indent-exp ()
  "Simple variant of indentation of continued-sexp.

Will not indent comment if it starts at `comment-indent' or looks like
continuation of the comment on the previous line.

If `sane-perl-indent-region-fix-constructs', will improve spacing on
conditional/loop constructs."
  (interactive)
  (save-excursion
    (let ((tmp-end (line-end-position)) top done)
      (save-excursion
	(beginning-of-line)
	(while (null done)
	  (setq top (point))
	  ;; Plan A: if line has an unfinished paren-group, go to end-of-group
	  (while (= -1 (nth 0 (parse-partial-sexp (point) tmp-end -1)))
	    (setq top (point)))		; Get the outermost parens in line
	  (goto-char top)
	  (while (< (point) tmp-end)
	    (parse-partial-sexp (point) tmp-end nil t) ; To start-sexp or eol
	    (or (eolp) (forward-sexp 1)))
	  (if (> (point) tmp-end)	; Check for an unfinished block
	      nil
	    (if (eq ?\) (preceding-char))
		;; closing parens can be preceded by up to three sexps
		(progn ;; Plan B: find by REGEXP block followup this line
		  (setq top (point))
		  (condition-case nil
		      (progn
			(forward-sexp -2)
			(if (eq (following-char) ?$ ) ; for my $var (list)
			    (progn
			      (forward-sexp -1)
			      (if (looking-at (concat sane-perl--declaring-regexp "\\>"))
				  (forward-sexp -1))))
			(if (looking-at
			     (concat "\\(?:" sane-perl--block-init-regexp
				     "\\|elsif" ;; elsif starts a new block
				     "\\>\\(\\("
				     sane-perl-maybe-white-and-comment-rex
				     sane-perl--declaring-regexp
				     "\\)?"
				     sane-perl-maybe-white-and-comment-rex
				     "\\$[_a-zA-Z0-9]+\\)?\\)\\>"))
			    (progn
			      (goto-char top)
			      (forward-sexp 1)
			      (setq top (point)))
			  ;; no block to be processed: expression ends here
			  (setq done t)))
		    (error (setq done t)))
		  (goto-char top))
	      (if (looking-at		; Try Plan C: continuation block
		   (concat sane-perl-maybe-white-and-comment-rex
			   "\\<\\(else\\|elsif\\|continue\\)\\>"))
		  (progn
		    (goto-char (match-end 0))
		    (setq tmp-end (line-end-position)))
		(setq done t))))
	  (setq tmp-end (line-end-position)))
	(goto-char tmp-end)
	(setq tmp-end (point-marker)))
      (if sane-perl-indent-region-fix-constructs
	  (sane-perl-fix-line-spacing tmp-end))
      (sane-perl-indent-region (point) tmp-end))))

(defun sane-perl-fix-line-spacing (&optional end parse-data)
  "Improve whitespace in a conditional/loop construct.
Returns some position at the last line."
  (interactive)
  (or end
      (setq end (point-max)))
  (let ((ee (line-end-position))
	(sane-perl-indent-region-fix-constructs
	 (or sane-perl-indent-region-fix-constructs 1))
	p pp ml have-brace ret)
    (save-excursion
      (beginning-of-line)
      (setq ret (point))
      ;;  }? continue
      ;;  blah; }
      (if (not
           (or (looking-at
                (concat "[ \t]*" sane-perl--block-regexp "\\>"))
               (setq have-brace (save-excursion (search-forward "}" ee t)))))
          nil                           ; Do not need to do anything
        ;; Looking at:
        ;; }
        ;; else
        (if sane-perl-merge-trailing-else
            (if (looking-at
                 (concat "[ \t]*}[ \t]*\n[ \t\n]*"
                         sane-perl--block-continuation-regexp "\\>"))
                (progn
                  (search-forward "}")
                  (setq p (point))
                  (skip-chars-forward " \t\n")
                  (delete-region p (point))
              (insert (make-string sane-perl-indent-region-fix-constructs ?\s))
                  (beginning-of-line)))
          (if (looking-at
               (concat "[ \t]*}[ \t]*"
                       sane-perl--block-continuation-regexp "\\>"))
              (save-excursion
                  (search-forward "}")
                  (delete-horizontal-space)
                  (insert "\n")
                  (setq ret (point))
                  (if (sane-perl-indent-line parse-data)
                      (progn
                        (sane-perl-fix-line-spacing end parse-data)
                        (setq ret (point)))))))
        ;; Looking at:
        ;; }     else
        (if (looking-at
             (concat "[ \t]*}\\(\t*\\|[ \t][ \t]+\\)\\<"
                     sane-perl--block-continuation-regexp "\\>"))
            (progn
              (search-forward "}")
              (delete-horizontal-space)
              (insert (make-string sane-perl-indent-region-fix-constructs ?\s))
              (beginning-of-line)))
        ;; Looking at:
        ;; else   {
            (if (looking-at
                 (concat "[ \t]*}?[ \t]*\\<"
                         sane-perl--block-regexp
                         "\\>\\(\t*\\|[ \t][ \t]+\\)[^ \t\n#]"))
            (progn
              (forward-word-strictly 1)
              (delete-horizontal-space)
              (insert (make-string sane-perl-indent-region-fix-constructs ?\s))
              (beginning-of-line)))
        ;; Looking at:
        ;; foreach my    $var
          (if (looking-at
               (concat "[ \t]*\\<for\\(each\\)?[ \t]+"
                       sane-perl--declaring-regexp
                       "\\(\t*\\|[ \t][ \t]+\\)[^ \t\n]"))
            (progn
              (forward-word-strictly 2)
              (delete-horizontal-space)
              (insert (make-string sane-perl-indent-region-fix-constructs ?\s))
              (beginning-of-line)))
        ;; Looking at:
        ;; foreach my $var     (
          (if (looking-at
               (concat  "[ \t]*\\<for\\(each\\)?[ \t]+"
                        sane-perl--declaring-regexp
                        "[ \t]*\\$[_a-zA-Z0-9]+\\(\t*\\|[ \t][ \t]+\\)[^ \t\n#]"))
            (progn
              (forward-sexp 3)
              (delete-horizontal-space)
              (insert
               (make-string sane-perl-indent-region-fix-constructs ?\s))
              (beginning-of-line)))
        ;; Looking at (with or without "}" at start, ending after "({"):
        ;; } foreach my $var ()         OR   {
          (if (looking-at
               (concat "[ \t]*\\(}[ \t]*\\)?\\<"
                       sane-perl--block-regexp
                       "\\(\\([ \t]+"
                       sane-perl--declaring-regexp
                       "\\)?[ \t]*\\$[_a-zA-Z0-9]+\\)?\\>\\([ \t]*(\\|[ \t\n]*{\\)\\|[ \t]*{"))
              (progn
              (setq ml (match-beginning 4)) ; "(" or "{" after control word
              (re-search-forward "[({]")
              (forward-char -1)
              (setq p (point))
              (if (eq (following-char) ?\( )
                  (progn
                    (forward-sexp 1)
                    (setq pp (point)))  ; past parenthesis-group
                ;; after `else' or nothing
                (if ml                  ; after `else'
                    (skip-chars-backward " \t\n")
                  (beginning-of-line))
                (setq pp nil))
              ;; Now after the sexp before the brace
              ;; Multiline expr should be special
              (setq ml (and pp (save-excursion (goto-char p)
                                               (search-forward "\n" pp t))))
              (if (and (or (not pp) (< pp end))         ; Do not go too far...
                       (looking-at "[ \t\n]*{"))
                  (progn
                    (cond
                     ((bolp)            ; Were before `{', no if/else/etc
                      nil)
                     ((looking-at "\\(\t*\\| [ \t]+\\){") ; Not exactly 1 SPACE
                      (delete-horizontal-space)
                      (if (if ml
                              sane-perl-extra-newline-before-brace-multiline
                            sane-perl-extra-newline-before-brace)
                          (progn
                            (delete-horizontal-space)
                            (insert "\n")
                            (setq ret (point))
                            (if (sane-perl-indent-line parse-data)
                                (progn
                                  (sane-perl-fix-line-spacing end parse-data)
                                  (setq ret (point)))))
                        (insert
                         (make-string sane-perl-indent-region-fix-constructs ?\s))))
                     ((and (looking-at "[ \t]*\n")
                           (not (if ml
                                    sane-perl-extra-newline-before-brace-multiline
                                  sane-perl-extra-newline-before-brace)))
                      (setq pp (point))
                      (skip-chars-forward " \t\n")
                      (delete-region pp (point))
                      (insert
                       (make-string sane-perl-indent-region-fix-constructs ?\ )))
                     ((and (looking-at "[\t ]*{")
                           (if ml sane-perl-extra-newline-before-brace-multiline
                             sane-perl-extra-newline-before-brace))
                      (delete-horizontal-space)
                      (insert "\n")
                      (setq ret (point))
                      (if (sane-perl-indent-line parse-data)
                          (progn
                            (sane-perl-fix-line-spacing end parse-data)
                            (setq ret (point))))))
                    ;; Now we are before `{'
                    (if (looking-at "[ \t\n]*{[ \t]*[^ \t\n#]")
                        (progn
                          (skip-chars-forward " \t\n")
                          (setq pp (point))
                          (forward-sexp 1)
                          (setq p (point))
                          (goto-char pp)
                          (setq ml (search-forward "\n" p t))
                          (if (or sane-perl-break-one-line-blocks-when-indent ml)
                              ;; not good: multi-line BLOCK
                              (progn
                                (goto-char (1+ pp))
                                (delete-horizontal-space)
                                (insert "\n")
                                (setq ret (point))
                                (if (sane-perl-indent-line parse-data)
                                    (setq ret (sane-perl-fix-line-spacing end parse-data)))))))))))
        (beginning-of-line)
        (setq p (point) pp (line-end-position)) ; May be different from ee.
        ;; Now check whether there is a hanging `}'
        ;; Looking at:
        ;; } blah
        (if (and
             sane-perl-fix-hanging-brace-when-indent
             have-brace
             (not (looking-at
                   (concat "[ \t]*}[ \t]*\\(\\<"
                           sane-perl--block-continuation-regexp
                           "\\>\\|$\\|#\\)")))
             (condition-case nil
                 (progn
                   (up-list 1)
                   (if (and (<= (point) pp)
                            (eq (preceding-char) ?\} )
                            (sane-perl-after-block-and-statement-beg (point-min)))
                       t
                     (goto-char p)
                     nil))
               (error nil)))
            (progn
              (forward-char -1)
              (skip-chars-backward " \t")
              (if (bolp)
                  ;; `}' was the first thing on the line, insert NL *after* it.
                  (progn
                    (sane-perl-indent-line parse-data)
                    (search-forward "}")
		    ;; This solves the problem of "};" turning into "}\n;"
		    (if (not (eq (following-char) ?\;))
			(progn
			  (delete-horizontal-space)
			  (insert "\n"))
		      ;; If we don't move the point beyond the };, it
		      ;; recurses endlessly. The following line stops
		      ;; that, but it doesn't seem the right thing to
		      ;; do.
		      (forward-char 2)))
                (delete-horizontal-space)
                (or (eq (preceding-char) ?\;)
                    (bolp)
                    (and (eq (preceding-char) ?\} )
                         (sane-perl-after-block-p (point-min)))
                    (insert ";"))
                (insert "\n")
                (setq ret (point)))
              (if (sane-perl-indent-line parse-data)
                  (setq ret (sane-perl-fix-line-spacing end parse-data)))
              (beginning-of-line)))))
    ret))

(defvar sane-perl-update-start)		; Do not need to make them local
(defvar sane-perl-update-end)
(defun sane-perl-delay-update-hook (beg end _old-len)
  (setq sane-perl-update-start (min beg (or sane-perl-update-start (point-max))))
  (setq sane-perl-update-end (max end (or sane-perl-update-end (point-min)))))

(defun sane-perl-indent-region (start end)
  "Indentation of region in Sane-Perl mode.
Will not indent comment if it starts at `comment-indent'
or looks like continuation of the comment on the previous line.
Indents all the lines whose first character is between START and END
inclusive.

If `sane-perl-indent-region-fix-constructs', will improve spacing on
conditional/loop constructs."
  (interactive "r")
  (sane-perl-update-syntaxification end end)
  (save-excursion
    (let (sane-perl-update-start sane-perl-update-end (h-a-c after-change-functions))
      (let ((indent-info (list nil nil nil)	; Cannot use '(), since will modify
			 )
	    after-change-functions	; Speed it up!
	    comm old-comm-indent new-comm-indent i empty)
	(if h-a-c (add-hook 'after-change-functions #'sane-perl-delay-update-hook))
	(goto-char start)
	(setq old-comm-indent (and (sane-perl-to-comment-or-eol)
				   (current-column))
	      new-comm-indent old-comm-indent)
	(goto-char start)
	(setq end (set-marker (make-marker) end)) ; indentation changes pos
	(or (bolp) (beginning-of-line 2))
	(while (and (<= (point) end) (not (eobp))) ; bol to check start
	  (if (or
	       (setq empty (looking-at "[ \t]*\n"))
	       (and (setq comm (looking-at "[ \t]*#"))
		    (or (eq (current-indentation) (or old-comm-indent
						      comment-column))
			(setq old-comm-indent nil))))
	      (if (and old-comm-indent
		       (not empty)
		       (= (current-indentation) old-comm-indent)
		       (not (eq (get-text-property (point) 'syntax-type) 'pod))
		       (not (eq (get-text-property (point) 'syntax-table)
				sane-perl-st-cfence)))
		  (let ((comment-column new-comm-indent))
		    (indent-for-comment)))
	    (progn
	      (setq i (sane-perl-indent-line indent-info))
	      (or comm
		  (not i)
		  (progn
		    (if sane-perl-indent-region-fix-constructs
			(goto-char (sane-perl-fix-line-spacing end indent-info)))
		    (if (setq old-comm-indent
			      (and (sane-perl-to-comment-or-eol)
				   (not (memq (get-text-property (point)
								 'syntax-type)
					      '(pod here-doc)))
				   (not (eq (get-text-property (point)
							       'syntax-table)
					    sane-perl-st-cfence))
				   (current-column)))
			(progn (indent-for-comment)
			       (skip-chars-backward " \t")
			       (skip-chars-backward "#")
			       (setq new-comm-indent (current-column))))))))
	  (beginning-of-line 2)))
      ;; Now run the update hooks
      (and after-change-functions
	   sane-perl-update-end
	   (save-excursion
	     (goto-char sane-perl-update-end)
	     (insert " ")
	     (delete-char -1)
	     (goto-char sane-perl-update-start)
	     (insert " ")
	     (delete-char -1))))))

;; Stolen from lisp-mode with a lot of improvements

(defun sane-perl-fill-paragraph (&optional justify iteration)
  "Like `fill-paragraph', but handle Perl comments.
If any of the current line is a comment, fill the comment or the
block of it that point is in, preserving the comment's initial
indentation and initial hashes.  Behaves usually outside of comment."
  (let (;; Non-nil if the current line contains a comment.
	has-comment
	fill-paragraph-function		; do not recurse
	;; If has-comment, the appropriate fill-prefix for the comment.
	comment-fill-prefix
	;; Line that contains code and comment (or nil)
	start
	c spaces len dc (comment-column comment-column))
    ;; Figure out what kind of comment we are looking at.
    (save-excursion
      (beginning-of-line)
      (cond

       ;; A line with nothing but a comment on it?
       ((looking-at "[ \t]*#[# \t]*")
	(setq has-comment t
	      comment-fill-prefix (buffer-substring (match-beginning 0)
						    (match-end 0))))

       ;; A line with some code, followed by a comment?  Remember that the
       ;; semi which starts the comment shouldn't be part of a string or
       ;; character.
       ((sane-perl-to-comment-or-eol)
	(setq has-comment t)
	(looking-at "#+[ \t]*")
	(setq start (point) c (current-column)
	      comment-fill-prefix
	      (concat (make-string (current-column) ?\s)
		      (buffer-substring (match-beginning 0) (match-end 0)))
	      spaces (progn (skip-chars-backward " \t")
			    (buffer-substring (point) start))
	      dc (- c (current-column)) len (- start (point))
	      start (point-marker))
	(delete-char len)
	(insert (make-string dc ?-)))))	; Placeholder (to avoid splitting???)
    (if (not has-comment)
	(fill-paragraph justify)       ; Do the usual thing outside of comment
      ;; Narrow to include only the comment, and then fill the region.
      (save-restriction
	(narrow-to-region
	 ;; Find the first line we should include in the region to fill.
	 (if start (progn (beginning-of-line) (point))
	   (save-excursion
	     (while (and (zerop (forward-line -1))
			 (looking-at "^[ \t]*#+[ \t]*[^ \t\n#]")))
	     ;; We may have gone to far.  Go forward again.
	     (or (looking-at "^[ \t]*#+[ \t]*[^ \t\n#]")
		 (forward-line 1))
	     (point)))
	 ;; Find the beginning of the first line past the region to fill.
	 (save-excursion
	   (while (progn (forward-line 1)
			 (looking-at "^[ \t]*#+[ \t]*[^ \t\n#]")))
	   (point)))
	;; Remove existing hashes
	(goto-char (point-min))
	(save-excursion
	  (while (progn (forward-line 1) (< (point) (point-max)))
	    (skip-chars-forward " \t")
	    (if (looking-at "#+")
		(progn
		  (if (and (eq (point) (match-beginning 0))
			   (not (eq (point) (match-end 0)))) nil
		    (error
 "Bug in Emacs: `looking-at' in `narrow-to-region': match-data is garbage"))
		(delete-char (- (match-end 0) (match-beginning 0)))))))

	;; Lines with only hashes on them can be paragraph boundaries.
	(let ((paragraph-start (concat paragraph-start "\\|^[ \t#]*$"))
	      (paragraph-separate (concat paragraph-start "\\|^[ \t#]*$"))
	      (fill-prefix comment-fill-prefix))
	  (fill-paragraph justify)))
      (if (and start)
	  (progn
	    (goto-char start)
	    (if (> dc 0)
		(progn (delete-char dc) (insert spaces)))
	    (if (or (= (current-column) c) iteration) nil
	      (setq comment-column c)
	      (indent-for-comment)
	      ;; Repeat once more, flagging as iteration
	      (sane-perl-fill-paragraph justify t))))))
  t)

(defun sane-perl-do-auto-fill ()
  ;; Break out if the line is short enough
  (if (> (save-excursion
	   (end-of-line)
	   (current-column))
	 fill-column)
      (let ((c (save-excursion (beginning-of-line)
			       (sane-perl-to-comment-or-eol) (point)))
	    (s (memq (following-char) '(?\s ?\t))) marker)
	(if (>= c (point))
	    ;; Don't break line inside code: only inside comment.
	    nil
	  (setq marker (point-marker))
	  (fill-paragraph nil)
	  (goto-char marker)
	  ;; Is not enough, sometimes marker is a start of line
	  (if (bolp) (progn (re-search-forward "#+[ \t]*")
			    (goto-char (match-end 0))))
	  ;; Following space could have gone:
	  (if (or (not s) (memq (following-char) '(?\s ?\t))) nil
	    (insert " ")
	    (backward-char 1))
	  ;; Previous space could have gone:
	  (or (memq (preceding-char) '(?\s ?\t)) (insert " "))))))

;;; imenu functions
(defvar sane-perl-imenu-addback)
(defun sane-perl-imenu-addback (lst &optional isback name)
  ;; We suppose that the lst is a DAG, unless the first element only
  ;; loops back, and ISBACK is set.  Thus this function cannot be
  ;; applied twice without ISBACK set.
  (cond ((not sane-perl-imenu-addback) lst)
	(t
	 (or name
	     (setq name "+++BACK+++"))
	 (mapc (lambda (elt)
		 (if (and (listp elt) (listp (cdr elt)))
		     (progn
		       ;; In the other order it goes up
		       ;; one level only ;-(
		       (setcdr elt (cons (cons name lst)
					 (cdr elt)))
		       (sane-perl-imenu-addback (cdr elt) t name))))
	       (if isback (cdr lst) lst))
	 lst)))

(defun sane-perl-imenu--create-perl-index (&optional regexp)
  (require 'imenu)			; May be called from TAGS creator
  (let ((index-alist '()) (index-pack-alist '()) (index-pod-alist '())
	(index-unsorted-alist '())
	(index-meth-alist '()) meth
	packages ends-ranges p marker is-proto
        is-pack index index1 name (end-range 0) package)
    (goto-char (point-min))
    (sane-perl-update-syntaxification (point-max) (point-max))
    ;; Search for the function
    (progn ;;save-match-data
      (while (re-search-forward
	      (or regexp sane-perl-imenu--function-name-regexp-perl)
	      nil t)
	;; 2=package-group, 5=package-name 8=sub-name
	(cond
	 ((and				; Skip some noise if building tags
	   (match-beginning 5)		; package name
	   ;;(eq (char-after (match-beginning 2)) ?p) ; package
	   (not (save-match-data
		  (looking-at "[ \t\n]*[;{]")))) ; Plain text word 'package'
	  nil)
	 ((and
	   (or (match-beginning 2)
	       (match-beginning 8))		; package or sub
	   ;; Skip if quoted (will not skip multi-line ''-strings :-():
	   (null (get-text-property (match-beginning 1) 'syntax-table))
	   (null (get-text-property (match-beginning 1) 'syntax-type))
	   (null (get-text-property (match-beginning 1) 'in-pod)))
	  (setq is-pack (match-beginning 2))
	  (setq meth nil
		p (point))
	  (while (and ends-ranges (>= p (car ends-ranges)))
	    ;; delete obsolete entries
	    (setq ends-ranges (cdr ends-ranges) packages (cdr packages)))
	  (setq package (or (car packages) "")
		end-range (or (car ends-ranges) 0))
	  (if is-pack			; doing "package"
	      (progn
		(if (match-beginning 5)	; named package
		    (setq name (buffer-substring (match-beginning 5)
						 (match-end 5))
			  name (progn
				 (set-text-properties 0 (length name) nil name)
				 name)
			  package (concat name "::")
			  name (concat "package " name))
		  ;; Support nameless packages
		  (setq name "package;" package ""))
		(setq end-range
		      (save-excursion
			(parse-partial-sexp (point) (point-max) -1) (point))
		      ends-ranges (cons end-range ends-ranges)
		      packages (cons package packages)))
	    (setq is-proto
		  (or (eq (following-char) ?\;)
		      (eq 0 (get-text-property (point) 'attrib-group)))))
	  ;; Skip this function name if it is a prototype declaration.
	  (if (and is-proto (not is-pack)) nil
	    (or is-pack
		(setq name
		      (buffer-substring (match-beginning 8) (match-end 8)))
		(set-text-properties 0 (length name) nil name))
	    (setq marker (make-marker))
	    (set-marker marker (match-end (if is-pack 2 8)))
	    (cond (is-pack nil)
		  ((string-match "[:']" name)
		   (setq meth t))
		  ((> p end-range) nil)
		  (t
		   (setq name (concat package name) meth t)))
	    (setq index (cons name marker))
	    (if is-pack
		(push index index-pack-alist)
	      (push index index-alist))
	    (if meth (push index index-meth-alist))
	    (push index index-unsorted-alist)))
	 ((match-beginning 16)		; POD section
	  (setq name (buffer-substring (match-beginning 17) (match-end 17))
		marker (make-marker))
	  (set-marker marker (match-beginning 17))
	  (set-text-properties 0 (length name) nil name)
	  (setq name (concat (make-string
			      (* 3 (- (char-after (match-beginning 16)) ?1))
			      ?\ )
			     name)
		index (cons name marker))
	  (setq index1 (cons (concat "=" name) (cdr index)))
	  (push index index-pod-alist)
	  (push index1 index-unsorted-alist)))))
    (setq index-alist
	  (if (default-value 'imenu-sort-function)
	      (sort index-alist (default-value 'imenu-sort-function))
	    (nreverse index-alist)))
    (and index-pod-alist
	 (push (cons "+POD headers+..."
		     (nreverse index-pod-alist))
	       index-alist))
    (and (or index-pack-alist index-meth-alist)
	 (let ((lst index-pack-alist) hier-list pack elt group name)
	   ;; Remove "package ", reverse and uniquify.
	   (while lst
	     (setq elt (car lst) lst (cdr lst) name (substring (car elt) 8))
	     (if (assoc name hier-list) nil
	       (setq hier-list (cons (cons name (cdr elt)) hier-list))))
	   (setq lst index-meth-alist)
	   (while lst
	     (setq elt (car lst) lst (cdr lst))
	     (cond ((string-match "\\(::\\|'\\)[_a-zA-Z0-9]+$" (car elt))
		    (setq pack (substring (car elt) 0 (match-beginning 0)))
		    (if (setq group (assoc pack hier-list))
			(if (listp (cdr group))
			    ;; Have some functions already
			    (setcdr group
				    (cons (cons (substring
						 (car elt)
						 (+ 2 (match-beginning 0)))
						(cdr elt))
					  (cdr group)))
			  (setcdr group (list (cons (substring
						     (car elt)
						     (+ 2 (match-beginning 0)))
						    (cdr elt)))))
		      (setq hier-list
			    (cons (cons pack
					(list (cons (substring
						     (car elt)
						     (+ 2 (match-beginning 0)))
						    (cdr elt))))
				  hier-list))))))
	   (push (cons "+Hierarchy+..."
		       hier-list)
		 index-alist)))
    (and index-pack-alist
	 (push (cons "+Packages+..."
		     (nreverse index-pack-alist))
	       index-alist))
    (and (or index-pack-alist index-pod-alist
	     (default-value 'imenu-sort-function))
	 index-unsorted-alist
	 (push (cons "+Unsorted List+..."
		     (nreverse index-unsorted-alist))
	       index-alist))
    (sane-perl-imenu-addback index-alist)))


;; Suggested by Mark A. Hershberger
(defun sane-perl-outline-level ()
  (looking-at outline-regexp)
  (cond ((not (match-beginning 1)) 0)	; beginning-of-file
        ;; 2=package-group, 5=package-name 8=sub-name 16=head-level
	((match-beginning 2) 0)		; package
	((match-beginning 8) 1)		; sub
	((match-beginning 16)
	 (- (char-after (match-beginning 16)) ?0)) ; headN ==> N
	(t 5)))				; should not happen


(defun sane-perl-windowed-init ()
  "Initialization under windowed version."
  (cond ((featurep 'ps-print)
	 (or sane-perl-faces-init (sane-perl-init-faces)))
	((not sane-perl-faces-init)
	 (add-hook 'font-lock-mode-hook
		   (lambda ()
		     (if (memq major-mode '(perl-mode sane-perl-mode))
			 (progn
			   (or sane-perl-faces-init (sane-perl-init-faces))))))
	 (eval-after-load
	     "ps-print"
	   '(or sane-perl-faces-init (sane-perl-init-faces))))))

(defvar sane-perl-font-lock-keywords-1 nil
  "Additional expressions to highlight in Perl mode.  Minimal set.")
(defvar sane-perl-font-lock-keywords nil
  "Additional expressions to highlight in Perl mode.  Default set.")
(defvar sane-perl-font-lock-keywords-2 nil
  "Additional expressions to highlight in Perl mode.  Maximal set")
(make-variable-buffer-local 'sane-perl-font-lock-keywords)
(make-variable-buffer-local 'sane-perl-font-lock-keywords-1)
(make-variable-buffer-local 'sane-perl-font-lock-keywords-2)

(defun sane-perl-load-font-lock-keywords ()
  (or sane-perl-faces-init (sane-perl-init-faces))
  sane-perl-font-lock-keywords)

(defun sane-perl-load-font-lock-keywords-1 ()
  (or sane-perl-faces-init (sane-perl-init-faces))
  sane-perl-font-lock-keywords-1)

(defun sane-perl-load-font-lock-keywords-2 ()
  (or sane-perl-faces-init (sane-perl-init-faces))
  sane-perl-font-lock-keywords-2)

(defun sane-perl-init-faces ()
  (condition-case errs
      (progn
	(let (t-font-lock-keywords t-font-lock-keywords-1)
	  (setq
	   t-font-lock-keywords
	   (list
	    `("[ \t]+$" 0 ',sane-perl-invalid-face t)
	    (cons
	     (concat
	      "\\(?:^\\|[^$@%&\\]\\)\\<\\("
	      sane-perl--flow-control-regexp
	      "\\)\\>") 1)	      ; was "\\)[ \n\t;():,|&]"
					; In what follows we use `type' style
					; for overwritable builtins
	    (list
	     (concat
	      "\\(?:^\\|[^$@%&\\]\\)\\<\\("
	      sane-perl--functions-regexp
	      "\\)\\>")
	     1 'font-lock-type-face)
	    ;; In what follows we use `other' style
	    ;; for nonoverwritable builtins
	    (list
	     (concat
	      "\\(?:^\\|[^$@%&\\]\\)\\<\\("
	      sane-perl--nonoverridable-regexp
	      "\\)\\>")
	     1 ''sane-perl-nonoverridable-face)
	    '("-[rwxoRWXOezsfdlpSbctugkTBMAC]\\>\\([ \t]+_\\>\\)?" 0
	      font-lock-function-name-face keep) ; Not very good, triggers at "[a-z]"
	    ;; This highlights declarations and definitions differently.
	    ;; We do not try to highlight in the case of attributes:
	    ;; it is already done by `sane-perl-find-pods-heres'
	    (list (concat "\\<" sane-perl--sub-regexp
			  sane-perl-white-and-comment-rex ; whitespace/comments
			  "\\([^ \n\t{;()]+\\)" ; 2=name (assume non-anonymous)
			  "\\("
			    sane-perl-maybe-white-and-comment-rex ;whitespace/comments?
			    "([^()]*)\\)?" ; prototype
			  sane-perl-maybe-white-and-comment-rex ; whitespace/comments?
			  "[{;]")
		  2 '(if (eq (char-after (sane-perl-1- (match-end 0))) ?\{ )
			 'font-lock-function-name-face
		       'font-lock-variable-name-face))
	    (list (concat "\\<" sane-perl--namespace-regexp
			  "[ \t]+\\([a-zA-Z_][a-zA-Z_0-9:]*\\)[ \t;]")
		  1 font-lock-function-name-face) ; require A if B;
	    '("^[ \t]*format[ \t]+\\([a-zA-Z_][a-zA-Z_0-9:]*\\)[ \t]*=[ \t]*$"
	      1 font-lock-function-name-face)
	    '("\\([]}\\%@>*&]\\|\\$[a-zA-Z0-9_:]*\\)[ \t]*{[ \t]*\\(-?[a-zA-Z0-9_:]+\\)[ \t]*}"
	      (2 font-lock-string-face t)
	      ("\\=[ \t]*{[ \t]*\\(-?[a-zA-Z0-9_:]+\\)[ \t]*}"
	       nil nil
	       (1 font-lock-string-face t)))
	    '("[[ \t{,(]\\(-?[a-zA-Z0-9_:]+\\)[ \t]*=>" 1
	      font-lock-string-face t)
	    (list (concat "^[ \t]*\\([a-zA-Z0-9_]+[ \t]*:\\)[ \t]*\\($\\|{\\|\\<"
			  sane-perl--after-label-regexp "\\>\\)")
		  1 font-lock-constant-face)  ; labels
	    (list (concat "\\<" sane-perl--before-label-regexp
			  "\\>[ \t]+\\([a-zA-Z0-9_:]+\\)")
		  1 font-lock-constant-face) ; labels as targets
	    `(,(concat "\\<" sane-perl--declaring-regexp
		       sane-perl-maybe-white-and-comment-rex
		       "\\(("
		       sane-perl-maybe-white-and-comment-rex
		       "\\)?\\([$@%*]\\([a-zA-Z0-9_:]+\\|[^a-zA-Z0-9_]\\)\\)")
	      (4 'font-lock-variable-name-face)
	      (,(concat "\\="
			sane-perl-maybe-white-and-comment-rex
			","
			sane-perl-maybe-white-and-comment-rex
			"\\([$@%*]\\([a-zA-Z0-9_:]+\\|[^a-zA-Z0-9_]\\)\\)")
	       ;; Bug in font-lock: limit is used not only to limit
	       ;; searches, but to set the "extend window for
	       ;; facification" property.  Thus we need to minimize.
	       '(if (match-beginning 2)
		    (save-excursion
		      (goto-char (match-beginning 2))
		      (condition-case nil
			  (forward-sexp 1)
			(error
			 (condition-case nil
			     (forward-char 200)
			   (error nil)))) ; typeahead
		      (1- (point))) ; report limit
		  (forward-char -2)) ; disable continued expr
	       nil
	       (3 font-lock-variable-name-face)))
	    `(,(concat "\\<for\\(each\\)?\\([ \t]+" sane-perl--declaring-regexp
		       "\\)?[ \t]*\\(\\$[a-zA-Z_][a-zA-Z_0-9]*\\)[ \t]*(")
	      3 font-lock-variable-name-face)
	    ;; Avoid $!, and s!!, qq!! etc. when not fontifying syntactically
	    '("\\(?:^\\|[^smywqrx$]\\)\\(!\\)" 1 font-lock-negation-char-face)
	    '("\\[\\(\\^\\)" 1 font-lock-negation-char-face prepend)))
	  (setq
	   t-font-lock-keywords-1
	   '(
	     ("\\(\\([@%]\\|\\$#\\)[a-zA-Z_:][a-zA-Z0-9_:]*\\)" 1
	      (if (eq (char-after (match-beginning 2)) ?%)
		  'sane-perl-hash-face
		'sane-perl-array-face)
	      nil)			; arrays and hashes
	     ("\\(\\([$@]+\\)[a-zA-Z_:][a-zA-Z0-9_:]*\\)[ \t]*\\([[{]\\)"
	      1
	      (if (= (- (match-end 2) (match-beginning 2)) 1)
		  (if (eq (char-after (match-beginning 3)) ?{)
		      'sane-perl-hash-face
		    'sane-perl-array-face)             ; arrays and hashes
		font-lock-variable-name-face)      ; Just to put something
	      t)
	     ("\\(@\\|\\$#\\)\\(\\$+\\([a-zA-Z_:][a-zA-Z0-9_:]*\\|[^ \t\n]\\)\\)"
	      (1 'sane-perl-array-face)
	      (2 font-lock-variable-name-face))
	     ("\\(%\\)\\(\\$+\\([a-zA-Z_:][a-zA-Z0-9_:]*\\|[^ \t\n]\\)\\)"
	      (1 'sane-perl-hash-face)
	      (2 font-lock-variable-name-face))
	     ))
	  (if sane-perl-highlight-variables-indiscriminately
	      (setq t-font-lock-keywords-1
		    (append t-font-lock-keywords-1
			    (list '("\\([$*]{?\\(?:\\sw+\\|::\\)+\\)" 1
				    font-lock-variable-name-face)))))
	  (setq sane-perl-font-lock-keywords-1
		(if sane-perl-syntaxify-by-font-lock
		    (cons 'sane-perl-fontify-update
			  t-font-lock-keywords)
		  t-font-lock-keywords)
		sane-perl-font-lock-keywords sane-perl-font-lock-keywords-1
		sane-perl-font-lock-keywords-2 (append
					   t-font-lock-keywords-1
					   sane-perl-font-lock-keywords-1)))
	(if (fboundp 'ps-print-buffer) (sane-perl-ps-print-init))
        (setq sane-perl-faces-init t))
    (error (message "sane-perl-init-faces (ignored): %s" errs))))


(defvar ps-bold-faces)
(defvar ps-italic-faces)
(defvar ps-underlined-faces)

(defun sane-perl-ps-print-init ()
  "Initialization of `ps-print' components for faces used in Sane-Perl."
  (eval-after-load "ps-print"
    '(setq ps-bold-faces
	   ;; 			font-lock-variable-name-face
	   ;;			font-lock-constant-face
	   (append '(sane-perl-array-face sane-perl-hash-face)
		   ps-bold-faces)
	   ps-italic-faces
	   ;;			font-lock-constant-face
	   (append '(sane-perl-nonoverridable-face sane-perl-hash-face)
		   ps-italic-faces)
	   ps-underlined-faces
	   ;;	     font-lock-type-face
	   (append '(sane-perl-array-face sane-perl-hash-face underline sane-perl-nonoverridable-face)
		   ps-underlined-faces))))

(defvar ps-print-face-extension-alist)

(defun sane-perl-ps-print (&optional file)
  "Pretty-print in Sane-Perl style.
If optional argument FILE is an empty string, prints to printer, otherwise
to the file FILE.  If FILE is nil, prompts for a file name.

Style of printout regulated by the variable `sane-perl-ps-print-face-properties'."
  (interactive)
  (or file
      (setq file (read-from-minibuffer
		  "Print to file (if empty - to printer): "
		  (concat (buffer-file-name) ".ps")
		  nil nil 'file-name-history)))
  (or (> (length file) 0)
      (setq file nil))
  (require 'ps-print)			; To get ps-print-face-extension-alist
  (let ((ps-print-color-p t)
	(ps-print-face-extension-alist ps-print-face-extension-alist))
    (ps-extend-face-list sane-perl-ps-print-face-properties)
    (ps-print-buffer-with-faces file)))

(sane-perl-windowed-init)

(defconst sane-perl-styles-entries
  '(sane-perl-indent-level
    sane-perl-brace-offset
    sane-perl-continued-brace-offset
    sane-perl-label-offset
    sane-perl-extra-newline-before-brace
    sane-perl-extra-newline-before-brace-multiline
    sane-perl-merge-trailing-else
    sane-perl-continued-statement-offset))

(defconst sane-perl-style-examples
"##### Numbers etc are: sane-perl-indent-level sane-perl-brace-offset
##### sane-perl-continued-brace-offset sane-perl-label-offset
##### sane-perl-continued-statement-offset
##### sane-perl-merge-trailing-else sane-perl-extra-newline-before-brace

########### (Do not forget sane-perl-extra-newline-before-brace-multiline)

### Sane-Perl	(=GNU - extra-newline-before-brace + merge-trailing-else) 2/0/0/-2/2/t/nil
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

### PBP (=Perl Best Practices)				4/0/0/-4/4/nil/nil
if (foo) {
    bar
	baz;
  label:
    {
	boon;
    }
}
else {
    stop;
}

### PerlStyle	(=Sane-Perl with 4 as indent)		4/0/0/-2/4/t/nil
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

### GNU							2/0/0/-2/2/nil/t
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

### C++		(=PerlStyle with braces aligned with control words) 4/0/-4/-4/4/nil/t
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

### BSD		(=C++, but will not change preexisting merge-trailing-else
###		 and extra-newline-before-brace )		4/0/-4/-4/4
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

### K&R		(=C++ with indent 5 - merge-trailing-else, but will not
###		 change preexisting extra-newline-before-brace)	5/0/-5/-5/5/nil
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

### Whitesmith	(=PerlStyle, but will not change preexisting
###		 extra-newline-before-brace and merge-trailing-else) 4/0/0/-4/4
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
"
"Examples of if/else with different indent styles (with v4.23).")

(defconst sane-perl-style-alist
  '(("Sane-Perl" ;; =GNU - extra-newline-before-brace + sane-perl-merge-trailing-else
     (sane-perl-indent-level               .  2)
     (sane-perl-brace-offset               .  0)
     (sane-perl-continued-brace-offset     .  0)
     (sane-perl-label-offset               . -2)
     (sane-perl-continued-statement-offset .  2)
     (sane-perl-extra-newline-before-brace .  nil)
     (sane-perl-extra-newline-before-brace-multiline .  nil)
     (sane-perl-merge-trailing-else	       .  t))

    ("PBP"  ;; Perl Best Practices by Damian Conway
     (sane-perl-indent-level               .  4)
     (sane-perl-brace-offset               .  0)
     (sane-perl-continued-brace-offset     .  0)
     (sane-perl-label-offset               . -2)
     (sane-perl-continued-statement-offset .  4)
     (sane-perl-extra-newline-before-brace .  nil)
     (sane-perl-extra-newline-before-brace-multiline .  nil)
     (sane-perl-merge-trailing-else        .  nil)
     (sane-perl-indent-parens-as-block     .  t)
     (sane-perl-tab-always-indent          .  t))

    ("PerlStyle"			; Sane-Perl with 4 as indent
     (sane-perl-indent-level               .  4)
     (sane-perl-brace-offset               .  0)
     (sane-perl-continued-brace-offset     .  0)
     (sane-perl-label-offset               . -4)
     (sane-perl-continued-statement-offset .  4)
     (sane-perl-extra-newline-before-brace .  nil)
     (sane-perl-extra-newline-before-brace-multiline .  nil)
     (sane-perl-merge-trailing-else	       .  t))

    ("GNU"
     (sane-perl-indent-level               .  2)
     (sane-perl-brace-offset               .  0)
     (sane-perl-continued-brace-offset     .  2)
     (sane-perl-label-offset               . -2)
     (sane-perl-continued-statement-offset .  2)
     (sane-perl-extra-newline-before-brace .  t)
     (sane-perl-extra-newline-before-brace-multiline .  t)
     (sane-perl-merge-trailing-else	       .  nil))

    ("K&R"
     (sane-perl-indent-level               .  5)
     (sane-perl-brace-offset               .  0)
     (sane-perl-continued-brace-offset     . -5)
     (sane-perl-label-offset               . -5)
     (sane-perl-continued-statement-offset .  5)
     (sane-perl-merge-trailing-else	       .  t))

    ("BSD"
     (sane-perl-indent-level               .  4)
     (sane-perl-brace-offset               .  0)
     (sane-perl-continued-brace-offset     . -4)
     (sane-perl-label-offset               . -4)
     (sane-perl-continued-statement-offset .  4)
     (sane-perl-extra-newline-before-brace .  t)
     (sane-perl-merge-trailing-else	       .  nil)
     )

    ("C++"
     (sane-perl-indent-level               .  4)
     (sane-perl-brace-offset               .  0)
     (sane-perl-continued-brace-offset     . -4)
     (sane-perl-label-offset               . -4)
     (sane-perl-continued-statement-offset .  4)
     (sane-perl-extra-newline-before-brace .  t)
     (sane-perl-extra-newline-before-brace-multiline .  t)
     (sane-perl-merge-trailing-else	       .  nil))

    ("Whitesmith"
     (sane-perl-indent-level               .  0)
     (sane-perl-brace-offset               .  4)
     (sane-perl-continued-brace-offset     .  0)
     (sane-perl-label-offset               . -4)
     (sane-perl-continued-statement-offset .  0)
     (sane-perl-extra-newline-before-brace .  t)
     (sane-perl-merge-trailing-else	       .  nil)
     )
    ("Current"))
  "List of variables to set to get a particular indentation style.
Should be used via `sane-perl-set-style' or via Perl menu.

See examples in `sane-perl-style-examples'.")

(defun sane-perl-set-style (style)
  "Set Sane-Perl mode variables to use one of several different indentation styles.
The arguments are a string representing the desired style.
The list of styles is in `sane-perl-style-alist', available styles
are \"Sane-Perl\", \"PBP\", \"PerlStyle\", \"GNU\", \"K&R\", \"BSD\", \"C++\"
and \"Whitesmith\".

The current value of style is memorized (unless there is a memorized
data already), may be restored by `sane-perl-set-style-back'.

Choosing \"Current\" style will not change style, so this may be used for
side-effect of memorizing only.  Examples in `sane-perl-style-examples'."
  (interactive
   (list (completing-read "Enter style: " sane-perl-style-alist nil 'insist)))
  (or sane-perl-old-style
      (setq sane-perl-old-style
	    (mapcar (lambda (name)
		      (cons name (eval name)))
		    sane-perl-styles-entries)))
  (let ((style (cdr (assoc style sane-perl-style-alist))) setting)
    (while style
      (setq setting (car style) style (cdr style))
      (set (car setting) (cdr setting)))))

(defun sane-perl-set-style-back ()
  "Restore a style memorized by `sane-perl-set-style'."
  (interactive)
  (or sane-perl-old-style (error "The style was not changed"))
  (let (setting)
    (while sane-perl-old-style
      (setq setting (car sane-perl-old-style)
	    sane-perl-old-style (cdr sane-perl-old-style))
      (set (car setting) (cdr setting)))))

(defvar perl-dbg-flags)
(defun sane-perl-check-syntax ()
  (interactive)
  (require 'mode-compile)
  (let ((perl-dbg-flags (concat sane-perl-extra-perl-args " -wc")))
    (eval '(mode-compile))))		; Avoid a warning

(declare-function Info-find-node "info"
		  (filename nodename &optional no-going-back strict-case))

(defun sane-perl-info-buffer (type)
  ;; Returns buffer with documentation.  Creates if missing.
  ;; If TYPE, this vars buffer.
  ;; Special care is taken to not stomp over an existing info buffer
  (let* ((bname (if type "*info-perl-var*" "*info-perl*"))
	 (info (get-buffer bname))
	 (oldbuf (get-buffer "*info*")))
    (if info info
      (save-window-excursion
	;; Get Info running
	(require 'info)
	(cond (oldbuf
	       (set-buffer oldbuf)
	       (rename-buffer "*info-perl-tmp*")))
	(save-window-excursion
	  (info))
	(Info-find-node sane-perl-info-page (if type "perlvar" "perlfunc"))
	(set-buffer "*info*")
	(rename-buffer bname)
	(cond (oldbuf
	       (set-buffer "*info-perl-tmp*")
	       (rename-buffer "*info*")
	       (set-buffer bname)))
	(set (make-local-variable 'window-min-height) 2)
	(current-buffer)))))

(defun sane-perl-word-at-point (&optional p)
  "Return the word at point or at P."
  (save-excursion
    (if p (goto-char p))
    (or (sane-perl-word-at-point-hard)
	(progn
	  (require 'etags)
	  (funcall (or (and (boundp 'find-tag-default-function)
			    find-tag-default-function)
		       (get major-mode 'find-tag-default-function)
		       'find-tag-default))))))

(defun sane-perl-info-on-command (command)
  "Show documentation for Perl command COMMAND in other window.
If perl-info buffer is shown in some frame, uses this frame.
Customized by setting variables `sane-perl-shrink-wrap-info-frame',
`sane-perl-max-help-size'."
  (interactive
   (let* ((default (sane-perl-word-at-point))
	  (read (read-string
		 (sane-perl--format-prompt "Find doc for Perl function" default))))
     (list (if (equal read "")
	       default
	     read))))

  (let ((cmd-desc (concat "^" (regexp-quote command) "[^a-zA-Z_0-9]")) ; "tr///"
	pos isvar height iniheight frheight buf win fr1 fr2 iniwin not-loner
	max-height char-height buf-list)
    (if (string-match "^-[a-zA-Z]$" command)
	(setq cmd-desc "^-X[ \t\n]"))
    (setq isvar (string-match "^[$@%]" command)
	  buf (sane-perl-info-buffer isvar)
	  iniwin (selected-window)
	  fr1 (window-frame iniwin))
    (set-buffer buf)
    (goto-char (point-min))
    (or isvar
	(progn (re-search-forward "^-X[ \t\n]")
	       (forward-line -1)))
    (if (re-search-forward cmd-desc nil t)
	(progn
	  ;; Go back to beginning of the group (ex, for qq)
	  (if (re-search-backward "^[ \t\n\f]")
	      (forward-line 1))
	  (beginning-of-line)
	  ;; Get some of
	  (setq pos (point)
		buf-list (list buf "*info-perl-var*" "*info-perl*"))
	  (while (and (not win) buf-list)
	    (setq win (get-buffer-window (car buf-list) t))
	    (setq buf-list (cdr buf-list)))
	  (or (not win)
	      (eq (window-buffer win) buf)
	      (set-window-buffer win buf))
	  (and win (setq fr2 (window-frame win)))
	  (if (or (not fr2) (eq fr1 fr2))
	      (pop-to-buffer buf)
	    (special-display-popup-frame buf) ; Make it visible
	    (select-window win))
	  (goto-char pos)
	  ;; Resize
	  (setq iniheight (window-height)
		frheight (frame-height)
		not-loner (< iniheight (1- frheight))) ; Are not alone
	  (cond ((if not-loner sane-perl-max-help-size
		   sane-perl-shrink-wrap-info-frame)
		 (setq height
		       (+ 2
			  (count-lines
			   pos
			   (save-excursion
			     (if (re-search-forward
				  "^[ \t][^\n]*\n+\\([^ \t\n\f]\\|\\'\\)" nil t)
				 (match-beginning 0) (point-max)))))
		       max-height
		       (if not-loner
			   (/ (* (- frheight 3) sane-perl-max-help-size) 100)
			 (setq char-height (frame-char-height))
			 (if (eq char-height 1) (setq char-height 18))
			 ;; Title, menubar, + 2 for slack
			 (- (/ (display-pixel-height) char-height) 4)))
		 (if (> height max-height) (setq height max-height))
		 (if not-loner
		     (enlarge-window (- height iniheight))
		   (set-frame-height (window-frame win) (1+ height)))))
	  (set-window-start (selected-window) pos))
      (message "No entry for %s found." command))
    (select-window iniwin)))

(defun sane-perl-info-on-current-command ()
  "Show documentation for Perl command at point in other window."
  (interactive)
  (sane-perl-info-on-command (sane-perl-word-at-point)))

(defun sane-perl-imenu-info-imenu-search ()
  (if (looking-at "^-X[ \t\n]") nil
    (re-search-backward
     "^\n\\([-a-zA-Z_]+\\)[ \t\n]")
    (forward-line 1)))

(defun sane-perl-imenu-info-imenu-name ()
  (buffer-substring
   (match-beginning 1) (match-end 1)))

(declare-function imenu-choose-buffer-index "imenu" (&optional prompt alist))

(defun sane-perl-imenu-on-info ()
  "Shows imenu for Perl Info Buffer.
Opens Perl Info buffer if needed."
  (interactive)
  (require 'imenu)
  (let* ((buffer (current-buffer))
	 imenu-create-index-function
	 imenu-prev-index-position-function
	 imenu-extract-index-name-function
	 (index-item (save-restriction
		       (save-window-excursion
			 (set-buffer (sane-perl-info-buffer nil))
			 (setq imenu-create-index-function
			       'imenu-default-create-index-function
			       imenu-prev-index-position-function
			       #'sane-perl-imenu-info-imenu-search
			       imenu-extract-index-name-function
			       #'sane-perl-imenu-info-imenu-name)
			 (imenu-choose-buffer-index)))))
    (and index-item
	 (progn
	   (push-mark)
	   (pop-to-buffer "*info-perl*")
	   (cond
	    ((markerp (cdr index-item))
	     (goto-char (marker-position (cdr index-item))))
	    (t
	     (goto-char (cdr index-item))))
	   (set-window-start (selected-window) (point))
	   (pop-to-buffer buffer)))))

(defun sane-perl-lineup (beg end &optional step minshift)
  "Lineup construction in a region.
Beginning of region should be at the start of a construction.
All first occurrences of this construction in the lines that are
partially contained in the region are lined up at the same column.

MINSHIFT is the minimal amount of space to insert before the construction.
STEP is the tabwidth to position constructions.
If STEP is nil, `sane-perl-lineup-step' will be used
\(or `sane-perl-indent-level', if `sane-perl-lineup-step' is nil).
Will not move the position at the start to the left."
  (interactive "r")
  (let (search col tcol seen)
    (save-excursion
      (goto-char end)
      (end-of-line)
      (setq end (point-marker))
      (goto-char beg)
      (skip-chars-forward " \t\f")
      (setq beg (point-marker))
      (indent-region beg end nil)
      (goto-char beg)
      (setq col (current-column))
      (if (looking-at "[a-zA-Z0-9_]")
	  (if (looking-at "\\<[a-zA-Z0-9_]+\\>")
	      (setq search
		    (concat "\\<"
			    (regexp-quote
			     (buffer-substring (match-beginning 0)
					       (match-end 0))) "\\>"))
	    (error "Cannot line up in a middle of the word"))
	(if (looking-at "$")
	    (error "Cannot line up end of line"))
	(setq search (regexp-quote (char-to-string (following-char)))))
      (setq step (or step sane-perl-lineup-step sane-perl-indent-level))
      (or minshift (setq minshift 1))
      (while (progn
	       (beginning-of-line 2)
	       (and (< (point) end)
		    (re-search-forward search end t)
		    (goto-char (match-beginning 0))))
	(setq tcol (current-column) seen t)
	(if (> tcol col) (setq col tcol)))
      (or seen
	  (error "The construction to line up occurred only once"))
      (goto-char beg)
      (setq col (+ col minshift))
      (if (/= (% col step) 0) (setq step (* step (1+ (/ col step)))))
      (while
          (progn
            (sane-perl-make-indent col)
            (beginning-of-line 2)
            (and (< (point) end)
                 (re-search-forward search end t)
                 (goto-char (match-beginning 0)))))))) ; No body

;; 2020-07-12: While they are technically possible under 'use utf8',
;; we don't support non-ASCII identifiers, and we also reject to
;; process package names starting with or ending with colon pairs.
(defconst sane-perl--basic-identifier-regexp
  "\\(?:[a-zA-Z_][a-zA-Z0-9_]*\\)"
  "A regexp for basic identifiers (ASCII only), without sigil.")

(defconst sane-perl--identifier-regexp
  (concat sane-perl--basic-identifier-regexp
          "\\(?:\\(?:'\\|::\\)" sane-perl--basic-identifier-regexp "\\)*")
  "A regexp for Perl identifiers, without sigil, qualified with a package.")

(defconst sane-perl--version-regexp
  (concat
   "\\(?:"
   "\\(?:v[[:digit:]]+\\(?:\\.[[:digit:]]+\\)\\{2,\\}\\)" ;; v1.2.3
   "\\|\\.[[:digit:]]+"                                   ;; .001
   "\\|[[:digit:]]+\\.[[:digit:]]*"                       ;; 0.01 or 12.
   "\\|[[:digit:]]+"                                      ;; 42
   "\\)")
  "A regexp for \"good, boring\" Perl version numbers.")

(defun sane-perl--setup-etags-args ()
  "Prepare the appropriate regular expressions for etags."
  `("-l" "none" "-r"
    ;; 1=fullname  2=package? 3=name 4=proto? 5=attrs? (VERY APPROX!)
    ,(concat "/[ \t]*\\<"                           ;; etags start at BOL
              sane-perl--sub-regexp                     ;; subroutine declarator
              "[ \\t]+"                             ;;
              "\\(" sane-perl--identifier-regexp "\\)"  ;; qualified subroutine name
              "[ \\t]*\\(?:([^()]*)[ \t]*\\)?"      ;; prototype / signature
              "\\(?:[ \t]*:[^#{;]*\\)?"             ;; optional attributes
              "\\(?:[{#]\\|$\\)"                    ;; brace or comment or EOL
              "/\\1/")                              ;; name goes to TAGS
    "-r"
    ,(concat "/[ \t]*\\<"                           ;; etags start at BOL
             sane-perl--namespace-declare-regexp        ;; namespace declarator
             "[ \\t]+"                              ;;
             "\\(" sane-perl--identifier-regexp "\\)"   ;; qualified package name
             "\\(?:[ \\t]+" sane-perl--version-regexp   ;; package NAME VERSION
             "\\)?"                                 ;; ...is optional
             "\\(?:[ \\t]+"                         ;;
             sane-perl--namespace-ref-regexp            ;; extends and similar stuff
             "[ \\t]+" sane-perl--identifier-regexp     ;; followed by another package
             "\\)*"                                 ;; FIXME: Is there a comma?
             "[ \\t]*\\(?:[#;{]\\|$\\)"             ;; and some closing thingy
             "/\\1/")                               ;; full name goes to TAGS
    "-r"
    ,(concat "/[ \t]*\\<\\("
             sane-perl--namespace-declare-regexp       ;; anonymous declarator
             "\\)[ \\t]*;/\\1;/")))                ;; declarator goes to TAGS

(defun sane-perl-etags (&optional add all files) ;; NOT USED???
  "Run etags with appropriate options for Perl files.
If optional argument ALL is `recursive', will process Perl files
in subdirectories too."
  (interactive)
  (let ((cmd "etags")
        (args (sane-perl--setup-etags-args))
        res)
    (if add (setq args (cons "-a" args)))
    (or files (setq files (list buffer-file-name)))
    (cond
     ((eq all 'recursive)
      (setq args (append (list "-e"
			       "sub wanted {push @ARGV, $File::Find::name if /\\.[pP][Llm]$/}
				use File::Find;
				find(\\&wanted, '.');
				exec @ARGV;"
			       cmd) args)
	    cmd "perl"))
     (all
      (setq args (append (list "-e"
			       "push @ARGV, <*.PL *.pl *.pm>;
				exec @ARGV;"
			       cmd) args)
	    cmd "perl"))
     (t
      (setq args (append args files))))
    (setq res (apply 'call-process cmd nil nil nil args))
    (or (eq res 0)
	(message "etags returned \"%s\"" res))))

(defun sane-perl-toggle-auto-newline ()
  "Toggle the state of `sane-perl-auto-newline'."
  (interactive)
  (setq sane-perl-auto-newline (not sane-perl-auto-newline))
  (message "Newlines will %sbe auto-inserted now."
	   (if sane-perl-auto-newline "" "not ")))

(defun sane-perl-toggle-abbrev ()
  "Toggle the state of automatic keyword expansion in Sane-Perl mode."
  (interactive)
  (abbrev-mode (if abbrev-mode 0 1))
  (message "Perl control structure will %sbe auto-inserted now."
	   (if abbrev-mode "" "not ")))


(defun sane-perl-toggle-electric ()
  "Toggle the state of parentheses doubling in Sane-Perl mode."
  (interactive)
  (setq sane-perl-electric-parens (if (sane-perl-val 'sane-perl-electric-parens) 'null t))
  (message "Parentheses will %sbe auto-doubled now."
	   (if (sane-perl-val 'sane-perl-electric-parens) "" "not ")))

(defun sane-perl-toggle-autohelp ()
  ;; FIXME: Turn me into a minor mode.  Fix menu entries for "Auto-help on" as
  ;; well.
  "Toggle the state of Auto-Help on Perl constructs (put in the message area).
Delay of auto-help controlled by `sane-perl-lazy-help-time'."
  (interactive)
  (if sane-perl-lazy-installed
      (sane-perl-lazy-unstall)
    (sane-perl-lazy-install))
  (message "Perl help messages will %sbe automatically shown now."
	   (if sane-perl-lazy-installed "" "not ")))

(defun sane-perl-toggle-construct-fix ()
  "Toggle whether `indent-region'/`indent-sexp' fix whitespace too."
  (interactive)
  (setq sane-perl-indent-region-fix-constructs
	(if sane-perl-indent-region-fix-constructs
	    nil
	  1))
  (message "indent-region/indent-sexp will %sbe automatically fix whitespace."
	   (if sane-perl-indent-region-fix-constructs "" "not ")))

(defun sane-perl-toggle-set-debug-unwind (arg &optional backtrace)
  "Toggle (or, with numeric argument, set) debugging state of syntaxification.
Nonpositive numeric argument disables debugging messages.  The message
summarizes which regions it was decided to rescan for syntactic constructs.

The message looks like this:

  Syxify req=123..138 actual=101..146 done-to: 112=>146 statepos: 73=>117

Numbers are character positions in the buffer.  REQ provides the range to
rescan requested by `font-lock'.  ACTUAL is the range actually resyntaxified;
for correct operation it should start and end outside any special syntactic
construct.  DONE-TO and STATEPOS indicate changes to internal caches maintained
by Sane-Perl."
  (interactive "P")
  (or arg
      (setq arg (if (eq sane-perl-syntaxify-by-font-lock
			(if backtrace 'backtrace 'message))
                    0 1)))
  (setq arg (if (> arg 0) (if backtrace 'backtrace 'message) t))
  (setq sane-perl-syntaxify-by-font-lock arg)
  (message "Debugging messages of syntax unwind %sabled."
	   (if (eq arg t) "dis" "en")))

;;;; Tags file creation.

(defvar sane-perl-tmp-buffer " *sane-perl-tmp*")

(defun sane-perl-setup-tmp-buf ()
  (set-buffer (get-buffer-create sane-perl-tmp-buffer))
  (set-syntax-table sane-perl-mode-syntax-table)
  (buffer-disable-undo)
  (auto-fill-mode 0)
  (if sane-perl-use-syntax-table-text-property-for-tags
      (progn
	;; Do not introduce variable if not needed, we check it!
	(set (make-local-variable 'parse-sexp-lookup-properties) t))))

;; Copied from imenu-example--name-and-position.
(defvar imenu-use-markers)

(defun sane-perl-imenu-name-and-position ()
  "Return the current/previous sexp and its (beginning) location.
Does not move point."
  (save-excursion
    (forward-sexp -1)
    (let ((beg (if imenu-use-markers (point-marker) (point)))
	  (end (progn (forward-sexp) (point))))
      (cons (buffer-substring beg end)
	    beg))))

(defun sane-perl-xsub-scan ()
  (require 'imenu)
  (let ((index-alist '())
        index index1 name package prefix)
    (goto-char (point-min))
    ;; Search for the function
    (progn ;;save-match-data
      (while (re-search-forward
	      "^\\([ \t]*MODULE\\>[^\n]*\\<PACKAGE[ \t]*=[ \t]*\\([a-zA-Z_][a-zA-Z_0-9:]*\\)\\>\\|\\([a-zA-Z_][a-zA-Z_0-9]*\\)(\\|[ \t]*BOOT:\\)"
	      nil t)
	(cond
	 ((match-beginning 2)		; SECTION
	  (setq package (buffer-substring (match-beginning 2) (match-end 2)))
	  (goto-char (match-beginning 0))
	  (skip-chars-forward " \t")
	  (forward-char 1)
	  (if (looking-at "[^\n]*\\<PREFIX[ \t]*=[ \t]*\\([a-zA-Z_][a-zA-Z_0-9]*\\)\\>")
	      (setq prefix (buffer-substring (match-beginning 1) (match-end 1)))
	    (setq prefix nil)))
	 ((not package) nil)		; C language section
	 ((match-beginning 3)		; XSUB
	  (goto-char (1+ (match-beginning 3)))
	  (setq index (sane-perl-imenu-name-and-position))
	  (setq name (buffer-substring (match-beginning 3) (match-end 3)))
	  (if (and prefix (string-match (concat "^" prefix) name))
	      (setq name (substring name (length prefix))))
	  (cond ((string-match "::" name) nil)
		(t
		 (setq index1 (cons (concat package "::" name) (cdr index)))
		 (push index1 index-alist)))
	  (setcar index name)
	  (push index index-alist))
	 (t				; BOOT: section
	  (setq index (sane-perl-imenu-name-and-position))
	  (setcar index (concat package "::BOOT:"))
	  (push index index-alist)))))
    index-alist))

(defvar sane-perl-unreadable-ok nil)

(defun sane-perl-find-tags (ifile xs topdir)
  (let ((b (get-buffer sane-perl-tmp-buffer)) ind lst elt pos ret rel
	(sane-perl-pod-here-fontify nil) file)
    (save-excursion
      (if b (set-buffer b)
	(sane-perl-setup-tmp-buf))
      (erase-buffer)
      (condition-case nil
	  (setq file (car (insert-file-contents ifile)))
	(error (if sane-perl-unreadable-ok nil
		 (if (y-or-n-p
		      (format "File %s unreadable.  Continue? " ifile))
		     (setq sane-perl-unreadable-ok t)
		   (error "Aborting: unreadable file %s" ifile)))))
      (if (not file)
	  (message "Unreadable file %s" ifile)
	(message "Scanning file %s ..." file)
	(sane-perl-collect-keyword-regexps)
	(if (and sane-perl-use-syntax-table-text-property-for-tags
		 (not xs))
	    (condition-case err		; after __END__ may have garbage
		(sane-perl-find-pods-heres nil nil noninteractive)
	      (error (message "While scanning for syntax: %S" err))))
	(if xs
	    (setq lst (sane-perl-xsub-scan))
	  (setq ind (sane-perl-imenu--create-perl-index))
	  (setq lst (cdr (assoc "+Unsorted List+..." ind))))
	(setq lst
	      (mapcar
	       (lambda (elt)
		 (cond ((string-match "^[_a-zA-Z]" (car elt))
			(goto-char (cdr elt))
			(beginning-of-line) ; pos should be of the start of the line
			(list (car elt)
			      (point)
			      (1+ (count-lines 1 (point))) ; 1+ since at beg-o-l
			      (buffer-substring (progn
						  (goto-char (cdr elt))
						  ;; After name now...
						  (or (eolp) (forward-char 1))
						  (point))
						(progn
						  (beginning-of-line)
						  (point)))))))
	       lst))
	(erase-buffer)
	(while lst
	  (setq elt (car lst) lst (cdr lst))
	  (if elt
	      (progn
		(insert (elt elt 3)
			127
			(if (string-match "^package " (car elt))
			    (substring (car elt) 8)
			  (car elt) )
			1
			(number-to-string (elt elt 2)) ; Line
			","
			(number-to-string (1- (elt elt 1))) ; Char pos 0-based
			"\n")
		(if (and (string-match "^[_a-zA-Z]+::" (car elt))
			 (string-match (concat "^[\t ]*"
					       sane-perl--sub-regexp
					       "[ \t]+\\([_a-zA-Z]+\\)[^:_a-zA-Z]")
				       (elt elt 3)))
		    ;; Need to insert the name without package as well
		    (setq lst (cons (cons (substring (elt elt 3)
						     (match-beginning 1)
						     (match-end 1))
					  (cdr elt))
				    lst))))))
	(setq pos (point))
	(goto-char 1)
	(setq rel file)
	;; On case-preserving filesystems case might be encoded in properties
	(set-text-properties 0 (length rel) nil rel)
	(and (equal topdir (substring rel 0 (length topdir)))
	     (setq rel (substring file (length topdir))))
	(insert "\f\n" rel "," (number-to-string (1- pos)) "\n")
	(setq ret (buffer-substring 1 (point-max)))
	(erase-buffer)
	(or noninteractive
	    (message "Scanning file %s finished" file))
	ret))))

(defun sane-perl-add-tags-recurse-noxs ()
  "Add to TAGS data for \"pure\" Perl files in the current directory and kids.
Use as
  emacs -batch -q -no-site-file -l emacs/sane-perl-mode.el \
        -f sane-perl-add-tags-recurse-noxs
"
  (sane-perl-write-tags nil nil t t nil t))

(defun sane-perl-add-tags-recurse-noxs-fullpath ()
  "Add to TAGS data for \"pure\" Perl in the current directory and kids.
Writes down fullpath, so TAGS is relocatable (but if the build directory
is relocated, the file TAGS inside it breaks). Use as
  emacs -batch -q -no-site-file -l emacs/sane-perl-mode.el \
        -f sane-perl-add-tags-recurse-noxs-fullpath
"
  (sane-perl-write-tags nil nil t t nil t ""))

(defun sane-perl-add-tags-recurse ()
  "Add to TAGS file data for Perl files in the current directory and kids.
Use as
  emacs -batch -q -no-site-file -l emacs/sane-perl-mode.el \
        -f sane-perl-add-tags-recurse
"
  (sane-perl-write-tags nil nil t t))

(defun sane-perl-write-tags (&optional file erase recurse dir inbuffer noxs topdir)
  ;; If INBUFFER, do not select buffer, and do not save
  ;; If ERASE is `ignore', do not erase, and do not try to delete old info.
  (require 'etags)
  (if file nil
    (setq file (if dir default-directory (buffer-file-name)))
    (if (and (not dir) (buffer-modified-p)) (error "Save buffer first!")))
  (or topdir
      (setq topdir default-directory))
  (let ((tags-file-name "TAGS")
        (inhibit-read-only t)
	(case-fold-search nil)
	xs rel)
    (save-excursion
      (cond (inbuffer nil)		; Already there
	    ((file-exists-p tags-file-name)
	     (visit-tags-table-buffer tags-file-name))
	    (t
             (set-buffer (find-file-noselect tags-file-name))))
      (cond
       (dir
	(cond ((eq erase 'ignore))
	      (erase
	       (erase-buffer)
	       (setq erase 'ignore)))
	(let ((files
	       (condition-case nil
		   (directory-files file t
				    (if recurse nil sane-perl-scan-files-regexp)
				    t)
		 (error
		  (if sane-perl-unreadable-ok nil
		    (if (y-or-n-p
			 (format "Directory %s unreadable.  Continue? " file))
			(progn
                          (setq sane-perl-unreadable-ok t)
                          nil)	; Return empty list
		      (error "Aborting: unreadable directory %s" file)))))))
	  (mapc (lambda (file)
		   (cond
		    ((string-match sane-perl-noscan-files-regexp file)
		     nil)
		    ((not (file-directory-p file))
		     (if (string-match sane-perl-scan-files-regexp file)
			 (sane-perl-write-tags file erase recurse nil t noxs topdir)))
		    ((not recurse) nil)
		    (t (sane-perl-write-tags file erase recurse t t noxs topdir))))
		files)))
       (t
	(setq xs (string-match "\\.xs$" file))
	(if (not (and xs noxs))
	    (progn
	      (cond ((eq erase 'ignore) (goto-char (point-max)))
		    (erase (erase-buffer))
		    (t
		     (goto-char 1)
		     (setq rel file)
		     ;; On case-preserving filesystems case might be encoded in properties
		     (set-text-properties 0 (length rel) nil rel)
		     (and (equal topdir (substring rel 0 (length topdir)))
			  (setq rel (substring file (length topdir))))
		     (if (search-forward (concat "\f\n" rel ",") nil t)
			 (progn
			   (search-backward "\f\n")
			   (delete-region (point)
					  (save-excursion
					    (forward-char 1)
					    (if (search-forward "\f\n"
								nil 'toend)
						(- (point) 2)
					      (point-max)))))
		       (goto-char (point-max)))))
	      (insert (sane-perl-find-tags file xs topdir))))))
      (if inbuffer nil			; Delegate to the caller
	(save-buffer 0)			; No backup
	(if (fboundp 'initialize-new-tags-table)
            (initialize-new-tags-table))))))

(defvar sane-perl-hierarchy '(() ())
  "Global hierarchy of classes.")

;; Follows call to (autoloaded) visit-tags-table.
(declare-function file-of-tag "etags" (&optional relative))
(declare-function etags-snarf-tag "etags" (&optional use-explicit))

(defvar sane-perl-tags-hier-regexp-list nil)

(defun sane-perl-tags-hier-fill ()
  ;; Suppose we are in a tag table cooked by sane-perl.
  (goto-char 1)
  (let (pack name line ord cons1 file info fileind)
    (while (re-search-forward sane-perl-tags-hier-regexp-list nil t)
      (setq pack (match-beginning 2))
      (beginning-of-line)
      (if (looking-at (concat
		       "\\([^\n]+\\)"
		       "\C-?"
		       "\\([^\n]+\\)"
		       "\C-a"
		       "\\([0-9]+\\)"
		       ","
		       "\\([0-9]+\\)"))
	  (progn
	    (setq
		  name (buffer-substring (match-beginning 2) (match-end 2))
		  line (buffer-substring (match-beginning 3) (match-end 3))
		  ord (if pack 1 0)
		  file (file-of-tag)  ;; <-- a function in etags.el
		  fileind (format "%s:%s" file line)
		  ;; Moves to beginning of the next line:
		  info (etags-snarf-tag)) ;; <-- in etags.el. Not documented.
	    ;; Move back
	    (forward-char -1)
	    ;; Make new member of hierarchy name ==> file ==> pos if needed
	    (if (setq cons1 (assoc name (nth ord sane-perl-hierarchy)))
		;; Name known
		(setcdr cons1 (cons (cons fileind (vector file info))
				    (cdr cons1)))
	      ;; First occurrence of the name, start alist
	      (setq cons1 (cons name (list (cons fileind (vector file info)))))
	      (if pack
		  (setcar (cdr sane-perl-hierarchy)
			  (cons cons1 (nth 1 sane-perl-hierarchy)))
		(setcar sane-perl-hierarchy
			(cons cons1 (car sane-perl-hierarchy)))))))
      (end-of-line))))

(declare-function x-popup-menu "menu.c" (position menu))
(declare-function etags-goto-tag-location "etags" (tag-info))

(defun sane-perl-tags-hier-init (&optional update)
  "Show hierarchical menu of classes and methods.
Finds info about classes by a scan of loaded TAGS files.
Supposes that the TAGS files contain fully qualified function names.
One may build such TAGS files from Sane-Perl mode menu."
  (interactive)
  (require 'etags)
  (require 'imenu)
  (if (or update (null (nth 2 sane-perl-hierarchy)))
      (let ((remover (function (lambda (elt) ; (name (file1...) (file2..))
				 (or (nthcdr 2 elt)
				     ;; Only in one file
				     (setcdr elt (cdr (nth 1 elt)))))))
	    to l1 l2 l3)
	(setq sane-perl-hierarchy (list l1 l2 l3))
	(or tags-table-list
	    (call-interactively 'visit-tags-table))
	(mapc
	 (lambda (tagsfile)
	   (message "Updating list of classes... %s" tagsfile)
	   (set-buffer (get-file-buffer tagsfile))
	   (sane-perl-tags-hier-fill))
	 tags-table-list)
	(message "Updating list of classes... postprocessing...")
	(mapc remover (car sane-perl-hierarchy))
	(mapc remover (nth 1 sane-perl-hierarchy))
	(setq to (list nil (cons "Packages: " (nth 1 sane-perl-hierarchy))
		       (cons "Methods: " (car sane-perl-hierarchy))))
	(sane-perl-tags-treeify to 1)
	(setcar (nthcdr 2 sane-perl-hierarchy)
		(sane-perl-menu-to-keymap (cons '("+++UPDATE+++" . -999) (cdr to))))
	(message "Updating list of classes: done, requesting display...")
	))
  (or (nth 2 sane-perl-hierarchy)
      (error "No items found"))
  (setq update
	(if (if (fboundp 'display-popup-menus-p)
		(display-popup-menus-p)
	      window-system)
	    (x-popup-menu t (nth 2 sane-perl-hierarchy))
	  (require 'tmm)
	  (tmm-prompt (nth 2 sane-perl-hierarchy))))
  (if (and update (listp update))
      (progn (while (cdr update) (setq update (cdr update)))
	     (setq update (car update)))) ; Get the last from the list
  (if (vectorp update)
      (progn
	(find-file (elt update 0))
	(etags-goto-tag-location (elt update 1))))
  (if (eq update -999) (sane-perl-tags-hier-init t)))

(defun sane-perl-tags-treeify (to level)
  ;; cadr of `to' is read-write.  On start it is a cons
  (let* ((regexp (concat "^\\(" (mapconcat
				 #'identity
				 (make-list level "[_a-zA-Z0-9]+")
				 "::")
			 "\\)\\(::\\)?"))
	 (packages (cdr (nth 1 to)))
	 (methods (cdr (nth 2 to)))
	 l1 head cons1 cons2 ord writeto recurse
	 root-packages root-functions
	 (move-deeper
	   (lambda (elt)
	     (cond ((and (string-match regexp (car elt))
			 (or (eq ord 1) (match-end 2)))
		    (setq head (substring (car elt) 0 (match-end 1))
			  recurse t)
		    (if (setq cons1 (assoc head writeto)) nil
		      ;; Need to init new head
		      (setcdr writeto (cons (list head (list "Packages: ")
						  (list "Methods: "))
					    (cdr writeto)))
		      (setq cons1 (nth 1 writeto)))
		    (setq cons2 (nth ord cons1)) ; Either packs or meths
		    (setcdr cons2 (cons elt (cdr cons2))))
		   ((eq ord 2)
		    (setq root-functions (cons elt root-functions)))
		   (t
		    (setq root-packages (cons elt root-packages)))))))
    (setcdr to l1)			; Init to dynamic space
    (setq writeto to)
    (setq ord 1)
    (mapc move-deeper packages)
    (setq ord 2)
    (mapc move-deeper methods)
    (if recurse
	(mapc (function (lambda (elt)
			  (sane-perl-tags-treeify elt (1+ level))))
	      (cdr to)))
    ;;Now clean up leaders with one child only
    (mapc (function (lambda (elt)
		      (if (not (and (listp (cdr elt))
				    (eq (length elt) 2)))
                          nil
			(setcar elt (car (nth 1 elt)))
			(setcdr elt (cdr (nth 1 elt))))))
	  (cdr to))
    ;; Sort the roots of subtrees
    (if (default-value 'imenu-sort-function)
	(setcdr to
		(sort (cdr to) (default-value 'imenu-sort-function))))
    ;; Now add back functions removed from display
    (mapc (function (lambda (elt)
		      (setcdr to (cons elt (cdr to)))))
	  (if (default-value 'imenu-sort-function)
	      (nreverse
	       (sort root-functions (default-value 'imenu-sort-function)))
	    root-functions))
    ;; Now add back packages removed from display
    (mapc (function (lambda (elt)
		      (setcdr to (cons (cons (concat "package " (car elt))
					     (cdr elt))
				       (cdr to)))))
	  (if (default-value 'imenu-sort-function)
	      (nreverse
	       (sort root-packages (default-value 'imenu-sort-function)))
	    root-packages))))

(defun sane-perl-list-fold (list name limit)
  (let (list1 list2 elt1 (num 0))
    (if (<= (length list) limit) list
      (setq list1 nil list2 nil)
      (while list
	(setq num (1+ num)
	      elt1 (car list)
	      list (cdr list))
	(if (<= num imenu-max-items)
	    (setq list2 (cons elt1 list2))
	  (setq list1 (cons (cons name
				  (nreverse list2))
			    list1)
		list2 (list elt1)
		num 1)))
      (nreverse (cons (cons name
			    (nreverse list2))
		      list1)))))

(defun sane-perl-menu-to-keymap (menu)
  (let (list)
    (cons 'keymap
	  (mapcar
	   (lambda (elt)
	     (cond ((listp (cdr elt))
		    (setq list (sane-perl-list-fold
				(cdr elt) (car elt) imenu-max-items))
		    (cons nil
			  (cons (car elt)
				(sane-perl-menu-to-keymap list))))
		   (t
		    (list (cdr elt) (car elt) t)))) ; t is needed in 19.34
	   (sane-perl-list-fold menu "Root" imenu-max-items)))))


(defvar sane-perl-bad-style-regexp
  (mapconcat #'identity
	     '("[^-\n\t <>=+!.&|(*/'`\"#^][-=+<>!|&^]" ; char sign
	       "[-<>=+^&|]+[^- \t\n=+<>~]") ; sign+ char
	     "\\|")
  "Finds places such that insertion of a whitespace may help a lot.")

(defvar sane-perl-not-bad-style-regexp
  (mapconcat
   #'identity
   '("[^-\t <>=+]\\(--\\|\\+\\+\\)"	; var-- var++
     "[a-zA-Z0-9_][|&][a-zA-Z0-9_$]"	; abc|def abc&def are often used.
     "&[(a-zA-Z0-9_$]"			; &subroutine &(var->field)
     "<\\$?\\sw+\\(\\.\\(\\sw\\|_\\)+\\)?>"	; <IN> <stdin.h>
     "-[a-zA-Z][ \t]+[_$\"'`a-zA-Z]"	; -f file, -t STDIN
     "-[0-9]"				; -5
     "\\+\\+"				; ++var
     "--"				; --var
     ".->"				; a->b
     "->"				; a SPACE ->b
     "\\[-"				; a[-1]
     "\\\\[&$@*\\]"			; \&func
     "^="				; =head
     "\\$."				; $|
     "<<[a-zA-Z_'\"`]"			; <<FOO, <<'FOO'
     "||"
     "//"
     "&&"
     "[CBIXSLFZ]<\\(\\sw\\|\\s \\|\\s_\\|[\n]\\)*>" ; C<code like text>
     "-[a-zA-Z_0-9]+[ \t]*=>"		; -option => value
     ;; Unaddressed trouble spots: = -abc, f(56, -abc) --- specialcased below
     ;;"[*/+-|&<.]+="
     )
   "\\|")
  "If matches at the start of match found by `my-bad-c-style-regexp',
insertion of a whitespace will not help.")

(defvar found-bad)

(defun sane-perl-find-bad-style ()
  "Find places in the buffer where insertion of a whitespace may help.
Prompts user for insertion of spaces.
Currently it is tuned to C and Perl syntax."
  (interactive)
  (let (found-bad (p (point)))
    (setq last-nonmenu-event 13)	; To disable popup
    (goto-char (point-min))
    (map-y-or-n-p "Insert space here? "
		  (lambda (_) (insert " "))
		  'sane-perl-next-bad-style
		  '("location" "locations" "insert a space into")
		  `((?\C-r ,(lambda (_)
			      (let ((buffer-quit-function
				     #'exit-recursive-edit))
			        (message "Exit with Esc Esc")
			        (recursive-edit)
			        t))	; Consider acted upon
			   "edit, exit with Esc Esc")
		    (?e ,(lambda (_)
			   (let ((buffer-quit-function
				  #'exit-recursive-edit))
			     (message "Exit with Esc Esc")
			     (recursive-edit)
			     t))        ; Consider acted upon
			"edit, exit with Esc Esc"))
		  t)
    (if found-bad (goto-char found-bad)
      (goto-char p)
      (message "No appropriate place found"))))

(defun sane-perl-next-bad-style ()
  (let (p (not-found t) found)
    (while (and not-found
		(re-search-forward sane-perl-bad-style-regexp nil 'to-end))
      (setq p (point))
      (goto-char (match-beginning 0))
      (if (or
	   (looking-at sane-perl-not-bad-style-regexp)
	   ;; Check for a < -b and friends
	   (and (eq (following-char) ?\-)
		(save-excursion
		  (skip-chars-backward " \t\n")
		  (memq (preceding-char) '(?\= ?\> ?\< ?\, ?\( ?\[ ?\{))))
	   ;; Now check for syntax type
	   (save-match-data
	     (setq found (point))
	     (beginning-of-defun)
	     (let ((pps (parse-partial-sexp (point) found)))
	       (or (nth 3 pps) (nth 4 pps) (nth 5 pps)))))
	  (goto-char (match-end 0))
	(goto-char (1- p))
	(setq not-found nil
	      found-bad found)))
    (not not-found)))


;;; Getting help
(defvar sane-perl-have-help-regexp
  ;;(concat "\\("
  (mapconcat
   #'identity
   '("[$@%*&][0-9a-zA-Z_:]+\\([ \t]*[[{]\\)?" ; Usual variable
     "[$@]\\^[a-zA-Z]"			; Special variable
     "[$@][^ \n\t]"			; Special variable
     "-[a-zA-Z]"			; File test
     "\\\\[a-zA-Z0]"			; Special chars
     "^=[a-z][a-zA-Z0-9_]*"		; POD sections
     "[-!&*+,./<=>?\\^|~]+"		; Operator
     "[a-zA-Z_0-9:]+"			; symbol or number
     "x="
     "#!")
   ;;"\\)\\|\\("
   "\\|")
  ;;"\\)"
  ;;)
  "Matches places in the buffer we can find help for.")

(defvar sane-perl-message-on-help-error t)
(defvar sane-perl-help-from-timer nil)

(defun sane-perl-word-at-point-hard ()
  ;; Does not save-excursion
  ;; Get to the something meaningful
  (or (eobp) (eolp) (forward-char 1))
  (re-search-backward "[-a-zA-Z0-9_:!&*+,./<=>?\\^|~$%@]"
		      (line-beginning-position)
		      'to-beg)
  ;; Try to backtrace
  (cond
   ((looking-at "[a-zA-Z0-9_:]")	; symbol
    (skip-chars-backward "a-zA-Z0-9_:")
    (cond
     ((and (eq (preceding-char) ?^)	; $^I
	   (eq (char-after (- (point) 2)) ?\$))
      (forward-char -2))
     ((memq (preceding-char) (append "*$@%&\\" nil)) ; *glob
      (forward-char -1))
     ((and (eq (preceding-char) ?\=)
	   (eq (current-column) 1))
      (forward-char -1)))		; =head1
    (if (and (eq (preceding-char) ?\<)
	     (looking-at "\\$?[a-zA-Z0-9_:]+>")) ; <FH>
	(forward-char -1)))
   ((and (looking-at "=") (eq (preceding-char) ?x)) ; x=
    (forward-char -1))
   ((and (looking-at "\\^") (eq (preceding-char) ?\$)) ; $^I
    (forward-char -1))
   ((looking-at "[-!&*+,./<=>?\\^|~]")
    (skip-chars-backward "-!&*+,./<=>?\\^|~")
    (cond
     ((and (eq (preceding-char) ?\$)
	   (not (eq (char-after (- (point) 2)) ?\$))) ; $-
      (forward-char -1))
     ((and (eq (following-char) ?\>)
	   (string-match "[a-zA-Z0-9_]" (char-to-string (preceding-char)))
	   (save-excursion
	     (forward-sexp -1)
	     (and (eq (preceding-char) ?\<)
		  (looking-at "\\$?[a-zA-Z0-9_:]+>")))) ; <FH>
      (search-backward "<"))))
   ((and (eq (following-char) ?\$)
	 (eq (preceding-char) ?\<)
	 (looking-at "\\$?[a-zA-Z0-9_:]+>")) ; <$fh>
    (forward-char -1)))
  (if (looking-at sane-perl-have-help-regexp)
      (buffer-substring (match-beginning 0) (match-end 0))))

(defun sane-perl-get-help ()
  "Get one-line docs on the symbol at the point."
  (interactive)
  (save-match-data			; May be called "inside" query-replace
    (save-excursion
      (let ((word (sane-perl-word-at-point-hard)))
	(if word
	    (if (and sane-perl-help-from-timer ; Bail out if not in mainland
		     (not (string-match "^#!\\|\\\\\\|^=" word)) ; Show help even in comments/strings.
		     (or (memq (get-text-property (point) 'face)
			       '(font-lock-comment-face font-lock-string-face))
			 (memq (get-text-property (point) 'syntax-type)
			       '(pod here-doc format))))
		nil
	      (sane-perl-describe-perl-symbol word))
	  (if sane-perl-message-on-help-error
	      (message "Nothing found for %s..."
		       (buffer-substring (point) (min (+ 5 (point)) (point-max))))))))))

(defvar sane-perl-doc-buffer " *perl-doc*"
  "Where the documentation can be found.")

(defun sane-perl-describe-perl-symbol (val)
  "Display the documentation of symbol at point, a Perl operator."
  (let ((enable-recursive-minibuffers t)
	regexp)
    (cond
     ((string-match "^[&*][a-zA-Z_]" val)
      (setq val (concat (substring val 0 1) "NAME")))
     ((string-match "^[$@]\\([a-zA-Z_:0-9]+\\)[ \t]*\\[" val)
      (setq val (concat "@" (substring val 1 (match-end 1)))))
     ((string-match "^[$@]\\([a-zA-Z_:0-9]+\\)[ \t]*{" val)
      (setq val (concat "%" (substring val 1 (match-end 1)))))
     ((and (string= val "x") (string-match "^x=" val))
      (setq val "x="))
     ((string-match "^\\$[\C-a-\C-z]" val)
      (setq val (concat "$^" (char-to-string (+ ?A -1 (aref val 1))))))
     ((string-match "^CORE::" val)
      (setq val "CORE::"))
     ((string-match "^SUPER::" val)
      (setq val "SUPER::"))
     ((and (string= "<" val) (string-match "^<\\$?[a-zA-Z0-9_:]+>" val))
      (setq val "<NAME>")))
    (setq regexp (concat "^"
			 "\\([^a-zA-Z0-9_:]+[ \t]+\\)?"
			 (regexp-quote val)
			 "\\([ \t([/]\\|$\\)"))

    ;; get the buffer with the documentation text
    (sane-perl-switch-to-doc-buffer)

    ;; lookup in the doc
    (goto-char (point-min))
    (let ((case-fold-search nil))
      (list
       (if (re-search-forward regexp (point-max) t)
	   (save-excursion
	     (beginning-of-line 1)
	     (let ((lnstart (point)))
	       (end-of-line)
	       (message "%s" (buffer-substring lnstart (point)))))
	 (if sane-perl-message-on-help-error
	     (message "No definition for %s" val)))))))

(defvar sane-perl-short-docs 'please-ignore-this-line
  "# based on \\='@(#)@ perl-descr.el 1.9 - describe-perl-symbol\\=' [Perl 5]
...	Range (list context); flip/flop [no flop when flip] (scalar context).
! ...	Logical negation.
... != ...	Numeric inequality.
... !~ ...	Search pattern, substitution, or translation (negated).
$!	In numeric context: errno.  In a string context: error string.
$\"	The separator which joins elements of arrays interpolated in strings.
$#	The output format for printed numbers.  Default is %.15g or close.
$$	Process number of this script.  Changes in the fork()ed child process.
$%	The current page number of the currently selected output channel.

	The following variables are always local to the current block:

$1	Match of the 1st set of parentheses in the last match (auto-local).
$2	Match of the 2nd set of parentheses in the last match (auto-local).
$3	Match of the 3rd set of parentheses in the last match (auto-local).
$4	Match of the 4th set of parentheses in the last match (auto-local).
$5	Match of the 5th set of parentheses in the last match (auto-local).
$6	Match of the 6th set of parentheses in the last match (auto-local).
$7	Match of the 7th set of parentheses in the last match (auto-local).
$8	Match of the 8th set of parentheses in the last match (auto-local).
$9	Match of the 9th set of parentheses in the last match (auto-local).
$&	The string matched by the last pattern match (auto-local).
$\\='	The string after what was matched by the last match (auto-local).
$\\=`	The string before what was matched by the last match (auto-local).

$(	The real gid of this process.
$)	The effective gid of this process.
$*	Deprecated: Set to 1 to do multiline matching within a string.
$+	The last bracket matched by the last search pattern.
$,	The output field separator for the print operator.
$-	The number of lines left on the page.
$.	The current input line number of the last filehandle that was read.
$/	The input record separator, newline by default.
$0	Name of the file containing the current perl script (read/write).
$:     String may be broken after these characters to fill ^-lines in a format.
$;	Subscript separator for multi-dim array emulation.  Default \"\\034\".
$<	The real uid of this process.
$=	The page length of the current output channel.  Default is 60 lines.
$>	The effective uid of this process.
$?	The status returned by the last \\=`\\=`, pipe close or `system'.
$@	The perl error message from the last eval or do @var{EXPR} command.
$ARGV	The name of the current file used with <> .
$[	Deprecated: The index of the first element/char in an array/string.
$\\	The output record separator for the print operator.
$]	The perl version string as displayed with perl -v.
$^	The name of the current top-of-page format.
$^A     The current value of the write() accumulator for format() lines.
$^D	The value of the perl debug (-D) flags.
$^E     Information about the last system error other than that provided by $!.
$^F	The highest system file descriptor, ordinarily 2.
$^H     The current set of syntax checks enabled by `use strict'.
$^I	The value of the in-place edit extension (perl -i option).
$^L     What formats output to perform a formfeed.  Default is \\f.
$^M     A buffer for emergency memory allocation when running out of memory.
$^O     The operating system name under which this copy of Perl was built.
$^P	Internal debugging flag.
$^T	The time the script was started.  Used by -A/-M/-C file tests.
$^W	True if warnings are requested (perl -w flag).
$^X	The name under which perl was invoked (argv[0] in C-speech).
$_	The default input and pattern-searching space.
$|	Auto-flush after write/print on current output channel?  Default 0.
$~	The name of the current report format.
... % ...	Modulo division.
... %= ...	Modulo division assignment.
%ENV	Contains the current environment.
%INC	List of files that have been require-d or do-ne.
%SIG	Used to set signal handlers for various signals.
... & ...	Bitwise and.
... && ...	Logical and.
... &&= ...	Logical and assignment.
... &= ...	Bitwise and assignment.
... * ...	Multiplication.
... ** ...	Exponentiation.
*NAME	Glob: all objects referred by NAME.  *NAM1 = *NAM2 aliases NAM1 to NAM2.
&NAME(arg0, ...)	Subroutine call.  Arguments go to @_.
... + ...	Addition.		+EXPR	Makes EXPR into scalar context.
++	Auto-increment (magical on strings).	++EXPR	EXPR++
... += ...	Addition assignment.
,	Comma operator.
... - ...	Subtraction.
--	Auto-decrement (NOT magical on strings).	--EXPR	EXPR--
... -= ...	Subtraction assignment.
-A	Access time in days since script started.
-B	File is a non-text (binary) file.
-C	Inode change time in days since script started.
-M	Age in days since script started.
-O	File is owned by real uid.
-R	File is readable by real uid.
-S	File is a socket .
-T	File is a text file.
-W	File is writable by real uid.
-X	File is executable by real uid.
-b	File is a block special file.
-c	File is a character special file.
-d	File is a directory.
-e	File exists .
-f	File is a plain file.
-g	File has setgid bit set.
-k	File has sticky bit set.
-l	File is a symbolic link.
-o	File is owned by effective uid.
-p	File is a named pipe (FIFO).
-r	File is readable by effective uid.
-s	File has non-zero size.
-t	Tests if filehandle (STDIN by default) is opened to a tty.
-u	File has setuid bit set.
-w	File is writable by effective uid.
-x	File is executable by effective uid.
-z	File has zero size.
.	Concatenate strings.
..	Range (list context); flip/flop (scalar context) operator.
.=	Concatenate assignment strings
... / ...	Division.	/PATTERN/ioxsmg	Pattern match
... /= ...	Division assignment.
/PATTERN/ioxsmg	Pattern match.
... < ...    Numeric less than.	<pattern>	Glob.	See <NAME>, <> as well.
<NAME>	Reads line from filehandle NAME (a bareword or dollar-bareword).
<pattern>	Glob (Unless pattern is bareword/dollar-bareword - see <NAME>).
<>	Reads line from union of files in @ARGV (= command line) and STDIN.
... << ...	Bitwise shift left.	<<	start of HERE-DOCUMENT.
... <= ...	Numeric less than or equal to.
... <=> ...	Numeric compare.
... = ...	Assignment.
... == ...	Numeric equality.
... =~ ...	Search pattern, substitution, or translation
... ~~ ..       Smart match
... > ...	Numeric greater than.
... >= ...	Numeric greater than or equal to.
... >> ...	Bitwise shift right.
... >>= ...	Bitwise shift right assignment.
... ? ... : ...	Condition=if-then-else operator.   ?PAT? One-time pattern match.
?PATTERN?	One-time pattern match.
@ARGV	Command line arguments (not including the command name - see $0).
@INC	List of places to look for perl scripts during do/include/use.
@_    Parameter array for subroutines; result of split() unless in list context.
\\  Creates reference to what follows, like \\$var, or quotes non-\\w in strings.
\\0	Octal char, e.g. \\033.
\\E	Case modification terminator.  See \\Q, \\L, and \\U.
\\L	Lowercase until \\E .  See also \\l, lc.
\\U	Upcase until \\E .  See also \\u, uc.
\\Q	Quote metacharacters until \\E .  See also quotemeta.
\\a	Alarm character (octal 007).
\\b	Backspace character (octal 010).
\\c	Control character, e.g. \\c[ .
\\e	Escape character (octal 033).
\\f	Formfeed character (octal 014).
\\l	Lowercase the next character.  See also \\L and \\u, lcfirst.
\\n	Newline character (octal 012 on most systems).
\\r	Return character (octal 015 on most systems).
\\t	Tab character (octal 011).
\\u	Upcase the next character.  See also \\U and \\l, ucfirst.
\\x	Hex character, e.g. \\x1b.
... ^ ...	Bitwise exclusive or.
__END__	Ends program source.
__DATA__	Ends program source.
__FILE__	Current (source) filename.
__LINE__	Current line in current source.
__PACKAGE__	Current package.
ARGV	Default multi-file input filehandle.  <ARGV> is a synonym for <>.
ARGVOUT	Output filehandle with -i flag.
BEGIN { ... }	Immediately executed (during compilation) piece of code.
END { ... }	Pseudo-subroutine executed after the script finishes.
CHECK { ... }	Pseudo-subroutine executed after the script is compiled.
UNITCHECK { ... }
INIT { ... }	Pseudo-subroutine executed before the script starts running.
DATA	Input filehandle for what follows after __END__	or __DATA__.
accept(NEWSOCKET,GENERICSOCKET)
alarm(SECONDS)
atan2(X,Y)   Arctangent of y/x in the range [-pi, +pi]
bind(SOCKET,NAME)
binmode FILEHANDLE [, LAYER]   Set binary or text mode; LAYER for directives
break	Break out of a given/when statement
caller[(LEVEL)]
chdir(EXPR)  Change the working directory
chmod(LIST)  Change the permissions of a list of files
chop[(LIST|VAR)]
chown(LIST)
chroot(FILENAME)
close(FILEHANDLE)
closedir(DIRHANDLE)
... cmp ...	String compare.
connect(SOCKET,NAME)
continue of { block } continue { block }.  Is executed after `next' or at end.
cos(EXPR)
crypt(PLAINTEXT,SALT)
dbmclose(%HASH)
dbmopen(%HASH,DBNAME,MODE)
default { ... } default case for given/when block
defined(EXPR)
delete($HASH{KEY})
die(LIST)
do { ... }|SUBR while|until EXPR	executes at least once
do(EXPR|SUBR([LIST]))	(with while|until executes at least once)
dump LABEL
each(%HASH)
endgrent
endhostent
endnetent
endprotoent
endpwent
endservent
eof[([FILEHANDLE])]
... eq ...	String equality.
eval(EXPR) or eval { BLOCK }
evalbytes   See eval.
exec([TRUENAME] ARGV0, ARGVs)     or     exec(SHELL_COMMAND_LINE)
exit(EXPR)
exp(EXPR)
fcntl(FILEHANDLE,FUNCTION,SCALAR)
fileno(FILEHANDLE)
flock(FILEHANDLE,OPERATION)
for (EXPR;EXPR;EXPR) { ... }
foreach [VAR] (@ARRAY) { ... }
fork
... ge ...	String greater than or equal.
getc[(FILEHANDLE)]
getgrent
getgrgid(GID)
getgrnam(NAME)
gethostbyaddr(ADDR,ADDRTYPE)
gethostbyname(NAME)
gethostent
getlogin
getnetbyaddr(ADDR,ADDRTYPE)
getnetbyname(NAME)
getnetent
getpeername(SOCKET)
getpgrp(PID)
getppid
getpriority(WHICH,WHO)
getprotobyname(NAME)
getprotobynumber(NUMBER)
getprotoent
getpwent
getpwnam(NAME)
getpwuid(UID)
getservbyname(NAME,PROTO)
getservbyport(PORT,PROTO)
getservent
getsockname(SOCKET)
getsockopt(SOCKET,LEVEL,OPTNAME)
given (EXPR) { [ when (EXPR) { ... } ]+ [ default { ... } ]? }
gmtime(EXPR)    
goto LABEL
... gt ...	String greater than.
hex(EXPR)       Convert from hexadecimal
if (EXPR) { ... } [ elsif (EXPR) { ... } ... ] [ else { ... } ] or EXPR if EXPR
index(STR,SUBSTR[,OFFSET])
int(EXPR)         Integer part of EXPR
ioctl(FILEHANDLE,FUNCTION,SCALAR)
join(EXPR,LIST)      Join LIST with EXPR and return the resulting string
keys(%HASH)
kill(LIST)
last [LABEL]
... le ...	String less than or equal.
length(EXPR)
link(OLDFILE,NEWFILE)
listen(SOCKET,QUEUESIZE)
local(LIST)
localtime(EXPR)
log(EXPR)
lstat(EXPR|FILEHANDLE|VAR)
... lt ...	String less than.
m/PATTERN/iogsmx
mkdir(FILENAME,MODE)
msgctl(ID,CMD,ARG)
msgget(KEY,FLAGS)
msgrcv(ID,VAR,SIZE,TYPE.FLAGS)
msgsnd(ID,MSG,FLAGS)
my VAR or my (VAR1,...)	Introduces a lexical variable ($VAR, @ARR, or %HASH).
our VAR or our (VAR1,...) Lexically enable a global variable ($V, @A, or %H).
... ne ...	String inequality.
next [LABEL]
oct(EXPR)   Interpret EXPR as an octal string
open(FILEHANDLE[,EXPR])
opendir(DIRHANDLE,EXPR)
ord(EXPR)	ASCII value of the first char of the string.
pack(TEMPLATE,LIST)
package NAME	Introduces package context.
pipe(READHANDLE,WRITEHANDLE)	Create a pair of filehandles on ends of a pipe.
pop(ARRAY)        Remove last element from array
print [FILEHANDLE] [(LIST)]       Print
printf [FILEHANDLE] (FORMAT,LIST)  Print formatted
push(ARRAY,LIST)     Push LIST into ARRAY
q/STRING/	Synonym for \\='STRING\\='
qq/STRING/	Synonym for \"STRING\"
qx/STRING/	Synonym for \\=`STRING\\=`
rand[(EXPR)]    Returns a random number between 0 and 1
read(FILEHANDLE,SCALAR,LENGTH[,OFFSET])
readdir(DIRHANDLE)
readlink(EXPR)
recv(SOCKET,SCALAR,LEN,FLAGS)
redo [LABEL]
rename(OLDNAME,NEWNAME)  Change a file's name
require [FILENAME | PERL_VERSION]
reset[(EXPR)]
return(LIST)    Return from a subroutine
reverse(LIST)    Returns the list in reverse order
rewinddir(DIRHANDLE)
rindex(STR,SUBSTR[,OFFSET])
rmdir(FILENAME)    Remove a directory
s/PATTERN/REPLACEMENT/gieoxsm   Substitute PATTERN with REPLACEMENT
say [FILEHANDLE] [(LIST)]
scalar(EXPR)    Convert an array or hash into a scalar
seek(FILEHANDLE,POSITION,WHENCE)
seekdir(DIRHANDLE,POS)
select(FILEHANDLE | RBITS,WBITS,EBITS,TIMEOUT)
semctl(ID,SEMNUM,CMD,ARG)
semget(KEY,NSEMS,SIZE,FLAGS)
semop(KEY,...)
send(SOCKET,MSG,FLAGS[,TO])
setgrent
sethostent(STAYOPEN)
setnetent(STAYOPEN)
setpgrp(PID,PGRP)
setpriority(WHICH,WHO,PRIORITY)
setprotoent(STAYOPEN)
setpwent
setservent(STAYOPEN)
setsockopt(SOCKET,LEVEL,OPTNAME,OPTVAL)
shift[(ARRAY)]
shmctl(ID,CMD,ARG)
shmget(KEY,SIZE,FLAGS)
shmread(ID,VAR,POS,SIZE)
shmwrite(ID,STRING,POS,SIZE)
shutdown(SOCKET,HOW)
sin(EXPR)    Sine
sleep[(EXPR)]
socket(SOCKET,DOMAIN,TYPE,PROTOCOL)
socketpair(SOCKET1,SOCKET2,DOMAIN,TYPE,PROTOCOL)
sort [SUBROUTINE] (LIST)
splice(ARRAY,OFFSET[,LENGTH[,LIST]])
split[(/PATTERN/[,EXPR[,LIMIT]])]
sprintf(FORMAT,LIST)
sqrt(EXPR)   Square root
srand(EXPR)  Seed the random number generator
stat(EXPR|FILEHANDLE|VAR)
state VAR or state (VAR1,...)	Introduces a static lexical variable
study[(SCALAR)]
sub [NAME [(format)]] { BODY }	sub NAME [(format)];	sub [(format)] {...}
substr(EXPR,OFFSET[,LEN])
symlink(OLDFILE,NEWFILE)
syscall(LIST)
sysread(FILEHANDLE,SCALAR,LENGTH[,OFFSET])
system([TRUENAME] ARGV0 [,ARGV])     or     system(SHELL_COMMAND_LINE)
syswrite(FILEHANDLE,SCALAR,LENGTH[,OFFSET])
tell[(FILEHANDLE)]
telldir(DIRHANDLE)
time
times
tr/SEARCHLIST/REPLACEMENTLIST/cds
truncate(FILE|EXPR,LENGTH)
umask[(EXPR)]
undef[(EXPR)]
unless (EXPR) { ... } [ else { ... } ] or EXPR unless EXPR
unlink(LIST)
unpack(TEMPLATE,EXPR)
unshift(ARRAY,LIST)
until (EXPR) { ... }					EXPR until EXPR
utime(LIST)
values(%HASH)
vec(EXPR,OFFSET,BITS)
wait
waitpid(PID,FLAGS)
wantarray	Returns true if the sub/eval is called in list context.
warn(LIST)
while  (EXPR) { ... }					EXPR while EXPR
write[(EXPR|FILEHANDLE)]
... x ...	Repeat string or array.
x= ...	Repetition assignment.
y/SEARCHLIST/REPLACEMENTLIST/
... | ...	Bitwise or.
... || ...	Logical or.
... // ...      Defined-or.
~ ...		Unary bitwise complement.
#!	OS interpreter indicator.  If contains `perl', used for options, and -x.
AUTOLOAD {...}	Shorthand for `sub AUTOLOAD {...}'.
CORE::		Prefix to access builtin function if imported sub obscures it.
SUPER::		Prefix to lookup for a method in @ISA classes.
DESTROY		Shorthand for `sub DESTROY {...}'.
... EQ ...	Obsolete synonym of `eq'.
... GE ...	Obsolete synonym of `ge'.
... GT ...	Obsolete synonym of `gt'.
... LE ...	Obsolete synonym of `le'.
... LT ...	Obsolete synonym of `lt'.
... NE ...	Obsolete synonym of `ne'.
abs [ EXPR ]	absolute value
... and ...		Low-precedence synonym for &&.
bless REFERENCE [, PACKAGE]	Makes reference into an object of a package.
chomp [LIST]	Strips $/ off LIST/$_.  Returns count.  Special if $/ eq \\='\\='!
chr		Converts a number to a character with the same ordinal.
else		Part of if/unless {BLOCK} elsif {BLOCK} else {BLOCK}.
elsif		Part of if/unless {BLOCK} elsif {BLOCK} else {BLOCK}.
exists $HASH{KEY}	True if the key exists, even if not defined.
fc EXPR    Returns the casefolded version of EXPR.
format [NAME] =	 Start of output format.  Ended by a single dot (.) on a line.
formline PICTURE, LIST	Backdoor into \"format\" processing.
glob EXPR	Synonym of <EXPR>.
lc [ EXPR ]	Returns lowercased EXPR.
lcfirst [ EXPR ]	Returns EXPR with lower-cased first letter.
grep EXPR,LIST  or grep {BLOCK} LIST	Filters LIST via EXPR/BLOCK.
map EXPR, LIST	or map {BLOCK} LIST	Applies EXPR/BLOCK to elts of LIST.
no PACKAGE [SYMBOL1, ...]  Partial reverse for `use'.  Runs `unimport' method.
not ...		Low-precedence synonym for ! - negation.
... or ...		Low-precedence synonym for ||.
pos STRING    Set/get end-position of the last match over this string, see \\G.
prototype FUNC   Returns the prototype of a function as a string, or undef.
quotemeta [ EXPR ]	Quote regexp metacharacters.
qw/WORD1 .../		Whitespace separated list
readline FH	Synonym of <FH>.
readpipe CMD	Synonym of \\=`CMD\\=`.
ref [ EXPR ]	Type of EXPR when dereferenced.
sysopen FH, FILENAME, MODE [, PERM]	(MODE is numeric, see Fcntl.)
tie VAR, PACKAGE, LIST	Hide an object behind a simple Perl variable.
tied		Returns internal object for a tied data.
uc [ EXPR ]	Returns upcased EXPR.
ucfirst [ EXPR ]	Returns EXPR with upcased first letter.
untie VAR	Unlink an object from a simple Perl variable.
use PACKAGE [SYMBOL1, ...]  Compile-time `require' with consequent `import'.
... xor ...		Low-precedence synonym for exclusive or.
prototype \\&SUB	Returns prototype of the function given a reference.
=head1		Top-level heading.
=head2		Second-level heading.
=head3		Third-level heading.
=head4          Fourth-level heading.
=over [ NUMBER ]	Start list.
=item [ TITLE ]		Start new item in the list.
=back		End list.
=cut		Switch from POD to Perl.
=pod		Switch from Perl to POD.
=begin [ FORMAT ]	 Switch from POD to FORMAT (e.g. HTML).
=end [ FORMAT ]	         Switch from FORMAT to POD.
=for [ FORMAT ]	STMT     Put STMT into FORMAT.
=encoding [ ENC ]   Set the encoding of the POD.
")

(defun sane-perl-switch-to-doc-buffer (&optional interactive)
  "Go to the perl documentation buffer and insert the documentation."
  (interactive "p")
  (let ((buf (get-buffer-create sane-perl-doc-buffer)))
    (if interactive
	(switch-to-buffer-other-window buf)
      (set-buffer buf))
    (if (= (buffer-size) 0)
	(progn
	  (insert (documentation-property 'sane-perl-short-docs
					  'variable-documentation))
	  (setq buffer-read-only t)))))

(defun sane-perl-beautify-regexp-piece (b e embed level)
  ;; b is before the starting delimiter, e before the ending
  ;; e should be a marker, may be changed, but remains "correct".
  ;; EMBED is nil if we process the whole REx.
  ;; The REx is guaranteed to have //x
  ;; LEVEL shows how many levels deep to go
  ;; position at enter and at leave is not defined
  (let (s c tmp (m (make-marker)) (m1 (make-marker)) c1 spaces inline pos)
    (if embed
	(progn
	  (goto-char b)
	  (setq c (if (eq embed t) (current-indentation) (current-column)))
	  (cond ((looking-at "(\\?\\\\#") ; (?#) wrongly commented when //x-ing
		 (forward-char 2)
		 (delete-char 1)
		 (forward-char 1))
		((looking-at "(\\?[^a-zA-Z]")
		 (forward-char 3))
		((looking-at "(\\?")	; (?i)
		 (forward-char 2))
		(t
		 (forward-char 1))))
      (goto-char (1+ b))
      (setq c (1- (current-column))))
    (setq c1 (+ c (or sane-perl-regexp-indent-step sane-perl-indent-level)))
    (or (looking-at "[ \t]*[\n#]")
	(progn
	  (insert "\n")))
    (goto-char e)
    (beginning-of-line)
    (if (re-search-forward "[^ \t]" e t)
	(progn			       ; Something before the ending delimiter
	  (goto-char e)
	  (delete-horizontal-space)
	  (insert "\n")
	  (sane-perl-make-indent c)
	  (set-marker e (point))))
    (goto-char b)
    (end-of-line 2)
    (while (< (point) (marker-position e))
      (beginning-of-line)
      (setq s (point)
	    inline t)
      (skip-chars-forward " \t")
      (delete-region s (point))
      (sane-perl-make-indent c1)
      (while (and
	      inline
	      (looking-at
	       (concat "\\([a-zA-Z0-9]+[^*+{?]\\)" ; 1 word
		       "\\|"		; Embedded variable
		       "\\$\\([a-zA-Z0-9_]+\\([[{]\\)?\\|[^\n \t)|]\\)" ; 2 3
		       "\\|"		; $ ^
		       "[$^]"
		       "\\|"		; simple-code simple-code*?
		       "\\(\\\\.\\|[^][()#|*+?$^\n]\\)\\([*+{?]\\??\\)?" ; 4 5
		       "\\|"		; Class
		       "\\(\\[\\)"	; 6
		       "\\|"		; Grouping
		       "\\((\\(\\?\\)?\\)" ; 7 8
		       "\\|"		; |
		       "\\(|\\)")))	; 9
	(goto-char (match-end 0))
	(setq spaces t)
	(cond ((match-beginning 1)	; Alphanum word + junk
	       (forward-char -1))
	      ((or (match-beginning 3)	; $ab[12]
		   (and (match-beginning 5) ; X* X+ X{2,3}
			(eq (preceding-char) ?\{)))
	       (forward-char -1)
	       (forward-sexp 1))
	      ((and			; [], already syntaxified
		(match-beginning 6)
		sane-perl-regexp-scan
		sane-perl-use-syntax-table-text-property)
	       (forward-char -1)
	       (forward-sexp 1)
	       (or (eq (preceding-char) ?\])
		   (error "[]-group not terminated"))
	       (re-search-forward
		"\\=\\([*+?]\\|{[0-9]+\\(,[0-9]*\\)?}\\)\\??" e t))
	      ((match-beginning 6)	; []
	       (setq tmp (point))
	       (if (looking-at "\\^?\\]")
		   (goto-char (match-end 0)))
	       ;; XXXX POSIX classes?!
	       (while (and (not pos)
			   (re-search-forward "\\[:\\|\\]" e t))
		 (if (eq (preceding-char) ?:)
		     (or (re-search-forward ":\\]" e t)
			 (error "[:POSIX:]-group in []-group not terminated"))
		   (setq pos t)))
	       (or (eq (preceding-char) ?\])
		   (error "[]-group not terminated"))
	       (re-search-forward
		"\\=\\([*+?]\\|{[0-9]+\\(,[0-9]*\\)?}\\)\\??" e t))
	      ((match-beginning 7)	; ()
	       (goto-char (match-beginning 0))
	       (setq pos (current-column))
	       (or (eq pos c1)
		   (progn
		     (delete-horizontal-space)
		     (insert "\n")
		     (sane-perl-make-indent c1)))
	       (setq tmp (point))
	       (forward-sexp 1)
	       ;;	       (or (forward-sexp 1)
	       ;;		   (progn
	       ;;		     (goto-char tmp)
	       ;;		     (error "()-group not terminated")))
	       (set-marker m (1- (point)))
	       (set-marker m1 (point))
	       (if (= level 1)
		   (if (progn		; indent rigidly if multiline
			 ;; In fact does not make a lot of sense, since
			 ;; the starting position can be already lost due
			 ;; to insertion of "\n" and " "
			 (goto-char tmp)
			 (search-forward "\n" m1 t))
		       (indent-rigidly (point) m1 (- c1 pos)))
		 (setq level (1- level))
		 (cond
		  ((not (match-beginning 8))
		   (sane-perl-beautify-regexp-piece tmp m t level))
		  ((eq (char-after (+ 2 tmp)) ?\{) ; Code
		   t)
		  ((eq (char-after (+ 2 tmp)) ?\() ; Conditional
		   (goto-char (+ 2 tmp))
		   (forward-sexp 1)
		   (sane-perl-beautify-regexp-piece (point) m t level))
		  ((eq (char-after (+ 2 tmp)) ?<) ; Lookbehind
		   (goto-char (+ 3 tmp))
		   (sane-perl-beautify-regexp-piece (point) m t level))
		  (t
		   (sane-perl-beautify-regexp-piece tmp m t level))))
	       (goto-char m1)
	       (cond ((looking-at "[*+?]\\??")
		      (goto-char (match-end 0)))
		     ((eq (following-char) ?\{)
		      (forward-sexp 1)
		      (if (eq (following-char) ?\?)
			  (forward-char))))
	       (skip-chars-forward " \t")
	       (setq spaces nil)
	       (if (looking-at "[#\n]")
		   (progn
		     (or (eolp) (indent-for-comment))
		     (beginning-of-line 2))
		 (delete-horizontal-space)
		 (insert "\n"))
	       (end-of-line)
	       (setq inline nil))
	      ((match-beginning 9)	; |
	       (forward-char -1)
	       (setq tmp (point))
	       (beginning-of-line)
	       (if (re-search-forward "[^ \t]" tmp t)
		   (progn
		     (goto-char tmp)
		     (delete-horizontal-space)
		     (insert "\n"))
		 ;; first at line
		 (delete-region (point) tmp))
	       (sane-perl-make-indent c)
	       (forward-char 1)
	       (skip-chars-forward " \t")
	       (setq spaces nil)
	       (if (looking-at "[#\n]")
		   (beginning-of-line 2)
		 (delete-horizontal-space)
		 (insert "\n"))
	       (end-of-line)
	       (setq inline nil)))
	(or (looking-at "[ \t\n]")
	    (not spaces)
	    (insert " "))
	(skip-chars-forward " \t"))
      (or (looking-at "[#\n]")
	  (error "Unknown code `%s' in a regexp"
		 (buffer-substring (point) (1+ (point)))))
      (and inline (end-of-line 2)))
    ;; Special-case the last line of group
    (if (and (>= (point) (marker-position e))
	     (/= (current-indentation) c))
	(progn
	  (beginning-of-line)
	  (sane-perl-make-indent c)))))

(defun sane-perl-make-regexp-x ()
  ;; Returns position of the start
  (save-excursion
    (or sane-perl-use-syntax-table-text-property
	(error "I need to have a regexp marked!"))
    ;; Find the start
    (if (looking-at "\\s|")
	nil				; good already
      (if (or (looking-at "\\([smy]\\|qr\\)\\s|")
	      (and (eq (preceding-char) ?q)
		   (looking-at "\\(r\\)\\s|")))
	  (goto-char (match-end 1))
	(re-search-backward "\\s|")))	; Assume it is scanned already.
    (let ((b (point)) (e (make-marker)) have-x delim
	  (sub-p (eq (preceding-char) ?s)))
      (forward-sexp 1)
      (set-marker e (1- (point)))
      (setq delim (preceding-char))
      (if (and sub-p (eq delim (char-after (- (point) 2))))
	  (error "Possible s/blah// - do not know how to deal with"))
      (if sub-p (forward-sexp 1))
      (if (looking-at "\\sw*x")
	  (setq have-x t)
	(insert "x"))
      ;; Protect fragile " ", "#"
      (if have-x nil
	(goto-char (1+ b))
	(while (re-search-forward "\\(\\=\\|[^\\]\\)\\(\\\\\\\\\\)*[ \t\n#]" e t) 
	  (forward-char -1)
	  (insert "\\")
	  (forward-char 1)))
      b)))

(defun sane-perl-beautify-regexp (&optional deep)
  "Do it.  (Experimental, may change semantics, recheck the result.)
We suppose that the regexp is scanned already."
  (interactive "P")
  (setq deep (if deep (prefix-numeric-value deep) -1))
  (save-excursion
    (goto-char (sane-perl-make-regexp-x))
    (let ((b (point)) (e (make-marker)))
      (forward-sexp 1)
      (set-marker e (1- (point)))
      (sane-perl-beautify-regexp-piece b e nil deep))))

(defun sane-perl-regext-to-level-start ()
  "Goto start of an enclosing group in regexp.
We suppose that the regexp is scanned already."
  (interactive)
  (let ((limit (sane-perl-make-regexp-x)) done)
    (while (not done)
      (or (eq (following-char) ?\()
	  (search-backward "(" (1+ limit) t)
	  (error "Cannot find `(' which starts a group"))
      (setq done
	    (save-excursion
	      (skip-chars-backward "\\\\")
	      (looking-at "\\(\\\\\\\\\\)*(")))
      (or done (forward-char -1)))))

(defun sane-perl-contract-level ()
  "Find an enclosing group in regexp and contract it.
\(Experimental, may change semantics, recheck the result.)
We suppose that the regexp is scanned already."
  (interactive)
  ;; (save-excursion		; Can't, breaks `sane-perl-contract-levels'
  (sane-perl-regext-to-level-start)
  (let ((b (point)) (e (make-marker)) c)
    (forward-sexp 1)
    (set-marker e (1- (point)))
    (goto-char b)
    (while (re-search-forward "\\(#\\)\\|\n" e 'to-end)
      (cond
       ((match-beginning 1)		; #-comment
	(or c (setq c (current-indentation)))
	(beginning-of-line 2)		; Skip
	(sane-perl-make-indent c))
       (t
	(delete-char -1)
	(just-one-space))))))

(defun sane-perl-contract-levels ()
  "Find an enclosing group in regexp and contract all the kids.
\(Experimental, may change semantics, recheck the result.)
We suppose that the regexp is scanned already."
  (interactive)
  (save-excursion
    (condition-case nil
	(sane-perl-regext-to-level-start)
      (error				; We are outside outermost group
       (goto-char (sane-perl-make-regexp-x))))
    (let ((b (point)) (e (make-marker)))
      (forward-sexp 1)
      (set-marker e (1- (point)))
      (goto-char (1+ b))
      (while (re-search-forward "\\(\\\\\\\\\\)\\|(" e t)
	(cond
	 ((match-beginning 1)		; Skip
	  nil)
	 (t				; Group
	  (sane-perl-contract-level)))))))

(defun sane-perl-beautify-level (&optional deep)
  "Find an enclosing group in regexp and beautify it.
\(Experimental, may change semantics, recheck the result.)
We suppose that the regexp is scanned already."
  (interactive "P")
  (setq deep (if deep (prefix-numeric-value deep) -1))
  (save-excursion
    (sane-perl-regext-to-level-start)
    (let ((b (point)) (e (make-marker)))
      (forward-sexp 1)
      (set-marker e (1- (point)))
      (sane-perl-beautify-regexp-piece b e 'level deep))))

(defun sane-perl-invert-if-unless-modifiers ()
  "Change `B if A;' into `if (A) {B}' etc if possible.
\(Unfinished.)"
  (interactive)
  (let (A B pre-B post-B pre-if post-if pre-A post-A if-string
	  (w-rex "\\<\\(if\\|unless\\|while\\|until\\|for\\|foreach\\)\\>"))
    (and (= (char-syntax (preceding-char)) ?w)
	 (forward-sexp -1))
    (setq pre-if (point))
    (sane-perl-backward-to-start-of-expr)
    (setq pre-B (point))
    (forward-sexp 1)		; otherwise forward-to-end-of-expr is NOP
    (sane-perl-forward-to-end-of-expr)
    (setq post-A (point))
    (goto-char pre-if)
    (or (looking-at w-rex)
	;; Find the position
	(progn (goto-char post-A)
	       (while (and
		       (not (looking-at w-rex))
		       (> (point) pre-B))
		 (forward-sexp -1))
	       (setq pre-if (point))))
    (or (looking-at w-rex)
	(error "Can't find `if', `unless', `while', `until', `for' or `foreach'"))
    ;; 1 B 2 ... 3 B-com ... 4 if 5 ... if-com 6 ... 7 A 8
    (setq if-string (buffer-substring (match-beginning 0) (match-end 0)))
    ;; First, simple part: find code boundaries
    (forward-sexp 1)
    (setq post-if (point))
    (forward-sexp -2)
    (forward-sexp 1)
    (setq post-B (point))
    (sane-perl-backward-to-start-of-expr)
    (setq pre-B (point))
    (setq B (buffer-substring pre-B post-B))
    (goto-char pre-if)
    (forward-sexp 2)
    (forward-sexp -1)
    ;; May be after $, @, $# etc of a variable
    (skip-chars-backward "$@%#")
    (setq pre-A (point))
    (sane-perl-forward-to-end-of-expr)
    (setq post-A (point))
    (setq A (buffer-substring pre-A post-A))
    ;; Now modify (from end, to not break the stuff)
    (skip-chars-forward " \t;")
    (delete-region pre-A (point))	; we move to pre-A
    (insert "\n" B ";\n}")
    (and (looking-at "[ \t]*#") (sane-perl-indent-for-comment))
    (delete-region pre-if post-if)
    (delete-region pre-B post-B)
    (goto-char pre-B)
    (if (string-match "^(.*)$" A)
	(insert if-string " " A " {")
      (insert if-string " (" A ") {"))
    (setq post-B (point))
    (if (looking-at "[ \t]+$")
	(delete-horizontal-space)
      (if (looking-at "[ \t]*#")
	  (sane-perl-indent-for-comment)
	(just-one-space)))
    (forward-line 1)
    (if (looking-at "[ \t]*$")
	(progn				; delete line
	  (delete-horizontal-space)
	  (delete-region (point) (1+ (point)))))
    (sane-perl-indent-line)
    (goto-char (1- post-B))
    (forward-sexp 1)
    (sane-perl-indent-line)
    (goto-char pre-B)))

(defun sane-perl-invert-if-unless ()
  "Change `if (A) {B}' into `B if A;' etc (or visa versa) if possible.
If the cursor is not on the leading keyword of the BLOCK flavor of
construct, will assume it is the STATEMENT flavor, so will try to find
the appropriate statement modifier."
  (interactive)
  (and (= (char-syntax (preceding-char)) ?w)
       (forward-sexp -1))
  (if (looking-at "\\<\\(if\\|unless\\|while\\|until\\|for\\|foreach\\)\\>")
      (let ((pre-if (point))
	    pre-A post-A pre-B post-B A B state p end-B-code is-block B-comment
	    (if-string (buffer-substring (match-beginning 0) (match-end 0))))
	(forward-sexp 2)
	(setq post-A (point))
	(forward-sexp -1)
	(setq pre-A (point))
	(setq is-block (and (eq (following-char) ?\( )
			    (save-excursion
			      (condition-case nil
				  (progn
				    (forward-sexp 2)
				    (forward-sexp -1)
				    (eq (following-char) ?\{ ))
				(error nil)))))
	(if is-block
	    (progn
	      (goto-char post-A)
	      (forward-sexp 1)
	      (setq post-B (point))
	      (forward-sexp -1)
	      (setq pre-B (point))
	      (if (and (eq (following-char) ?\{ )
		       (progn
			 (sane-perl-backward-to-noncomment post-A)
			 (eq (preceding-char) ?\) )))
		  (if (condition-case nil
			  (progn
			    (goto-char post-B)
			    (forward-sexp 1)
			    (forward-sexp -1)
			    (looking-at "\\<els\\(e\\|if\\)\\>"))
			(error nil))
		      (error
		       "`%s' (EXPR) {BLOCK} with `else'/`elsif'" if-string)
		    (goto-char (1- post-B))
		    (sane-perl-backward-to-noncomment pre-B)
		    (if (eq (preceding-char) ?\;)
			(forward-char -1))
		    (setq end-B-code (point))
		    (goto-char pre-B)
		    (while (re-search-forward "\\<\\(for\\|foreach\\|if\\|unless\\|while\\|until\\)\\>\\|;" end-B-code t)
		      (setq p (match-beginning 0)
			    A (buffer-substring p (match-end 0))
			    state (parse-partial-sexp pre-B p))
		      (or (nth 3 state)
			  (nth 4 state)
			  (nth 5 state)
			  (error "`%s' inside `%s' BLOCK" A if-string))
		      (goto-char (match-end 0)))
		    ;; Finally got it
		    (goto-char (1+ pre-B))
		    (skip-chars-forward " \t\n")
		    (setq B (buffer-substring (point) end-B-code))
		    (goto-char end-B-code)
		    (or (looking-at ";?[ \t\n]*}")
			(progn
			  (skip-chars-forward "; \t\n")
			  (setq B-comment
				(buffer-substring (point) (1- post-B)))))
		    (and (equal B "")
			 (setq B "1"))
		    (goto-char (1- post-A))
		    (sane-perl-backward-to-noncomment pre-A)
		    (or (looking-at "[ \t\n]*)")
			(goto-char (1- post-A)))
		    (setq p (point))
		    (goto-char (1+ pre-A))
		    (skip-chars-forward " \t\n")
		    (setq A (buffer-substring (point) p))
		    (delete-region pre-B post-B)
		    (delete-region pre-A post-A)
		    (goto-char pre-if)
		    (insert B " ")
		    (and B-comment (insert B-comment " "))
		    (just-one-space)
		    (forward-word-strictly 1)
		    (setq pre-A (point))
		    (insert " " A ";")
		    (delete-horizontal-space)
		    (setq post-B (point))
		    (if (looking-at "#")
			(indent-for-comment))
		    (goto-char post-B)
		    (forward-char -1)
		    (delete-horizontal-space)
		    (goto-char pre-A)
		    (just-one-space)
		    (goto-char pre-if)
		    (setq pre-A (set-marker (make-marker) pre-A))
		    (while (<= (point) (marker-position pre-A))
		      (sane-perl-indent-line)
		      (forward-line 1))
		    (goto-char (marker-position pre-A))
		    (if B-comment
			(progn
			  (forward-line -1)
			  (indent-for-comment)
			  (goto-char (marker-position pre-A)))))
		(error "`%s' (EXPR) not with an {BLOCK}" if-string)))
	  (forward-sexp -1)
	  (sane-perl-invert-if-unless-modifiers)))
    (sane-perl-invert-if-unless-modifiers)))

(declare-function Man-getpage-in-background "man" (topic))

(declare-function shr-browse-url "shr" ())
(declare-function shr-render-buffer "shr" (buffer))

(defun sane-perl--perldoc-goto-section (section)
  "Find SECTION in the current buffer.
There is no precise indicator for SECTION in shr-generated
buffers, so this function is using some fuzzy regexp matching
which takes into account that the perldoc/pod2html workflow has
no clear specification what makes a section."
  (goto-char (point-min))
  ;; Here's a workaround for a misunderstanding between pod2html and
  ;; shr: pod2html converts a section like "/__SUB__" to a fragment
  ;; "#SUB__".  The shr renderer doesn't pick id elements in its
  ;; character properties, so we need to sloppily allow leading "__"
  ;; before looking for the text of the heading.
  (let ((target-re (replace-regexp-in-string "-" "." section))
	(prefix "^\\(__\\)?")
	(suffix "\\([[:blank:]]\\|$\\)"))
    (if (re-search-forward (concat prefix target-re suffix) nil t)
	(goto-char (line-beginning-position))
      (message "Warning: No section '%s' found." section))))

(defun sane-perl-perldoc-browse-url ()
  "Browse the URL at point, using either perldoc or `shr-browse-url'.
If the URL at point starts with a \"perldoc\" schema, then run
either sane-perl-perldoc, or produce a man-page if the URL is of the
type \"topic(section)\".  If it is a local fragment, just search
for it in the current buffer.  For URLs with a schema, run
browse-url."
  (interactive)
  (require 'shr)
  (let ((url (get-text-property (point) 'shr-url)))
    (when url
      (cond
       ((string-match (concat "^perldoc://"	; our scheme
				"\\(?:\\(?1:[^/]*\\)"   ; 1: page, may be empty
				"\\(?:#\\|/\\)"      ; section separator
				"\\(?2:.+\\)" ; "/" + 2: nonzero section
				"\\|"		; or
				"\\(?1:[^/]+\\)\\)$")   ; 1: just a page
			url)
	  ;; link to be handled by sane-perl-perldoc
	(let ((page   (match-string 1 url))
	      (section (match-string 2 url)))
	  (if (> (length page) 0)
	      (if (null (string-match "([1-9])$" page))
		  (sane-perl-perldoc page section))
	    (when section
	      (sane-perl--perldoc-goto-section section)))))
       ((string-match "^#\\(.+\\)" url)
	;; local section created by pod2html
	(if (boundp 'sane-perl-perldoc-base)
	    (sane-perl-perldoc sane-perl-perldoc-base
			   (match-string-no-properties 1 url))
	(sane-perl--perldoc-goto-section (match-string-no-properties 1 url))))
       (t
	(shr-browse-url))))))

(defvar sane-perl-perldoc-shr-map
  (let ((map (make-sparse-keymap)))
    (define-key map [?\t] 'shr-next-link)
    (define-key map [?\M-\t] 'shr-previous-link)
    (define-key map [follow-link] 'mouse-face)
    (define-key map [mouse-2] 'sane-perl-perldoc-browse-url)
    (define-key map "\r" 'sane-perl-perldoc-browse-url)
    (define-key map "q" 'bury-buffer)
    (define-key map (kbd "SPC") 'scroll-up-command)
    map)
  "A keymap to allow following links in perldoc buffers.")

(defun sane-perl--pod-process-links ()
  "This converts the links in the pod document so that they work
as part of the Emacs help buffer. Find the next link in a POD
section, and process it."
  ;; Note: Processing links can't be done with syntax tables by using
  ;; <> as a bracket pair because links can contain unbalanced < or >
  ;; symbols.  So do it the hard way....
  (goto-char (point-min))
  ;; Links, in general, have three components: L<text|name/section>.
  ;; In the following we match and capture like this:
  ;; - (match-string 1) to text, which is optional
  ;; - (match-string 2) to name, which is mandatory but may be empty
  ;;   for targets in the same file.   We capture old-style sections
  ;;   here, too, because syntactically they look like names.
  ;; - (match-string 3) to section.
  ;; Links can contain markup, too.  We support two levels of nesting
  ;; (because we've seen such things in the wild), but only with
  ;; single <> delimiters.  For the link element as a whole,
  ;; L<<< stuff >>> is supported.
  (let* (({  "\\(?:")
	 ({1 "\\(?1:")
	 ({2 "\\(?2:")
	 ({3 "\\(?3:")
	 (}  "\\)")
	 (or "\\|")
	 (bs "\\\\")
	 (q  "\"")
	 (ws	(concat { "[[:blank:]]" or "\n" } ))
	 (quoted    (concat { q { bs bs or bs q or "[^\"]" } "*" q } ))
	 (ang-expr "[BCEFISXZ]<+[^>]*>+")
	 (plain     (concat { "[^|<>]" or ang-expr } ))
	 (ponk     (concat { "[^|<>/]" or ang-expr } ))
	 (extended  (concat { "[^|/]" } ))
	 (nomarkup  (concat { "[^A-Z]<" } ))
	 (no-del    (concat { bs "|" or bs "/" or "[^|/]" } ))
	 (m2	(concat { "[A-Z]<<" ws no-del "+?" ws ">>" } ))
	 (m0	(concat { "[A-Z]<" { "[^<>|/]" or nomarkup } "+?>" } ))
	 (markup    (concat { m2 or "[A-Z]<"
			    { m2 or m0 or nomarkup or "[^|/>]" }
			    "+?>" } ))
	 (component (concat { plain or markup or nomarkup } ))
	 (pork (concat { ponk or markup or nomarkup } ))
	 (name      (concat {2 { "[^ \"\t|/<>]" or markup } "*" } ))
	 (url       (concat {2 "\\w+:/[^ |<>]+" } ))
	 ;; old-style references to a section in the same page.
	 ;; This style is deprecated, but found in the wild.  We are
	 ;; following the recommended heuristic from perlpodspec:
	 ;;    .... if it contains any whitespace, it's a section.
	 ;; We also found quoted things to be sections.
	 (old-sect  (concat {2 { component "+ " component "+" }
			    or quoted
			    }  )))
    (while (re-search-forward "L<\\(<+ \\)?" nil t)
      (let* ((terminator-length (length (match-string 1)))
	     (allow-angle (> terminator-length 0))
	     (text  (if allow-angle
			(concat {1 extended "+?" } )
		      (concat {1 component "+?" } )))
	     (section (if allow-angle
			  (concat {3 quoted or extended "+?" } )
			(concat {3 quoted or pork "+" } )))
	     (terminator (if allow-angle
			     (concat " " (make-string terminator-length ?>))
			   ">"))
	     (link-re   (concat "\\="
				{ { text "|" } "?"
				  {
				    { name { "/" section } "?" }
				    or url or old-sect
				  }
				}))
	     (re	(concat link-re terminator))
	     (end-marker (make-marker)))
	(re-search-forward re nil t)
	(set-marker end-marker (match-end 0))
	(cond
	 ((null (match-string 2))
	  ;; This means that the regexp failed.  Either the L<...>
	  ;; element is really, really bad, or the regexp isn't
	  ;; complicated enough.  Since the consequences are rather
	  ;; harmless, don't raise an error.
	  (message "sane-perl-perldoc: Unexpected string: %s"
		   (buffer-substring (line-beginning-position)
				     (line-end-position))))
	 ((string= (match-string 2) "")
	  ;; L<Some text|/anchor> or L</anchor> -> don't touch
	  nil)
	 ((save-match-data
	    (string-match "^\\w+:/" (match-string 2)))
	  ;; L<https://www.perl.org/> -> don't touch
	  nil)
	 ((save-match-data
	    (string-match " " (match-string 2)))
	  ;; L<SEE ALSO> -> L<SEE ALSO|/"SEE ALSO">, fix old style section
	  (goto-char (match-end 2))
	  (insert "\"")
	  (goto-char (match-beginning 2))
	  (insert (concat (match-string 2) "|/\"")))
	 ((save-match-data
	    (and (match-string 1) (string-match quoted (match-string 2))))
	  ;; L<unlink1|"unlink1"> -> L<unlink1|/"unlink1">, as seen in File::Temp
	  (goto-char (match-beginning 2))
	  (insert "/"))
	 ((save-match-data
	    (string-match quoted (match-string 2)))
	  ;; L<"safe_level"> -> L<safe_level|/"safe_level">, as seen in File::Temp
	  (goto-char (match-beginning 2))
	  (insert (concat (substring (match-string 2) 1 -1) "|/")))
	 ((match-string 3)
	  ;; L<Some text|page/sect> -> L<Some text|perldoc://page/sect>
	  ;; L<page/section> -> L<page/section|perldoc://page/section>
	  ;; In both cases:
	  ;; Work around a bug in pod2html as of 2020-07-27: It
	  ;; doesn't grok spaces in the "section" part, though they
	  ;; are perfectly valid.  Also, it retains quotes around
	  ;; sections which it removes for links to local sections.
	  (let ((section (match-string 3))
		(text (if (match-string 1) ""
			(concat (match-string 3)
				" in "
				(match-string 2) "|"))))
	      (save-match-data
		(setq section (replace-regexp-in-string "\"" "" section))
		(setq section (replace-regexp-in-string " " "-" section)))
	      (goto-char (match-beginning 3))
	      (delete-char (- (match-end 3) (match-beginning 3)))
	      (insert section)
	      (goto-char (match-beginning 2))
	      (insert text)
	      (insert "perldoc://")))
	 ((match-string 1) ; but without section
	  ;; L<Some text|page> -> L<Some text|perldoc://page>
	  (goto-char (match-beginning 2))
	  (insert "perldoc://"))
	 (t
	  (goto-char (match-beginning 2))
	  (insert (concat (match-string 2) "|" "perldoc://"))))
	(goto-char (marker-position end-marker))))))


;;;###autoload
(defun sane-perl-perldoc (word &optional section)
  "Run the shell command \\='perldoc\\=' on WORD, on Win32 platforms."
  (interactive
   (let* ((default (sane-perl-word-at-point))
	 (read (read-string
		(sane-perl--format-prompt "Find doc for function or module" default))))
     (list (if (equal read "")
	      default
	    read))))
  (require 'shr)
  (let* ((case-fold-search nil)
	 (is-func (and
		   (string-match "^\\(-[A-Za-z]\\|[a-z]+\\)$" word)
		   (string-match (concat "^" word "\\>")
				 (documentation-property
				  'sane-perl-short-docs
				  'variable-documentation))))
	 (perldoc-buffer (concat "*perldoc-"
				 (substring-no-properties word)
				 "*")))
    (if (get-buffer perldoc-buffer)
	(switch-to-buffer perldoc-buffer)
      (with-temp-buffer
	;; for diagnostics comment out the previous line, and
	;; uncomment the next.  This makes the intermediate buffer
	;; permanent for inspection in the pod- and html-phase.
	;; (with-current-buffer (get-buffer-create (concat "**pod-" word "**"))
	;; Fetch plain POD into a temporary buffer
	(when (< 0 (if is-func
		       (call-process sane-perl-perldoc-program nil t t "-u" "-f" word)
		     (call-process sane-perl-perldoc-program nil t t "-u" word)))
	  (error (buffer-string)))
	(sane-perl--pod-process-links)
	(shell-command-on-region (point-min) (point-max)
				 (concat sane-perl-pod2html-program
					 " --cachedir="
					 (make-temp-file "sane-perl" t)
					 " --flush"
					 " --noindex"
					 " --quiet")
				 (current-buffer) nil "*perldoc error*")
	(shr-render-buffer (current-buffer))) ; this pops to buffer "*html*"
      (switch-to-buffer "*html*") ; just to be sure
      (rename-buffer perldoc-buffer t)
      (put-text-property (point-min) (point-max)
			 'keymap sane-perl-perldoc-shr-map)
      (when is-func
	(make-local-variable 'sane-perl-perldoc-base)
	(defvar sane-perl-perldoc-base "perlfunc"))
      (set-buffer-modified-p nil)
      (read-only-mode))
    (when section
      (sane-perl--perldoc-goto-section section))))


;;;###autoload
(defun sane-perl-perldoc-at-point ()
  "Run a `perldoc' on the word around point."
  (interactive)
  (sane-perl-perldoc (sane-perl-word-at-point)))

(defcustom sane-perl-pod2man-program "pod2man"
  "File name for `pod2man'."
  :type 'file
  :group 'sane-perl)

(defun sane-perl-pod-to-manpage ()
  "Create a virtual manpage in Emacs from the Perl Online Documentation."
  (interactive)
  (require 'man)
  (let* ((pod2man-args (concat buffer-file-name " | nroff -man "))
	 (bufname (concat "Man " buffer-file-name))
	 (buffer (generate-new-buffer bufname)))
    (with-current-buffer buffer
      (let ((process-environment (copy-sequence process-environment)))
	;; Prevent any attempt to use display terminal fanciness.
	(setenv "TERM" "dumb")
	(set-process-sentinel
	 (start-process sane-perl-pod2man-program buffer "sh" "-c"
			(format (sane-perl-pod2man-build-command) pod2man-args))
	 'Man-bgproc-sentinel)))))

(defun sane-perl-build-manpage ()
  "Create a virtual manpage in Emacs from the POD in the file."
  (interactive)
  (require 'man)
  (let ((manual-program "perldoc")
	(Man-switches ""))
    (Man-getpage-in-background buffer-file-name)))

(defun sane-perl-pod2man-build-command ()
  "Builds the entire background manpage and cleaning command."
  (let ((command (concat sane-perl-pod2man-program " %s 2>/dev/null"))
	(flist (and (boundp 'Man-filter-list) Man-filter-list)))
    (while (and flist (car flist))
      (let ((pcom (car (car flist)))
            (pargs (cdr (car flist))))
        (setq command
              (concat command " | " pcom " "
                      (mapconcat (lambda (phrase)
                                   (if (not (stringp phrase))
                                       (error "Malformed Man-filter-list"))
                                   phrase)
                                 pargs " ")))
        (setq flist (cdr flist))))
    command))


(defun sane-perl-next-interpolated-REx-1 ()
  "Move point to next REx which has interpolated parts without //o.
Skips RExes consisting of one interpolated variable.

Note that skipped RExen are not performance hits."
  (interactive "")
  (sane-perl-next-interpolated-REx 1))

(defun sane-perl-next-interpolated-REx-0 ()
  "Move point to next REx which has interpolated parts without //o."
  (interactive "")
  (sane-perl-next-interpolated-REx 0))

(defun sane-perl-next-interpolated-REx (&optional skip beg limit)
  "Move point to next REx which has interpolated parts.
SKIP is a list of possible types to skip, BEG and LIMIT are the starting
point and the limit of search (default to point and end of buffer).

SKIP may be a number, then it behaves as list of numbers up to SKIP; this
semantic may be used as a numeric argument.

Types are 0 for / $rex /o (interpolated once), 1 for /$rex/ (if $rex is
a result of qr//, this is not a performance hit), t for the rest."
  (interactive "P")
  (if (numberp skip) (setq skip (list 0 skip)))
  (or beg (setq beg (point)))
  (or limit (setq limit (point-max)))	; needed for n-s-p-c
  (let (pp)
    (and (eq (get-text-property beg 'syntax-type) 'string)
	 (setq beg (next-single-property-change beg 'syntax-type nil limit)))
    (sane-perl-map-pods-heres
     (function (lambda (s _e _p)
		 (if (memq (get-text-property s 'REx-interpolated) skip)
		     t
		   (setq pp s)
		   nil)))	; nil stops
     'REx-interpolated beg limit)
    (if pp (goto-char pp)
      (message "No more interpolated REx"))))

(defun sane-perl-here-doc-spell ()
  "Spell-check HERE-documents in the Perl buffer.
If a region is highlighted, restricts to the region."
  (interactive)
  (sane-perl-pod-spell t))

(defun sane-perl-pod-spell (&optional do-heres)
  "Spell-check POD documentation.
If invoked with prefix argument, will do HERE-DOCs instead.
If a region is highlighted, restricts to the region."
  (interactive "P")
  (save-excursion
    (let (beg end)
      (if (region-active-p)
	  (setq beg (min (mark) (point))
		end (max (mark) (point)))
	(setq beg (point-min)
	      end (point-max)))
      (sane-perl-map-pods-heres (lambda (s e _p)
			       (if do-heres
				   (setq e (save-excursion
					     (goto-char e)
					     (forward-line -1)
					     (point))))
			       (ispell-region s e)
			       t)
			    (if do-heres 'here-doc-group 'in-pod)
			    beg end))))

(defun sane-perl-map-pods-heres (func &optional prop s end)
  "Executes a function over regions of pods or here-documents.
PROP is the text-property to search for; default to `in-pod'.  Stop when
function returns nil."
  (let (pos posend has-prop (cont t))
    (or prop (setq prop 'in-pod))
    (or s (setq s (point-min)))
    (or end (setq end (point-max)))
    (sane-perl-update-syntaxification end end)
    (save-excursion
      (goto-char (setq pos s))
      (while (and cont (< pos end))
	(setq has-prop (get-text-property pos prop))
	(setq posend (next-single-property-change pos prop nil end))
	(and has-prop
	     (setq cont (funcall func pos posend prop)))
	(setq pos posend)))))

(defun sane-perl-get-here-doc-region (&optional pos pod)
  "Return HERE document region around the point.
Return nil if the point is not in a HERE document region.  If POD is non-nil,
will return a POD section if point is in a POD section."
  (or pos (setq pos (point)))
  (sane-perl-update-syntaxification pos pos)
  (if (or (eq 'here-doc  (get-text-property pos 'syntax-type))
	  (and pod
	       (eq 'pod (get-text-property pos 'syntax-type))))
      (let ((b (sane-perl-beginning-of-property pos 'syntax-type))
	    (e (next-single-property-change pos 'syntax-type)))
	(cons b (or e (point-max))))))

(defun sane-perl-narrow-to-here-doc (&optional pos)
  "Narrows editing region to the HERE-DOC at POS.
POS defaults to the point."
  (interactive "d")
  (or pos (setq pos (point)))
  (let ((p (sane-perl-get-here-doc-region pos)))
    (or p (error "Not inside a HERE document"))
    (narrow-to-region (car p) (cdr p))
    (message
     "When you are finished with narrow editing, type C-x n w")))

(defun sane-perl-select-this-pod-or-here-doc (&optional pos)
  "Select the HERE-DOC (or POD section) at POS.
POS defaults to the point."
  (interactive "d")
  (let ((p (sane-perl-get-here-doc-region pos t)))
    (if p
	(progn
	  (goto-char (car p))
	  (push-mark (cdr p) nil t))	; Message, activate in transient-mode
      (message "I do not think POS is in POD or a HERE-doc..."))))

(defun sane-perl-facemenu-add-face-function (face _end)
  "A callback to process user-initiated font-change requests.
Translates `bold', `italic', and `bold-italic' requests to insertion of
corresponding POD directives, and `underline' to C<> POD directive.

Such requests are usually bound to M-o LETTER."
  (or (get-text-property (point) 'in-pod)
      (error "Faces can only be set within POD"))
  (setq facemenu-end-add-face (if (eq face 'bold-italic) ">>" ">"))
  (cdr (or (assq face '((bold . "B<")
			(italic . "I<")
			(bold-italic . "B<I<")
			(underline . "C<")))
	   (error "Face %S not configured for sane-perl-mode"
		  face))))
(defvar font-lock-cache-position)

(defun sane-perl-emulate-lazy-lock (&optional window-size)
  "Emulate `lazy-lock' without `condition-case', so `debug-on-error' works.
Start fontifying the buffer from the start (or end) using the given
WINDOW-SIZE (units is lines).  Negative WINDOW-SIZE starts at end, and
goes backwards; default is -50.  This function is not Sane-Perl-specific; it
may be used to debug problems with delayed incremental fontification."
  (interactive
   "nSize of window for incremental fontification, negative goes backwards: ")
  (or window-size (setq window-size -50))
  (let ((pos (if (> window-size 0)
		 (point-min)
	       (point-max)))
	p)
    (goto-char pos)
    (normal-mode)
    ;; Why needed???  With older font-locks???
    (set (make-local-variable 'font-lock-cache-position) (make-marker))
    (while (if (> window-size 0)
	       (< pos (point-max))
	     (> pos (point-min)))
      (setq p (progn
		(forward-line window-size)
		(point)))
      (font-lock-fontify-region (min p pos) (max p pos))
      (setq pos p))))


(defvar sane-perl-help-shown nil
  "Non-nil means that the help was already shown now.")

(defvar sane-perl-lazy-installed nil
  "Non-nil means that the lazy-help handlers are installed now.")

(defun sane-perl-lazy-install ()
  "Switch on Auto-Help on Perl constructs (put in the message area).
Delay of auto-help controlled by `sane-perl-lazy-help-time'."
  (interactive)
  (make-local-variable 'sane-perl-help-shown)
  (if (and (sane-perl-val 'sane-perl-lazy-help-time)
	   (not sane-perl-lazy-installed))
      (progn
	(add-hook 'post-command-hook #'sane-perl-lazy-hook)
	(run-with-idle-timer
	 (sane-perl-val 'sane-perl-lazy-help-time 1000000 5)
	 t
	 #'sane-perl-get-help-defer)
	(setq sane-perl-lazy-installed t))))

(defun sane-perl-lazy-unstall ()
  "Switch off Auto-Help on Perl constructs (put in the message area).
Delay of auto-help controlled by `sane-perl-lazy-help-time'."
  (interactive)
  (remove-hook 'post-command-hook #'sane-perl-lazy-hook)
  (cancel-function-timers #'sane-perl-get-help-defer)
  (setq sane-perl-lazy-installed nil))

(defun sane-perl-lazy-hook ()
  (setq sane-perl-help-shown nil))

(defun sane-perl-get-help-defer ()
  (if (not (memq major-mode '(perl-mode sane-perl-mode))) nil
    (let ((sane-perl-message-on-help-error nil) (sane-perl-help-from-timer t))
      (sane-perl-get-help)
      (setq sane-perl-help-shown t))))
(sane-perl-lazy-install)


;;; Plug for wrong font-lock:

(defun sane-perl-font-lock-unfontify-region-function (beg end)
  (with-silent-modifications
    (remove-text-properties beg end '(face nil))))

(defun sane-perl-font-lock-fontify-region-function (beg end loudly)
  "Extends the region to safe positions, then calls the default function.
Newer `font-lock's can do it themselves.
We unwind only as far as needed for fontification.  Syntaxification may
do extra unwind via `sane-perl-unwind-to-safe'."
  (save-excursion
    (goto-char beg)
    (while (and beg
		(progn
		  (beginning-of-line)
		  (eq (get-text-property (setq beg (point)) 'syntax-type)
		      'multiline)))
      (let ((new-beg (sane-perl-beginning-of-property beg 'syntax-type)))
	(setq beg (if (= new-beg beg) nil new-beg))
	(goto-char new-beg)))
    (setq beg (point))
    (goto-char end)
    (while (and end (< end (point-max))
		(progn
		  (or (bolp) (condition-case nil
				 (forward-line 1)
			       (error nil)))
		  (eq (get-text-property (setq end (point)) 'syntax-type)
		      'multiline)))
      (setq end (next-single-property-change end 'syntax-type nil (point-max)))
      (goto-char end))
    (setq end (point)))
  (font-lock-default-fontify-region beg end loudly))

(defvar sane-perl-d-l nil)
(defvar edebug-backtrace-buffer)        ;FIXME: Why?
(defun sane-perl-fontify-syntaxically (end)
  (let ((dbg (point)) (iend end) (idone sane-perl-syntax-done-to)
	(istate (car sane-perl-syntax-state))
	start from-start edebug-backtrace-buffer)
    (if (eq sane-perl-syntaxify-by-font-lock 'backtrace)
	(progn
	  (require 'edebug)
	  (let ((f 'edebug-backtrace))
	    (funcall f))))	; Avoid compile-time warning
    (or sane-perl-syntax-done-to
	(setq sane-perl-syntax-done-to (point-min)
	      from-start t))
    (setq start (if (and sane-perl-hook-after-change
			 (not from-start))
		    sane-perl-syntax-done-to ; Fontify without change; ignore start
		  ;; Need to forget what is after `start'
		  (min sane-perl-syntax-done-to (point))))
    (goto-char start)
    (beginning-of-line)
    (setq start (point))
    (and sane-perl-syntaxify-unwind
	 (setq end (sane-perl-unwind-to-safe t end)
	       start (point)))
    (and (> end start)
	 (setq sane-perl-syntax-done-to start) ; In case what follows fails
	 (sane-perl-find-pods-heres start end t nil t))
    (if (memq sane-perl-syntaxify-by-font-lock '(backtrace message))
	(message "Syxify req=%s..%s actual=%s..%s done-to: %s=>%s statepos: %s=>%s"
		 dbg iend start end idone sane-perl-syntax-done-to
		 istate (car sane-perl-syntax-state))) ; For debugging
    nil))				; Do not iterate

(defun sane-perl-fontify-update (end)
  (let ((pos (point-min)) prop posend)
    (setq end (point-max))
    (while (< pos end)
      (setq prop (get-text-property pos 'sane-perl-postpone)
	    posend (next-single-property-change pos 'sane-perl-postpone nil end))
      (and prop (put-text-property pos posend (car prop) (cdr prop)))
      (setq pos posend)))
  nil)					; Do not iterate

(defun sane-perl-fontify-update-bad (end)
  ;; Since fontification happens with different region than syntaxification,
  ;; do to the end of buffer, not to END;;; likewise, start earlier if needed
  (let* ((pos (point)) (prop (get-text-property pos 'sane-perl-postpone)) posend)
    (if prop
	(setq pos (or (sane-perl-beginning-of-property
		       (sane-perl-1+ pos) 'sane-perl-postpone)
		      (point-min))))
    (while (< pos end)
      (setq posend (next-single-property-change pos 'sane-perl-postpone))
      (and prop (put-text-property pos posend (car prop) (cdr prop)))
      (setq pos posend)
      (setq prop (get-text-property pos 'sane-perl-postpone))))
  nil)					; Do not iterate

;; Called when any modification is made to buffer text.
(defun sane-perl-after-change-function (beg _end _old-len)
  ;; We should have been informed about changes by `font-lock'.  Since it
  ;; does not inform as which calls are deferred, do it ourselves
  (if sane-perl-syntax-done-to
      (setq sane-perl-syntax-done-to (min sane-perl-syntax-done-to beg))))

(defun sane-perl-update-syntaxification (from to)
  (cond
   ((not sane-perl-use-syntax-table-text-property) nil)
   ((fboundp 'syntax-propertize) (syntax-propertize to))
   ((and sane-perl-syntaxify-by-font-lock
         (or (null sane-perl-syntax-done-to)
             (< sane-perl-syntax-done-to to)))
    (save-excursion
      (goto-char from)
      (sane-perl-fontify-syntaxically to)))))

(provide 'sane-perl-mode)
