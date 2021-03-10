# Test for adding support for named capture

use FindBin '$Bin';
use lib "$Bin";
use SanePerl;
my $pl =<<'EOF';
m!(?<fruit>banana|orange)!
EOF
my $fl = run_font_lock ($pl);
my $plq =<<'EOF';
m!(?'fruit'banana|orange)!
EOF
my $flq = run_font_lock ($plq);
my $plmix =<<'EOF';
m!(?<fruit'banana|orange)!
EOF
my $flmix = run_font_lock ($plmix);
#TODO: {
#    local $TODO = 'Support named captures';
unlike ($fl, qr!warning">\?!, "No warning about named capture");
unlike ($flq, qr!warning">\?!, "No warning about named capture");
#};
like ($flmix, qr!warning">\?!, "Warning about broken named capture");
done_testing ();
