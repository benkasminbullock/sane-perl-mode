#!/home/ben/software/install/bin/perl
use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my $verbose;
my $dir = "$Bin/../original-tests/lisp/progmodes";
my $file = "$dir/sane-perl-mode-tests.el";
my $spm = "$Bin/../sane-perl-mode.el";
my $f = 'ert-run-tests-batch-and-exit';
my $command = "emacs -batch -l $spm -l ert -l $file -f $f";
my ($ofh, $ofn) = tempfile ("out.XXXXXX", dir => $Bin);
my ($efh, $efn) = tempfile ("err.XXXXXX", dir => $Bin);
close $ofh or die $!;
close $efh or die $!;
my $status = system ("$command > $ofn 2> $efn");
#my $output = read_text ($ofn);
#print $output;
# The test results are "errors" apparently.
my $errors = read_text ($efn);
unlink $ofn or die $!;
unlink $efn or die $!;
if ($verbose) {
    print "$errors\n";
}
my $ntests;
if ($errors =~ /Running ([0-9]+) tests/) {
    $ntests = $1;
}
for my $i (1..$ntests) {
    if ($errors =~ m!\s+(.*)\s+$i/$ntests\s+(.*)!) {
	my $result = $1;
	my $name = $2;
	ok ($result =~ /passed/, "$name");
    }
}
done_testing ($ntests);
