use FindBin '$Bin';
use lib "$Bin/../t/";
use SanePerl;
my $perl = <<'EOF';
write_json ($trans, $json_file);
EOF
my $el = <<EOF;
(set-mark 19)
(goto-char 19)
(transpose-words 1)
EOF
my $out = run ($el, $perl, no_clean => 1,);
TODO: {
    local $TODO = 'Recognise words in Perl correctly';
    unlike ($out, qr!trans_file!, "Bad transposition");
    unlike ($out, qr!\$json,!, "Bad transposition");
    like ($out, qr!\$json_file!, "Transpose underscores as part of word");
};
done_testing ();
