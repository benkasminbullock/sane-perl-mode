#!/home/ben/software/install/bin/perl
use Z;
use Deploy ':all';
my $verbose = 1;
my $login = 'ben@orange';
my $dir = '/home/ben/config/emacs';
my $file = 'sane-perl-mode.el';
do_ssh ($login, "chmod 0644 $dir/$file");
do_scp ($login, $file, $dir, $verbose);
exit;
