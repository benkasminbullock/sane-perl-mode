#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use utf8;
use FindBin '$Bin';
use Deploy 'local_install';
local_install (
    'sane-perl-mode.el',
    indir => $Bin,
    outdir => '/home/ben/config/emacs',
    verbose => 1,
    mode => 0444,
    nomastercheck => 1,
);
