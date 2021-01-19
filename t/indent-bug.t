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

my $sub = <<'EOF';
sub run
{
    my ($thing) = @_;
}
EOF

my $el = <<EOF;
(sane-perl-mode)
(setq sane-perl-indent-level 4)
(setq sane-perl-continued-statement-offset 4)
(indent-region (point-min) (point-max) nil)
EOF

#TODO: {
#    local $TODO = 'Fix continued-statement-offset bug';
    my $output = run ($el, $sub);
    is ($output, $sub);
#};

done_testing ();
