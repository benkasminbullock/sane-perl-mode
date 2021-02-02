use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my $pl =<<'EOF';
sub get_image_rads
{
    my %image_rads = qw/
	10 ninben
/;
    return %image_rads;
}
EOF
my $el = <<EOF;
(setq sane-perl-indentable-indent nil)
(setq sane-perl-indent-level 4)
EOF
my $pl_re=<<'EOF';
sub baba
{
    my $re = qr!
        abcdef
    !x;
}
EOF
# http://mikan/bugs/bug/2181

#TODO: {
#    local $TODO = 'Last line of qw is not indented correctly';
    my $out = run_indent ($pl, $el);
    like ($out, qr!    /;!, "Indented end of qw correctly");
    my $out_re = run_indent ($pl_re, $el);
    like ($out_re, qr{    !x;}, "Indented end of qr correctly");
#};
done_testing ();
