use FindBin '$Bin';
use lib $Bin;
use SanePerl;
my $hr = read_text ("$Bin/hash-ref.pl");
my $ihr = run_indent ($hr);
TODO: {
    local $TODO = 'Fix wonky hash reference indentation';
    like ($ihr, qr!\{.*\}!, "{ and } on the same line");
    unlike ($ihr, qr!\{[^\}]*$!m, "{ not on its own line");
    unlike ($ihr, qr![^\{]\}.*$!m, "} not on its own line");
}
done_testing ();
