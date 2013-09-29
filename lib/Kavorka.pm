use 5.014;
use strict;
use warnings;

use Carp ();
use Exporter::Tiny ();
use PadWalker ();
use Parse::Keyword ();
use Module::Runtime ();
use Scalar::Util ();
use Sub::Name ();

package Kavorka;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

our @ISA         = qw( Exporter::Tiny );
our @EXPORT      = qw( fun method );
our %EXPORT_TAGS = (
	modifiers => [qw( after around before )],
);

our %IMPLEMENTATION = (
	after        => 'Kavorka::Sub::After',
	around       => 'Kavorka::Sub::Around',
	before       => 'Kavorka::Sub::Before',
	classmethod  => 'Kavorka::Sub::ClassMethod',
	fun          => 'Kavorka::Sub::Fun',
	func         => 'Kavorka::Sub::Fun',
	function     => 'Kavorka::Sub::Fun',
	method       => 'Kavorka::Sub::Method',
	objectmethod => 'Kavorka::Sub::ObjectMethod',
);

our %INFO;

sub info
{
	my $me = shift;
	my $code = $_[0];
	$INFO{$code};
}

sub _exporter_expand_sub
{
	my $me = shift;
	my ($name, $args, $globals) = @_;
	
	my $implementation =
		$args->{'implementation'}
		// $IMPLEMENTATION{$name}
		// $me;
	
	Module::Runtime::use_package_optimistically($implementation)->can('parse')
		or Carp::croak("No suitable implementation for keyword '$name'");
	
	no warnings 'void';
	my $code = Sub::Name::subname(
		"$me\::$name",
		sub {
			$name; # close over name to prevent optimization
			my $subroutine = shift;
			$INFO{ $subroutine->body } = $subroutine;
			my @r = wantarray ? $subroutine->install_sub : scalar($subroutine->install_sub);
			Scalar::Util::weaken($subroutine->{body}) unless Scalar::Util::isweak($subroutine->{body});
			
			my $closed_over = PadWalker::closed_over($subroutine->{body});
			my $caller_vars = PadWalker::peek_my(1);
			$closed_over->{$_} = $caller_vars->{$_} for keys %$closed_over;
			PadWalker::set_closed_over($subroutine->{body}, $closed_over);
			
			wantarray ? @r : $r[0];
		},
	);
	
	Parse::Keyword::install_keyword_handler(
		$code => sub {
			my $subroutine = $implementation->parse;
			return (
				sub { ($subroutine, $args) },
				!! $subroutine->declared_name,
			);
		},
	);
	
	return ($name => $code);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Kavorka - function signatures with the lure of the animal

=head1 SYNOPSIS

   use Kavorka;
   
   fun maxnum (Num @numbers) {
      my $max = shift @numbers;
      for (@numbers) {
         $max = $_ if $max < $_;
      }
      return $max;
   }
   
   my $biggest = maxnum(42, 3.14159, 666);

=head1 STATUS

Kavorka is still at a very early stage of development; there are likely
to be many bugs that still need to be shaked out. Certain syntax
features are a little odd and may need to be changed in incompatible
ways.

=head1 DESCRIPTION

Kavorka provides C<fun> and C<method> keywords for declaring functions
and methods. It uses Perl 5.14's keyword API, so should work more
reliably than source filters or L<Devel::Declare>-based modules.

=head2 Basic Syntax

The syntax provided by Kavorka is largely inspired by Perl 6, though
it has also been greatly influenced by L<Method::Signatures> and
L<Function::Parameters>.

The anatomy of a function:

=over

=item 1.

The keyword introducing the function.

=item 2.

The function name (optional).

=item 3.

The signature (optional).

=item 4.

The prototype (optional).

=item 5.

The attribute list (optional).

=item 6.

The function body.

=back

Example:

   #  (1) (2)    (3)          (4)   (5)     (6)
      fun foobar ($foo, $bar) :($$) :cached { return $foo + $bar }
   
   #          (1) (6)
      my $f = fun { return $_[0] + $_[1] };

=head2 The Keyword

By default this module exports the keywords C<fun> and C<method>. These
keywords are respectively implemented by L<Kavorka::Sub::Fun> and
L<Kavorka::Sub::Method>. Other keywords may be imported upon request:
C<after>, C<around>, C<before>, C<classmethod> and C<objectmethod>.

The module implementing the keyword may alter various aspects of the
keyword's behaviour. For example, C<fun> ensures that the function's
name and prototype is declared at compile time; C<method> shifts the
invocant off C<< @_ >>; and C<before>, C<after> and C<around> pass the
body coderef to your OO framework's method modifier installation
function.

See the implementing modules' documentation for further details.

=head2 The Function Name

If present, it specifies the name of the function being defined. As
with C<sub>, if a name is present, by default the whole declaration is
syntactically a statement and its effects are performed at compile time
(i.e. at runtime you can call functions whose definitions only occur
later in the file). If no name is present, the declaration is an
expression that evaluates to a reference to the function in question.

=head2 The Signature

The signature consists of a list of parameters for the function.

Each parameter is a variable name which will be available within the
body of the function. Variable names are assumed to be lexicals unless
they look like punctuation variables or escape-character global
variables, in which case they'll be implicitly localized within the
function.

Parameters are separated with commas, however if one of the commas
is replaced by a colon, all parameters to the left are assumed to be
invocants and are shifted off C<< @_ >>. If no invocants are explicitly
listed as part of the signature, the module implementing the keyword
may assume a default invocant - for example, C<method> assumes an
invocant called C<< $self >> while C<around> assumes two invocants
called C<< ${^NEXT} >> and C<< $self >>.

=head3 Positional parameters

=head3 Named parameters

=head3 Optional and required parameters

=head3 Slurpy parameters

=head3 Invocants

=head3 Type constraints

=head3 Value constraints

=head3 Defaults

=head3 Traits

=head3 Type coercion

=head2 The Prototype

Like with the L<sub|perlsub> keyword, a prototype may be provided for
functions. Method dispatch ignores this, so it's only likely to be
useful for C<fun>, and even then, rarely.

Like L<Function::Parameters>, Kavorka uses C<< :(...) >> to indicate
a prototype. This avoids ambiguity between signatures, prototypes and
attributes.

=head2 The Attributes

Attributes are currently parsed but ignored. Due to a limitation in
current versions of L<Parse::Keyword>, there's little we can do with
them.

=head2 The Function Body

This is more or less what you'd expect from the function body you'd
write with L<sub|perlsub>, however the lexical variables for parameters
are pre-declared and pre-populated, and invocants have been shifted
off C<< @_ >>.

=head2 Introspection API

The coderef for any sub created by Kavorka can be passed to the
C<< Kavorka->info >> method. This returns a blessed object that
does the L<Kavorka::Sub> role.

   fun foo { }
   
   my $info = Kavorka->info(\&foo);
   
   my $function_name = $info->qualified_name;
   my @named_params  = grep $_->named, @{$info->signature->params};

See L<Kavorka::Sub>, L<Kavorka::Signature> and
L<Kavorka::Signature::Parameter> for further details.

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Kavorka>.

=head1 SEE ALSO

L<http://perlcabal.org/syn/S06.html>,
L<Function::Parameters>,
L<Method::Signatures>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

