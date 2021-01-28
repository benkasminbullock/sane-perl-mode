use FindBin '$Bin';
use lib "$Bin";
use SanePerl;

my $pod = 'L<F<benchmarks/bench>|https://github.com/benkasminbullock/JSON-Parse/801f8ef89cdd640e6666413ad4c025b0a4f0027c/benchmarks/bench>';
my $el = <<EOF;
(sane-perl-mode)
(sane-perl--pod-process-links)
EOF

my ($out, $err) = run_err ($el, $pod);
#TODO: {
#    local $TODO = 'Fix the bug with nested L<F<>>';
ok (! $err);
#};

# http://mikan/bugs/bug/2186

#TODO: {
#    local $TODO = 'Process perlre link';
my $perlre = 'L<perlop/m/PATTERN/msixpodualngc>';
my ($reout, $reerr) = run_err ($el, $perlre);
ok (! $reerr);
#};

done_testing ();
