#!/home/ben/software/install/bin/perl

# Oneoff to rewrite all the files under test to change cperl to
# sane-perl.

use Z;
rewrite_files ("original-tests");
exit;
sub rewrite_files
{
    my ($file) = @_;
    if (-f $file) {
	my $text = read_text ($file);
	my $old = $text;
	$text =~ s!cperl!sane-perl!g;
	$text =~ s!github.com/(.*?)/sane-perl-mode!github.com/$1/cperl-mode!g;
	if ($text ne $old) {
	    print "Altering $file.\n";
	    write_text ($file, $text);
	}
    }
    elsif (-d $file) {
	print "Going into $file\n";
	my @files = <$file/*>;
	for (@files) {
	    rewrite_files ($_);
	}
    }
    else {
	print "No option for $file.\n";
    }
}
