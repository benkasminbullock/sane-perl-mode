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
if (A) { B }
EOF

my $invertel =<<EOF;
(sane-perl-mode)
(sane-perl-invert-if-unless)
EOF

my $invertif = "B if A;\n";

my $out = run ($invertel, $if);
is ($out, $invertif);
done_testing ();
