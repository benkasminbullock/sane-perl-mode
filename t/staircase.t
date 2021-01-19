# https://github.com/jrockway/cperl-mode/issues/32

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

my $origel = <<EOF;
(defun my-cperl-mode-defaults ()
  (setq cperl-close-paren-offset -2
        cperl-close-brace-offset -2
        cperl-continued-statement-offset 2
        cperl-continued-brace-offset 2
        cperl-fix-hanging-brace-when-indent t
        cperl-indent-level 2
       cperl-indent-parens-as-block t
       cperl-tabs-always-indent t)

  (setq cperl-hairy)
  )
EOF

$origel =~ s!cperl!sane-perl!g;
my $el =<<EOF;
(sane-perl-mode)
$origel
EOF

my $in = <<'EOF';
use constant {
  ONE => 1,
  TWO => 2
};
EOF

run_expect ($el, $in, $in, "Staircase bug");

done_testing ();
