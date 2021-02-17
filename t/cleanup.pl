#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use utf8;
use FindBin '$Bin';
chdir $Bin or die $!;
my @bad = <el.*>;
push @bad, <err.*>;
push @bad, <txt.*>;
for (@bad) {
    print "$_\n";
    unlink $_ or die $!;
}
