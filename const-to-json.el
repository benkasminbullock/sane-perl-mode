;json-serialize does not work, but this does.
; https://tess.oconnor.cx/2006/03/json.el
(require 'json)
(load-file "sane-perl-mode.el")
;(message "%s" (type-of 'sane-perl-style-alist))
(setq s (json-encode sane-perl-style-alist))
(write-region s nil "style-alist.json" t)
;(message "%s" (json-serialize sane-perl-style-alist))
(kill-emacs)
