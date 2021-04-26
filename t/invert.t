# This tests sane-perl-mode.el's ability to invert if (A) {B} into a
# "trailing if" format B if A.

use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my $if = <<EOF;
if (A) {
  B;
}
EOF

my $invertel =<<EOF;
(sane-perl-mode)
(sane-perl-invert-if-unless)
EOF

my $invertif = "B if A;\n";

my $out = run ($invertel, $if);
is ($out, $invertif, "Create trailing if");

my $restoreel =<<EOF;
(sane-perl-mode)
(sane-perl-invert-if-unless-modifiers)
EOF

my $revert = run ($restoreel, $out);
is ($revert, $if, "Convert trailing to leading if");

# Don't add parentheses if not necessary
# http://mikan/bugs/bug/2163
my $trailing = <<'EOF';
	last if ($m == $b || $m == $t);
EOF
my $leading = run ($restoreel, $trailing);
unlike ($leading, qr!\(\(\$m!, "Don't add parentheses unless necessary");

done_testing ();
