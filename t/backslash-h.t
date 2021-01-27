# It fails to recognise \h in regular expressions.
# http://mikan/bugs/bug/2180
use FindBin '$Bin';
use lib "$Bin";
use SanePerl;
#TODO: {
#    local $TODO = 'Recognize \h and friends in regex';
for my $verboten (qw!h H v V R!) {
    my $p = "print if /\\$verboten/";
    my $out = run_font_lock ($p);
    unlike ($out, qr!<span class="warning">\\</span>!);
}
#};
done_testing ();
