use Test::More;
use FindBin '$Bin';
use lib "$Bin";
use SanePerl;
my $in = <<'EOF';
if (x) {

}
EOF
my $el = <<'EOF';
(setq sane-perl-extra-newline-before-brace t)
EOF

my $expect = <<'EOF';
if (x)
{

}
EOF
run_indent ($in, $el, $expect);
done_testing ();
