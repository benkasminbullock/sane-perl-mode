use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

# All of the following lines have trailing whitespace.

my $perl = <<'EOF';
$_ 
$ 
"cperl mode is totally bonkers"       
# Not really, we love cperl-mode.  
EOF

my $el = <<EOF;
(setq sane-perl-invalid-face 'underline)
EOF
my $html = run_font_lock ($perl, $el);
like ($html, qr!bonkers"</span><span class="underline">!, "Got underlining of trailing whitespace");
like ($html, qr!cperl-mode\.</span><span class="underline">!, "It even underlines within comments");
done_testing ();
