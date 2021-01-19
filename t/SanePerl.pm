=head1 NAME

SanePerl - tests for sane-perl-mode.el

=head1 DESCRIPTION

This is a helper for running Emacs in batch mode with the file under
test and getting the results back.

=head1 FUNCTIONS

=cut

package SanePerl;
use warnings;
use strict;
use utf8;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw/run/;
use Carp;
use Test::More;
use File::Temp 'tempfile';
use File::Slurper qw!read_text write_text!;

# Find the lisp file we are testing.

my $dir = __FILE__;
$dir =~ s!/SanePerl\.pm!!;
if (! -d $dir) {
    die "Directory '$dir' not found";
}

my $modeel = "$dir/../sane-perl-mode.el";
if (! -f $modeel) {
    die "Lisp file '$modeel' not found";
}

=head2 run

     my $output = run ($el, $text);

Run F<sane-perl-mode.el> and the Emacs lisp you specify in C<$el> on
C<$text>, and then return the result of the processing.

This uses L<File::Temp/tempfile> to create temporary files for the
lisp and the text and for error output, and then it deletes the files
at the end of processing.

=cut

sub run
{
    my ($el, $text) = @_;

    # Write the emacs lisp into a temporary file
    my ($elfh, $elfn) = tempfile ("el.XXXXXX", DIR => $dir);
    print $elfh $el;
    close $elfh or die $!;

    # Write the text into a temporary file
    my ($textfh, $textfn) = tempfile ("txt.XXXXXX", DIR => $dir);
    print $textfh $text;
    close $textfh or die $!;

    # Error file
    my ($errfh, $errfn) = tempfile ("err.XXXXXX", DIR => $dir);

    # Make a command to run Emacs without .emacs

    # This is slightly annoying to get right because Emacs seems to
    # not like having the commands in the wrong order. It seems that
    # the -batch has to come first. Also, for some reason if I put
    # (save-buffer) in the lisp, Emacs drops out of batch mode and
    # asks for the file name.

    my $command = "emacs -batch $textfn --load=$modeel --load=$elfn -f save-buffer";

    system ("$command 2> $errfn") == 0 or die "'$command' failed: $!";
    if (-s $errfn) {
	# This hasn't happened yet, probably need to do this better.
	print "Errors: ";
	my $errors = read_text ($errfn);
	print $errors;
    }
    my $output = read_text ($textfn);
    # To do: have an option where the user can keep the files, for
    # debugging.
    unlink ($textfn, $errfn, $elfn) or warn "Error unlinking temp files: $!";
    return $output;
}

1;

=head1 EXPORTS

This is a module for local testing, so all the functions are exported.

=head1 AUTHOR

Ben Bullock <benkasminbullock@gmail.com>, <bkb@cpan.org>.

=cut
