# This tests sane-perl-mode.el's ability to invert if (A) {B} into a
# "trailing if" format B if A.

use warnings;
use strict;
use utf8;
use FindBin '$Bin';
use Test::More;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";
use lib "$Bin";
use SanePerl;

my $if = <<EOF;
if (A) {
  B;
}
EOF

my $invertel =<<EOF;
(sane-perl-mode)
(sane-perl-invert-if-unless)
EOF

=for html "monkey business"

=cut

my $invertif = "B if A;\n";

my $out = run ($invertel, $if);
is ($out, $invertif, "Create trailing if");

my $restoreel =<<EOF;
(sane-perl-mode)
(sane-perl-invert-if-unless-modifiers)
EOF

my $revert = run ($restoreel, $out);
is ($revert, $if, "Convert trailing to leading if");

done_testing ();
