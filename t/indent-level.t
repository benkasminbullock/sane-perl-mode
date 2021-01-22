use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

# No indent

my $in = read_text ("$Bin/ex/nested-perl.pl");
run_indent ($in, '', $in, "Default nesting is unchanged");

# Indent with three spaces

my $outdent3 = outdent ($in, 3);
my $el3 = "(setq sane-perl-indent-level 3)\n";
run_indent ($in, $el3, $outdent3, "Setting indent to 3 succeeded");

# Indent with four spaces

my $outdent4 = outdent ($in, 4);
my $el4 = "(setq sane-perl-indent-level 4)\n";
run_indent ($in, $el4, $outdent4, "Setting indent to 4 succeeded");

done_testing ();

sub outdent
{
    my ($outdent, $n) = @_;
    my $replace = ' ' x $n;
    $outdent =~ s!^((?:  )+)!$replace x (length ($1)/2) !gesm;
    $outdent =~ s!        !\t!g;
    return $outdent;
}
