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

my $rein = <<'EOF';
my $re = qr!
    (
	something
    |
	or
    |
	another
    )
!x;
EOF

my $reel = <<EOF;
(sane-perl-mode)
(setq sane-perl-indentable-indent nil)
(setq sane-perl-indent-level 4)
(indent-region (point-min) (point-max) nil)
EOF

run_expect ($reel, $rein, $rein);

done_testing ();
