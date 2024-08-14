use FindBin '$Bin';
use lib $Bin;
use SanePerl;
plan skip_all => "Can't reproduce the bug yet";
ok (1);
my $in =<<'EOF';
my $plonker = 'Ricky Gervais';

=head1 SIMPLE DEMO

=cut

sub dingdong
{
    return 'King Kong';
}
EOF
my $el =<<EOF;
(kill-region 33 58)
EOF
my $out = run ($el, $in);
print "$out\n";
done_testing ();
