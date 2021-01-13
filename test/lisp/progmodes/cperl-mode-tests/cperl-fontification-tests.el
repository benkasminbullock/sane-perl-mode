;;; sane-perl-fontification-tests.el --- Test fontification in sane-perl-mode -*- lexical-binding: t -*-

;; Copyright (C) 2020-2020 ...to be decided ...

;; Author: Harald Jörg <haj@posteo.de>
;; Maintainer: Harald Jörg
;; Keywords:       internal
;; Human-Keywords: internal
;; Homepage: https://github.com/HaraldJoerg/cperl-mode

;;; Commentary:

;; This is a collection of Tests for the fontification of CPerl-mode.
;; The primary target is to verify that the refactoring we're doing
;; right now (May 2020 - ...) doesn't change any behavior, or does the
;; right thing in cases where new fontification rules are enabled.

;; Run these tests interactively:
;; (ert-run-tests-interactively '(tag :fontification))

;; Adapted from flymake
(defvar sane-perl-mode-tests-data-directory
  (expand-file-name "lisp/progmodes/sane-perl-mode-resources"
                    (or (getenv "EMACS_TEST_DIRECTORY")
                        (expand-file-name "../../../.."
                                          (or load-file-name
                                              buffer-file-name))))
  "Directory containing sane-perl-mode test data.")

(defun sane-perl-test-face (text regexp)
  "Returns the face of the first character matched by REGEXP in TEXT."
  (interactive)
  (with-temp-buffer
    (let ((sane-perl-hairy nil)
      (sane-perl-font-lock nil)) ;; Does this matter?
      (insert text)
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (goto-char (point-min))
      (re-search-forward regexp)
      (get-text-property (match-beginning 0) 'face))))

(ert-deftest jrockway-issue-45 ()
  "Verify that '/' is a division after ++ or --, not a regexp.
Reported in https://github.com/jrockway/cperl-mode/issues/45.
If seen as regular expression, then the slash is displayed using
font-lock-constant-face.  If seen as a division, then it doesn't
have a face property."
  :tags '(:fontification)
  ;; The next two Perl expressions have divisions.  Perl "punctuation"
  ;; operators don't get a face.  The comment at the end of line
  ;; prevents sane-perl-mode from tripping over "End of ‘/ ... /’
  ;; string/RE not found" if it gets it wrong
  (let ((code "{ $a++ / $b } # /"))
    (should (equal (sane-perl-test-face code "/" ) nil)))
  (let ((code "{ $a-- / $b } # /"))
    (should (equal (sane-perl-test-face code "/" ) nil)))
  ;; The next two Perl expressions have regular expressions.  The
  ;; delimiter of a RE is fontified with font-lock-constant-face.
  (let ((code "{ $a+ / $b } # /"))
    (should (equal (sane-perl-test-face code "/" ) font-lock-constant-face)))
  (let ((code "{ $a- / $b } # /"))
    (should (equal (sane-perl-test-face code "/" ) font-lock-constant-face))))

(defun sane-perl-test--text-face (text face)
  "Find the next occurrence of TEXT and test against FACE.
Search forward in the current buffer, so several of these tests
can be run in a row.  Check the first character of the match
whether its face property matches FACE."
  (search-forward text)
  (should (equal (get-text-property (match-beginning 0) 'face) face)))


(ert-deftest sane-perl-here-docs ()
  "Verify that unindented here-docs are closed properly."
  (let ((file (expand-file-name "sane-perl-here-docs.pl"
                                 sane-perl-mode-tests-data-directory))
        (case-fold-search nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (indent-region (point-min) (point-max))
      (sane-perl-test--text-face "HERE"   font-lock-constant-face)
      (sane-perl-test--text-face "test"   font-lock-string-face)
      (sane-perl-test--text-face "HERE"   font-lock-constant-face)
      (sane-perl-test--text-face "return" font-lock-keyword-face))))



(ert-deftest sane-perl-here-docs-indented ()
  "Verify that indented here-docs are closed properly.
As of Perl 5.26, here-docs can be indented with their code."
  (let ((file (expand-file-name "sane-perl-here-docs-indented.pl"
                                 sane-perl-mode-tests-data-directory))
        (case-fold-search nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (indent-region (point-min) (point-max))
      (sane-perl-test--text-face "HERE"   font-lock-constant-face)
      (sane-perl-test--text-face "test"   font-lock-string-face)
      (sane-perl-test--text-face "HERE"   font-lock-constant-face)
      (sane-perl-test--text-face "return" font-lock-keyword-face))))


(ert-deftest sane-perl-here-docs-edge ()
  "Verify that an edge case here-doc is closed properly.
In this case, the here-doc contains the terminator string, but
not starting at column 1: This is still part of the here-doc."
  (let ((file (expand-file-name "sane-perl-here-docs-edge.pl"
                                 sane-perl-mode-tests-data-directory))
        (case-fold-search nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (indent-region (point-min) (point-max))
      (sane-perl-test--text-face "HERE"   font-lock-constant-face)
      (sane-perl-test--text-face "test"   font-lock-string-face)
      ;; For a non-indented keyword, the terminator _must_ start
      ;; in column one, so this occurrence is _not_ a terminator.
      (sane-perl-test--text-face "    HERE"   font-lock-string-face)
      (sane-perl-test--text-face "HERE"   font-lock-constant-face)
      (sane-perl-test--text-face "return" font-lock-keyword-face))))


(ert-deftest sane-perl-test-moosex-declare ()
  "Verify that a module using MooseX::Declare looks halfway decent.
Full compatibility with jrockway's branch is not attempted."
  (let ((file (expand-file-name "sane-perl-moosex-declare.pm"
                                sane-perl-mode-tests-data-directory))
        (sane-perl-automatic-keyword-sets t)
        (case-fold-search nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (sane-perl-test--text-face "use"             font-lock-keyword-face)
      (sane-perl-test--text-face "MooseX::Declare" font-lock-function-name-face)
      (sane-perl-test--text-face "class"           font-lock-keyword-face)
      (sane-perl-test--text-face "BankAccount"     font-lock-function-name-face)
      (sane-perl-test--text-face "has"             font-lock-type-face)
      (sane-perl-test--text-face "method"          font-lock-keyword-face)
      (sane-perl-test--text-face "deposit"         font-lock-function-name-face)
      (sane-perl-test--text-face "my"              font-lock-keyword-face)
      (sane-perl-test--text-face "$current_balanc" font-lock-variable-name-face)
      (sane-perl-test--text-face "confess"         font-lock-type-face)
      (sane-perl-test--text-face "CheckingAccount" font-lock-function-name-face)
      (sane-perl-test--text-face "extends"         font-lock-keyword-face)
      (sane-perl-test--text-face "BankAccount"     font-lock-function-name-face)
      (sane-perl-test--text-face "before"          font-lock-type-face)
      (sane-perl-test--text-face "withdraw"        nil)
      "done.")))

(ert-deftest sane-perl-test-moosex-declare-noauto ()
  "The same test as before, but disable keyword recognition.
This behaves as older versions of sane-perl-mode, and should still
recognize variables and core keywords."
  (let ((file (expand-file-name "sane-perl-moosex-declare.pm"
                                sane-perl-mode-tests-data-directory))
        (sane-perl-automatic-keyword-sets nil) ; Don't apply keyword sets
        (case-fold-search nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (sane-perl-test--text-face "use"             font-lock-keyword-face)
      (sane-perl-test--text-face "MooseX::Declare" font-lock-function-name-face)
      (sane-perl-test--text-face "class"           nil)
      (sane-perl-test--text-face "BankAccount"     nil)
      (sane-perl-test--text-face "has"             nil)
      (sane-perl-test--text-face "method"          nil)
      (sane-perl-test--text-face "deposit"         nil)
      (sane-perl-test--text-face "my"              font-lock-keyword-face)
      (sane-perl-test--text-face "$current_balanc" font-lock-variable-name-face)
      (sane-perl-test--text-face "confess"         nil)
      (sane-perl-test--text-face "CheckingAccount" nil)
      (sane-perl-test--text-face "extends"         nil)
      (sane-perl-test--text-face "BankAccount"     nil)
      (sane-perl-test--text-face "before"          nil)
      (sane-perl-test--text-face "withdraw"        nil)
      "done.")))

(ert-deftest sane-perl-test-test-more ()
  "Test some keywords which occur in Test::More scripts."
  (let ((file (expand-file-name "test-more.t"
                                sane-perl-mode-tests-data-directory))
        (sane-perl-automatic-keyword-sets t)
        (case-fold-search nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (let ((functions '("require_ok(" "ok(" "is  (" "isnt("
                         "diag(" "like  (" "unlike(" "cmp_ok("
                         "is_deeply(" "skip "
                         "can_ok(" "isa_ok("
                         "pass(" "fail("
                         "BAIL_OUT(" "done_testing;")))
        (dolist (f functions)
          (sane-perl-test--text-face f font-lock-type-face))))))

(ert-deftest sane-perl-test-ancient-font-lock ()
  "Verify that ancient bugs of font-lock are gone."
  (let ((file (expand-file-name "ancient-font-lock-bugs.pl"
                                 sane-perl-mode-tests-data-directory))
        (case-fold-search nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (sane-perl-test--text-face "$string =~ /\\s" nil)          ; get in place
      (sane-perl-test--text-face "golden" font-lock-string-face) ; ok here
      (sane-perl-test--text-face "/" font-lock-constant-face)    ; end of Perl RE
      (sane-perl-test--text-face "$`" nil)                       ; get in place
      (sane-perl-test--text-face ";" nil)                        ; not a string
      (sane-perl-test--text-face "$'" nil)                       ; get in place
      (sane-perl-test--text-face ";" nil)                        ; not a string
      (sane-perl-test--text-face "$\"" font-lock-variable-name-face) ; get in place
      (sane-perl-test--text-face "=" nil)                        ; not a string
      (search-forward "my %opt = (")                         ; get in place
      (sane-perl-test--text-face "s" font-lock-string-face)      ; hash key
      (sane-perl-test--text-face " => " nil)                     ; not a string
      ;; Can't test for sane-perl-hash-face for "$opt{s}": that is a lexical
      (sane-perl-test--text-face "}" nil)                        ; not a string
      (sane-perl-test--text-face ";" nil)                        ; not a string
      (sane-perl-test--text-face "//" nil)                       ; not a string
      (sane-perl-test--text-face ";" nil))))                     ; not a string

(ert-deftest sane-perl-test-set-activation ()
  "Verify that explicit activation / deactivation of keywords works."
  (let ((file (expand-file-name "sane-perl-moose-module.pm"
                                sane-perl-mode-tests-data-directory))
        (sane-perl-automatic-keyword-sets t)
        (case-fold-search nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (sane-perl-mode)
      (font-lock-fontify-buffer)
      (sane-perl-test--text-face "builder"         font-lock-type-face)
      (sane-perl-deactivate-keyword-set 'Plack::Builder)
      (goto-char (point-min))
      (font-lock-fontify-buffer)
      (sane-perl-test--text-face "builder"         nil)
      (sane-perl-activate-keyword-set 'Plack::Builder)
      (goto-char (point-min))
      (font-lock-fontify-buffer)
      (sane-perl-test--text-face "builder"         font-lock-type-face)
      "done.")))
