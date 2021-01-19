#!/home/ben/software/install/bin/perl
use Z;
#do_system ("wget https://raw.githubusercontent.com/emacs-mirror/emacs/master/lisp/progmodes/cperl-mode.el");
my $text = read_text ("cperl-mode.el");
$text =~ s!cperl!sane-perl!g;
$text =~ s!CPerl!Sane-Perl!g;
my $out = "gnu-cperl-mode.el";
if (-f $out) {
    unlink $out or die $!;
}
write_text ($out, $text);
print `diff $out sane-perl-mode.el`;
