#!/home/ben/software/install/bin/perl

# Oneoff to rewrite all the files under test to change cperl to
# sane-perl.

use Z;
my $verbose = 1;
rename_files ("test");
exit;
sub rename_files
{
    my ($file) = @_;
    if (-f $file) {
	my $newname = $file;
	$newname =~ s!cperl([^/]*$)!sane-perl$1!g;
	if ($newname ne $file) {
	    do_system ("git mv $file $newname", $verbose);
	}
    }
    elsif (-d $file) {
	print "Going into $file\n";
	my @files = <$file/*>;
	for (@files) {
	    rename_files ($_);
	}
    }
    else {
	print "No option for $file.\n";
    }
}
