use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my $ifelse = read_text ("$Bin/ex/if-else.pl");
my $ifelse_no_merge = read_text ("$Bin/ex/if-else-no-merge.pl");

run_indent ($ifelse, '', $ifelse, "Get } else { as default");
my $nomergeel = "(setq sane-perl-merge-trailing-else nil)\n";
run_indent ($ifelse, $nomergeel, $ifelse_no_merge, "Get } \\n else {");
done_testing ();
