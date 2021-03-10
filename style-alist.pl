#!/home/ben/software/install/bin/perl

# Make the table of constants for the documentation.

use warnings;
use strict;
use utf8;
use FindBin '$Bin';
use JSON::Parse 'read_json';
use JSON::Create 'create_json';
use Text::Table::Tiny 'generate_table';
use List::Util 'uniq';
my $styles = read_json ("$Bin/style-alist.json");
#print create_json ($styles, sort => 1, indent => 1);
my @keys;
my @styles;
for my $style (keys %$styles) {
#    print "$style\n";
    if ($style eq 'Current') {
	next;
    }
    push @styles, $style;
    my @jkeys = keys %{$styles->{$style}};
    push @keys, @jkeys;
}
@keys = uniq sort @keys;
my @rows;
@styles = sort @styles;
my @simpstyles = @styles;
for (@simpstyles) {
    $_ = substr ($_, 0, 4);
}
push @rows, ['', @simpstyles];
my @simplekeys;
for my $key (@keys) {
    my @row;
    my $simplekey = $key;
    $simplekey =~ s!^sane-perl-!!;
    $simplekey =~ s!([a-z])[a-z]+!$1!g;
    push @row, $simplekey;
    push @simplekeys, $simplekey;
    for my $style (@styles) {
	# create_json is just used to pull the "true" and "null"
	# values out of $styles, othewise we get 1 and blank.
	my $cell = create_json ($styles->{$style}{$key});
	if ($cell eq 'true') {
	    $cell = 't';
	}
	if ($cell eq 'null') {
	    $cell = 'nil';
	}
	push @row, $cell;
    }
    push @rows, \@row;
}
print STDOUT generate_table (
    rows => \@rows,
    align => ['l', ('r') x (scalar (@styles))],
#    style => 'norule',
#    compact => 1,
), "\n";
for my $i (0..$#keys) {
    print "$simplekeys[$i] = $keys[$i]\n";
}



