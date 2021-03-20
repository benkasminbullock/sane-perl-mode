use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my $bug_47112 =<<'EOF';
my $x =~ tr_a_b_;
EOF
my $out_47112 = run_font_lock ($bug_47112);
print "->$out_47112\n";
unlike ($out_47112, qr!<span class="sane-perl-nonoverridable">tr</span>!,
	"tr not transliteration before _");
done_testing ();
