use FindBin '$Bin';
use lib "$Bin";
use SanePerl;
my $perl = <<'EOF';
write_json ($trans, $json_file);
EOF
my $el = <<EOF;
(set-mark 12)
(goto-char 30)
(transpose-words 0)
EOF
my $out = run ($el, $perl, no_clean => 1,);
like ($out, qr!trans_file!, "Bad transposition");
#unlike ($out, qr!\$json,!, "Bad transposition");

done_testing ();
