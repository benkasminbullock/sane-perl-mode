# Check that the indentation that the mode actually offers is the same
# as the documented indentation.

use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my $verbose;
#my $verbose = 1;

# Extract the style examples from the documentation.

my $text = read_text ("$Bin/../sane-perl-mode.el");
my %s2t;

my $opt = qr!(?:nil|-?[0-9]|t)!;
my $style_re = qr!
^\#\#\#
\s
((?:\w|\+|-|&)+)
.*?
(?:(?:$opt)\/)+$opt\s*\n
(if.*?stop;\s*?\}\n)
!xsm;

while ($text =~ /$style_re/g) {
    my $style = $1;
    my $output = $2;
    $s2t{$style} = $output;
}

if ($verbose) {
    for my $style (sort {uc $a cmp uc $b} keys %s2t) {
	print "********* $style\n";
	print "$s2t{$style}\n";
    }
}

my $initial = $s2t{"Sane-Perl"};
my @broken = qw!Whitesmith!;
my %broken;
@broken{@broken} = @broken;
for my $style (sort {uc $a cmp uc $b} keys %s2t) {
    if ($broken{$style}) {
	note "$style known to be broken, skipping";
	next;
    }
    my $el = "(sane-perl-set-style \"$style\")\n";
    run_indent ($initial, $el, $s2t{$style}, "Test of $style indentation");
}

TODO: {
    local $TODO = "Fix broken styles";
    for my $style (sort {uc $a cmp uc $b} keys %s2t) {
	if (! $broken{$style}) {
	    next;
	}
	my $el = "(sane-perl-set-style \"$style\")\n";
	# We can't run todo tests in a different module, so we can't
	# use the third argument of run_indent to run our tests.
	my $output = run_indent ($initial, $el);
	is ($output, $s2t{$style}, "Test of $style indentation");
    }
};

done_testing ();
