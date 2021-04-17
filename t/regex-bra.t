use FindBin '$Bin';
use lib $Bin;
use SanePerl;

# Inserting a space before the first ( removes the problem.

TODO: {
    local $TODO = 'Fix warning font lock with )';
my $p = <<'EOF';
my $urlre = qr!
(([^\s\):"]*[^\s\)\.:"]+))
!x;
EOF
my $out = run_font_lock ($p);
unlike ($out, qr!<span class="warning">\)</span>!, "No red closing brace");
my $p2 = <<'EOF';
my $urlre = qr!
([^s])
!x;
EOF
my $out2 = run_font_lock ($p2);
unlike ($out2, qr!<span class="warning">\)</span>!, "No red closing brace");
}
done_testing ();
