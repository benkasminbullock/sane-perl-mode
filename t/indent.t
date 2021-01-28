# Tests related to indentation.

use FindBin '$Bin';
use lib "$Bin";
use SanePerl;


my $ifelse = read_text ("$Bin/ex/if-else.pl");
my $ifelse_no_merge = read_text ("$Bin/ex/if-else-no-merge.pl");

run_indent ($ifelse, '', $ifelse, "Get } else { as default");
my $nomergeel = "(setq sane-perl-merge-trailing-else nil)\n";
run_indent ($ifelse, $nomergeel, $ifelse_no_merge, "Get } \\n else {");

TODO: {
    local $TODO = 'fix indentation of hash refs';

    # http://mikan/bugs/bug/2189

    # This is from ~/projects/kanji/ui/build/make-www-files.pl

    my $hash_ref =<<'EOF';
sub write_html
{
    for my $js_file (@js_files) {
	tt ($tt, \$js_input, \%vars, \$js_text);
	if ($js_text) {
	    $js_text = $jl->process (
		$js_text,
	    {loaded  => \%already_loaded,
	     no_load => \%no_load,
	     #verbose => 1
	 });
	}
    }
}
EOF

    my $hash_ref_want =<<'EOF';
sub write_html
{
    for my $js_file (@js_files) {
	tt ($tt, \$js_input, \%vars, \$js_text);
	if ($js_text) {
	    $js_text = $jl->process (
		$js_text,
	        {loaded  => \%already_loaded,
	         no_load => \%no_load,
	         #verbose => 1
	    });
	}
    }
}
EOF
    my $el =<<EOF;
(setq sane-perl-indent-level 4)
(setq sane-perl-indentable-indent nil)
(setq sane-perl-brace-offset -4)
EOF
    my $got = run_indent ($hash_ref, $el);
    is ($got, $hash_ref_want, "indentation of hash ref in arguments bug");
};

done_testing ();
