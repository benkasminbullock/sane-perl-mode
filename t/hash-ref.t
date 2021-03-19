use FindBin '$Bin';
use lib $Bin;
use SanePerl;
my $hr = read_text ("$Bin/hash-ref.pl");
my $ihr = run_indent ($hr);

done_testing ();
