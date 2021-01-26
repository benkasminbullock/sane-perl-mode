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

use Carp;
use Test::More;
use File::Temp 'tempfile';
use File::Slurper qw!
    read_text
    write_text
!;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = (qw/
    $dir
    $modeel
    run
    run_err
    run_expect
    run_font_lock
    run_indent
    read_text
    tempfile
    write_text
/, @Test::More::EXPORT);


sub import
{
    my ($class) = @_;

    strict->import ();
    utf8->import ();
    warnings->import ();

    File::Slurper->import (qw!read_text write_text!);
    File::Temp->import (qw!tempfile!);
# We already had to do this to use this module.
#    FindBin->import ('$Bin');
    Test::More->import ();

    SanePerl->export_to_level (1);
}

# Put the Test::More encoding adjustments here.

my $builder = Test::More->builder;
binmode $builder->output,         ":encoding(utf8)";
binmode $builder->failure_output, ":encoding(utf8)";
binmode $builder->todo_output,    ":encoding(utf8)";
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";

# Find the lisp file we are testing.

our $dir = __FILE__;
$dir =~ s!/SanePerl\.pm!!;
if (! -d $dir) {
    die "Directory '$dir' not found";
}

our $modeel = "$dir/../sane-perl-mode.el";
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
    my ($el, $text, %options) = @_;

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

    my $output;
    my $status = system ("$command 2> $errfn");
    my $errors;
    if ($status == 0) {
	if (-s $errfn) {
	    $errors = read_text ($errfn);
	}
    }
    else {
	warn "'$command' failed: $!";
    }
    $output = read_text ($textfn);
    # To do: have an option where the user can keep the files, for
    # debugging.
    unlink ($textfn, $errfn, $elfn) or warn "Error unlinking temp files: $!";
    cleanup ();
    if ($options{want_errors}) {
	return ($output, $errors);
    }
    if ($errors) {
	warn "Errors from Emacs as follows: $errors";
    }
    return $output;
}

sub run_err
{
    return run(@_, want_errors => 1);
}

=head2 run_expect

    run_expect ($el, $in, $ex);

Run the Emacs lisp in C<$el> on the Perl input C<$in> and see if one
gets the expected output C<$ex> or not. Runs L<Test::More/is> on the
output of L</run> and compares the outputs. A fourth, optional,
argument may contain a short description of the test:

    run_expect ($el, $in, $ex, "Got correct indentation");

There is no return value.

=cut

sub run_expect
{
    my ($el, $in, $ex, $note) = @_;
    my $out = run ($el, $in);
    is ($out, $ex, $note);
}

=head2 run_font_lock

    my $html = run_font_lock ($in)

Run the included lisp, then run a hacked version of F<htmlize.el> on
the buffer to retrieve the output of fontification (the colouring of
the code on the Emacs window).

=cut

sub run_font_lock
{
    my ($in, $el) = @_;
    if (! $el) {
	$el = '';
    }
    my $fontify = <<EOF;
(add-to-list 'load-path "$dir")
(add-to-list 'load-path "$dir/..")
(setq htmlize-use-rgb-map 'force)
(require 'htmlize)
(require 'sane-perl-mode)
(find-file (pop command-line-args-left))
(sane-perl-mode)
(let ((noninteractive nil))
  (font-lock-mode 1))
(with-current-buffer (htmlize-buffer)
  (princ (buffer-string)))
EOF
    # If the caller specifies lisp, add it before.
    if ($el) {
	$fontify = $el . $fontify;
    }
    my ($inh, $inf) = tempfile ("in.XXXXX", DIR => $dir);
    binmode $inh, ":encoding(utf8)";
    print $inh $in;
    close $inh or die $!;
    my ($outh, $outf) = tempfile ("out.XXXXX", DIR => $dir);
    close $outh or die $!;
    my ($elh, $elf) = tempfile ("el.XXXXX", DIR => $dir);
    binmode $elh, ":encoding(utf8)";
    print $elh $fontify;
    close $elh or die $!;
    my ($errh, $errf) = tempfile ("err.XXXXX", DIR => $dir);
    close $errh or die $!;
    system ("emacs -batch -l $elf $inf > $outf 2> $errf");
    my $out = read_text ($outf);
    my $errors = read_text ($errf);
    # It doesn't run in batch mode without (require 'cl), the error we
    # get is "Symbol’s function definition is void: lexical-let", so
    # I've added the (require 'cl) as a quick fix, but that ends up
    # getting the following error message. 2021-01-20 00:48:52
    $errors =~ s/Package cl is deprecated\s*//;
    if ($errors) {
	print "Errors: $errors\n";
    }
#    print $out;
    unlink ($inf, $outf, $elf, $errf) or warn "Error unlinking temp files: $!";
    cleanup ();
    # Completely unnecessary use of entities for everything in htmlize.el.
    $out =~ s!&#([0-9]+);!chr ($1)!ge;
    return $out;
}

sub cleanup
{
    my @backups = <$dir/*.*.~*~>;
    for (@backups) {
	unlink $_ or warn "Can't remove $_: $!";
    }
}

=head2 run_indent

    run_indent ($in, $el, $expect);

Indent C<$in> using C<sane-perl-mode> with C<$el> specifying
additional Emacs lisp to run. The expected output can be supplied as a
third argument. If C<$expect> is not supplied, it returns the
output. If it is supplied, it tests the output of C<sane-perl-mode>
using L<Test::More/is>:

    is ($output, $expect);

=cut

sub run_indent
{
    my ($in, $el, $expect, $note) = @_;
    my $default_el = <<EOF;
(sane-perl-mode)
(indent-region (point-min) (point-max) nil)
EOF
    my $pel = $el . $default_el;
    my $output = run ($pel, $in);
    if ($expect) {
	is ($output, $expect, $note);
    }
    else {
	return $output;
    }
}

1;

=head1 EXPORTS

This is a module for local testing, so all the functions are exported.

=head1 AUTHOR

Ben Bullock <benkasminbullock@gmail.com>, <bkb@cpan.org>.

=cut
