# This is a test for another decade-old bug in cperl-mode where it
# turns }; into }\n;.

use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my $input =<<EOF;
BLOCK: {
};
EOF

TODO: {
    local $TODO = 'Fix trailing semicolon bug';
    my $output = run_indent ($input, '');
    is ($output, $input, "Semicolon bug is not happening");
    unlike ($output, qr!}\n;!, "Explicitly fix this bug");
}

done_testing ();
