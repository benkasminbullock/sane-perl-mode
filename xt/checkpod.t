use FindBin '$Bin';
use lib "$Bin/../t/";
use SanePerl;
use Perl::Build::Pod ':all';
for my $filepath ("$Bin/../README.pod") {
    my $errors = pod_checker ($filepath);
    ok (@$errors == 0, "No errors");
    my $linkerrors = pod_link_checker ($filepath);
    ok (@$linkerrors == 0, "No link errors");
    if (@$linkerrors) {
	for my $le (@$linkerrors) {
	    note ($le);
	}
    }
}

done_testing ();
