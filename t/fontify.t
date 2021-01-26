use FindBin '$Bin';
use lib "$Bin";
use SanePerl;
my $in = read_text ("$Bin/ex/hash-font.pl");
my $out = run_font_lock ($in);
my @lines = split /\n/, $out;
for (@lines) {
    my $line = $_;
    $line =~ s/<.*?>//g;
    if (/chunky/) {
	like ($_, qr!<span class="sane-perl-hash">.+?chunky</span>!,
	      "Fontified chunky as hash in $line");
    }
    if (/chops/) {
	like ($_, qr!<span class="sane-perl-array">.+?chops</span>!,
	      "Fontified chops as array in $line");
    }
}


done_testing ();
