use FindBin '$Bin';
use lib "$Bin";
use SanePerl;
use Deploy 'do_system';
#plan skip_all => "Can't reproduce the bug yet";
my $in = read_text ("$Bin/replace.pl");
my $el = read_text ("$Bin/replace.el");
do_system ("emacs --batch replace.pl --load replace.el");
ok (1);
done_testing ();

# Using Emacs interactively, with "replace-string", we get the
# following:
# 
# <span class="keyword">my</span> <span class="variable-name">$thing</span> = <span class="sane-perl-nonoverridable">qw</span><span class="string">/
# aaa
# qqq
# ccc
# /;
# print "Yes sir, I can boogie.\n";
# </span>
# 
