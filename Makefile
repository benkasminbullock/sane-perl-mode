IDIR=/home/ben/config/emacs

all:

install: $(IDIR)/sane-perl-mode.elc

$(IDIR)/sane-perl-mode.el $(IDIR)/sane-perl-mode.elc: sane-perl-mode.el install.pl
	./install.pl

style-alist.json:	sane-perl-mode.el const-to-json.el
	rm -f style-alist.json
	emacs -Q -nw --batch --load const-to-json.el

test:
	prove t/*.t

clean:
	purge -r
