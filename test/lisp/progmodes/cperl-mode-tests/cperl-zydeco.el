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

(ert-deftest sane-perl-test-zydeco-indenting ()
  "Rudimentary verify that Zydeco sources are indented properly."
  (let ((file (expand-file-name "zydeco.pl"
                                sane-perl-mode-tests-data-directory))
	(expect (expand-file-name "zydeco_expected.pl"
				  sane-perl-mode-tests-data-directory)))
    (with-temp-buffer
      (insert-file file)
      (sane-perl-mode)
      (sane-perl-set-style "PBP")
      (indent-region (point-min) (point-max))
      (sane-perl-set-style-back)
      (let ((result (buffer-substring-no-properties
		     (point-min) (point-max))))
	(find-file-existing expect)
	(sane-perl-mode)
	(should (equal result (buffer-substring-no-properties
		     (point-min) (point-max))))
	(kill-buffer)))))
      
