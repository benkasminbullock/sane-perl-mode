use FindBin '$Bin';
use lib $Bin;
use SanePerl;
my $qw = <<'EOF';
my $qw = qw!
this
that
other
!;
EOF
my $out = run_indent ($qw);
like ($out, qr/^\s+this/m, "Added space before entry in qw");
done_testing ();
