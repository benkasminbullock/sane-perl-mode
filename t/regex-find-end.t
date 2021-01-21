use Test::More;
use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

# Byte-compilation of sane-perl-mode.el gives the following error:
#
# sane-perl-mode.el:3415:1:Warning: Unused lexical argument ‘oend’
#
# However, when "oend" was removed from the arguments of
# sane-perl-forward-re, it caused a bug where, for example, everything
# from circle/; on the first line to the end of the second line of the
# following code was not highlighted correctly.

my $perl = <<'EOF';
$repair =~ s/circular/circle/;
$repair =~ s/buckets/bucket/;
EOF

my $html = run_font_lock ($perl);
unlike ($html, qr!<span class="string">circle/;\n\$repair =~ s/buckets/bucket/;</span>!);

done_testing ();
