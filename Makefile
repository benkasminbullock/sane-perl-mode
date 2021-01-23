IDIR=/home/ben/config/emacs

install: $(IDIR)/sane-perl-mode.elc

$(IDIR)/sane-perl-mode.el $(IDIR)/sane-perl-mode.elc: sane-perl-mode.el install.pl
	./install.pl

test:
	prove t/*.t

clean:
	purge -r
