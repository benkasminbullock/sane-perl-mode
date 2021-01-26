#!/home/ben/software/install/bin/perl
use FindBin '$Bin';
use lib "$Bin/t";
use SanePerl;
my $command = "emacs -batch -l sane-perl-mode.el -l ert -l original-tests/lisp/progmodes/sane-perl-mode-tests.el -f ert-run-tests-batch-and-exit";
my ($ofh, $ofn) = tempfile ("out.XXXXXX", dir => $Bin);
my ($efh, $efn) = tempfile ("err.XXXXXX", dir => $Bin);
close $ofh or die $!;
close $efh or die $!;
my $status = system ("$command > $ofn 2> $efn");
my $errors = read_text ($efn);
print $errors;
unlink $ofn or die $!;
unlink $efn or die $!;
