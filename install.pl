#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use utf8;
use FindBin '$Bin';
use Deploy qw!
    do_system
    local_install
!;

my $outdir = '/home/ben/config/emacs';
my $file = 'sane-perl-mode.el'; 

local_install (
    $file,
    indir => $Bin,
    outdir => $outdir,
    verbose => 1,
    mode => 0444,
    nomastercheck => 1,
);

# https://stackoverflow.com/a/12394284

do_system ("emacs --batch --eval '(byte-compile-file \"$outdir/$file\")'");
