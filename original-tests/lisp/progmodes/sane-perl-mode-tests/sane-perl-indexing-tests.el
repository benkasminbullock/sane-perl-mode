;;; sane-perl-indexing-test.el --- Test indexing in sane-perl-mode -*- lexical-binding: t -*-

;; Copyright (C) 2020-2020 ...to be decided ...

;; Author: Harald Jörg <haj@posteo.de>
;; Maintainer: Harald Jörg
;; Keywords:       internal
;; Human-Keywords: internal
;; Homepage: https://github.com/HaraldJoerg/cperl-mode

;;; Commentary:

;; This is a collection of Tests for indexing of Perl modules,
;; classes, subroutines, methods and whatnot.

;; Run these tests interactively:
;; (ert-run-tests-interactively '(tag :indexing))


;; Adapted from flymake
(defvar sane-perl-mode-tests-data-directory
  (expand-file-name "lisp/progmodes/sane-perl-mode-resources"
                    (or (getenv "EMACS_TEST_DIRECTORY")
                        (expand-file-name "../../../.."
                                          (or load-file-name
                                              buffer-file-name))))
  "Directory containing sane-perl-mode test data.")

(ert-deftest sane-perl-test-package-name-block-indexing ()
  "Verify indexing of the syntax package NAME BLOCK.
The syntax package NAME BLOCK is available as of Perl 5.14.
Check that such packages are indexed correctly."
  :tags '(:indexing)
  (let ((code "package Foo::Bar {
    sub baz { ...; }
}"))
    (with-temp-buffer
      (insert code)
      (sane-perl-mode)
      (sane-perl-imenu--create-perl-index)
      (let* ((index-alist (sane-perl-imenu--create-perl-index))
         (packages-alist (assoc "+Packages+..." index-alist))
         (unsorted-alist (assoc "+Unsorted List+..." index-alist))
         )
    (should (markerp (cdr (assoc "package Foo::Bar" packages-alist))))
    (should (markerp (cdr (assoc "Foo::Bar::baz" unsorted-alist))))
    ))))

;;; For testing tags, we need files - buffers won't do it.
(ert-deftest sane-perl-etags-basic ()
  "Just open a buffer in sane-perl-mode and run `sane-perl-etags`."
  (let ((file (expand-file-name "sane-perl-indexing.pm"
                                sane-perl-mode-tests-data-directory)))
    (find-file file)
    (sane-perl-mode)
    (sane-perl-etags)
    (find-file "TAGS")
    (goto-char (point-min))
    (should (search-forward "Pack::Age"))
    (should (search-forward "foo"))
    (delete-file "TAGS")
    (kill-buffer)))

(ert-deftest sane-perl-write-tags-basic ()
  "Just open a buffer in sane-perl-mode and run `sane-perl-write-tags`."
  (let ((file (expand-file-name "sane-perl-indexing.pm"
                                sane-perl-mode-tests-data-directory)))
    (find-file file)
    (sane-perl-mode)
    (sane-perl-write-tags)
    (find-file "TAGS")
    (goto-char (point-min))
    (should (search-forward "Pack::Age"))
    (should (search-forward "foo"))
    (delete-file "TAGS")
    (kill-buffer)))

(ert-deftest sane-perl-write-tags-from-menu ()
  "Just open a buffer in sane-perl-mode and run `sane-perl-etags` recursively."
  (let ((file (expand-file-name "sane-perl-indexing.pm"
                                sane-perl-mode-tests-data-directory)))
    (find-file file)
    (sane-perl-mode)
    (sane-perl-write-tags nil t t t) ;; from the Perl menu "Tools/Tags"
    (find-file "TAGS")
    (goto-char (point-min))
    (should (search-forward "sane-perl-indexing.pm"))
    (should (search-forward "Pack::Age"))
    (should (search-forward "foo"))
    (goto-char (point-min))
    (should (search-forward "sane-perl-moose-module.pm"))
    (should (search-forward "My::Moo::dule")) ;; written as package NAME BLOCK
    (should (search-forward "my_method")) ;; This sub doesn't start in column 1
    (goto-char (point-min))
    (should (search-forward "sane-perl-moosex-declare.pm"))  ;; extra keywords!
    (should (search-forward "BankAccount")) ;; a class, not a module
    (should (search-forward "deposit")) ;; a method, not a sub
;;  (should (search-forward "CheckingAccount")) ;; a  subclass FAILS
    (delete-file "TAGS")
    (kill-buffer)))

(ert-deftest sane-perl-function-parameters ()
  "Play around with the keywords of Function::Parameters"
  (let ((file (expand-file-name "function-parameters.pm"
                                sane-perl-mode-tests-data-directory))
        (sane-perl-automatic-keyword-sets t))
    (find-file file)
    (sane-perl-mode)
    (sane-perl-imenu--create-perl-index)
    (let* ((index-alist (sane-perl-imenu--create-perl-index))
           (packages-alist (assoc "+Packages+..." index-alist))
           (unsorted-alist (assoc "+Unsorted List+..." index-alist))
           )
      (should (markerp (cdr (assoc "Main::foo" unsorted-alist)))) ;; a "fun"ction
      (should (markerp (cdr (assoc "Main::bar" unsorted-alist)))) ;; a method
      (should (markerp (cdr (assoc "package Main" packages-alist))))
      (should (markerp (cdr (assoc "package Derived" packages-alist)))))))

