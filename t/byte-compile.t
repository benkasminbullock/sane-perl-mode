use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my ($erh, $erf) = tempfile ("bytecerr.XXXXXX", DIR => $dir);
close $erh or die $!;
system ("emacs --batch --eval '(byte-compile-file \"$modeel\")' 2> $erf");
my $errors = read_text ($erf);
unlink $erf or die $!;
my $elc = "${modeel}c";
if (-f $elc) {
    unlink $elc or die $!;
}
TODO: {
    local $TODO = 'Fix byte compiler errors';
    ok (! $errors, "No errors from byte compilation of $modeel");
    # This is the sticking point.
    unlike ($errors, qr!Unused lexical argument ‘oend’!,
	    "Fixed oend problem");
};

done_testing ();
