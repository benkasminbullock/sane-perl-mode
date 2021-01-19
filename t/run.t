# Basic tests for sane-perl-mode.el, see also SanePerl.pm in this
# directory.

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

# Test that the thing basically works

my $input = "qw/monkeys on a plane/";
my $output = run ('(insert "#!perl")', $input);
is ($output, "#!perl$input", "Was able to run script");

my $html = run_font_lock ("#!perl\nuse Funky::Module;\n");

ok ($html, "Got html back");
like ($html, qr!<span!, "Looks like HTML");

# Test that the wacky default behaviour remains intact unless the user
# switches it off.

my $qwin=<<'EOF';
my $x = qw!
             too
             far
             right
          !;
EOF
my $qwdefaultel = <<EOF;
(sane-perl-mode)
(indent-region (point-min) (point-max) nil)
EOF
my $farright = run ($qwdefaultel, $qwin);
is ($farright, $qwin, "Got expected far-right behaviour without option");

# Test that we can use the *normal indentation* and not get everything
# shoved far to the right, if the user chooses to do so.

my $qwnormalel = <<EOF;
(sane-perl-mode)
(setq sane-perl-indentable-indent nil)
(setq sane-perl-indent-level 4)
(indent-region (point-min) (point-max) nil)
EOF

my $qwnormal =<<'EOF';
my $x = qw!
    too
    far
    right
!;
EOF
my $qw = run ($qwnormalel, $qwin);
is ($qw, $qwnormal, "Got expected normal indentation with option");

done_testing ();
