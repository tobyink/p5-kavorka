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
our $VERSION   = '0.002';

our @ISA         = qw( Exporter::Tiny );
our @EXPORT      = qw( fun method );
our @EXPORT_OK   = qw( fun method after around before classmethod objectmethod );
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
			$subroutine->_post_parse();
			$INFO{ $subroutine->body } = $subroutine;
			
			my @r = wantarray
				? $subroutine->install_sub
				: scalar($subroutine->install_sub);
			
			Scalar::Util::weaken($subroutine->{body})
				unless Scalar::Util::isweak($subroutine->{body});
			
			my $closed_over = PadWalker::closed_over($subroutine->{body});
			my $caller_vars = PadWalker::peek_my(1);
			$closed_over->{$_} = $caller_vars->{$_} for keys %$closed_over;
			PadWalker::set_closed_over($subroutine->{body}, $closed_over);
			
			wantarray ? @r : $r[0];
		},
	);
	
	Parse::Keyword::install_keyword_handler(
		$code => Sub::Name::subname(
			"$me\::parse_$name",
			sub {
				local $Carp::CarpLevel = $Carp::CarpLevel + 1;
				my $subroutine = $implementation->parse(keyword => $name);
				return (
					sub { ($subroutine, $args) },
					!! $subroutine->declared_name,
				);
			},
		),
	);
	
	return ($name => $code);
}

1;

__END__

=pod

=encoding utf-8

=for stopwords invocant invocants lexicals unintuitive yada

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
to be many bugs that still need to be shaken out. Certain syntax
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

Parameters which are not explicitly named, slurpy or invocants, are
positional. For example:

   method foo ( $x, $y ) { ... }

Is roughly equivalent to:

   sub foo {
      my $self = shift;
      die "Expected two parameters" unless @_ == 2;
      my ($x, $y) = @_;
      ...
   }

This feature is shared with Perl 6 signatures, L<Function::Parameters>,
and L<Method::Signatures>.

=head3 Invocants

Invocants are a type of positional parameter, which instead of being
copied from the C<< @_ >> array are shifted off it.

Invocants are always required, and cannot have defaults. Some keywords
(such as C<< method >> and C<< classmethod >>) provide a standard
invocant for you (respectively C<< $self >> and C<< $class >>).

You may specify invocants in the signature manually, in which case the
default provided by the keyword is ignored.

   # The invocant is called $me instead of $self
   method ($me: $x, $y?) { ... }

This feature is shared with Perl 6 signatures, L<Function::Parameters>,
and L<Method::Signatures>. Unique to Kavorka is the ability to specify
multiple invocants.

=head3 Named parameters

Parameters can be named by preceding them with a colon:

   method foo ( :$x, :$y ) { ... }

The method would be called like this:

   $object->foo( x => 1, y => 2 );

This feature is shared with Perl 6 signatures, L<Function::Parameters>,
and L<Method::Signatures>.

Positional parameters (if any) must precede named parameters.

If you have any named parameters, they will also be made available in
the magic global hash C<< %_ >>.

=head3 Long name parameters

Named parameters can be given a different name "inside" and "outside"
the function:

   fun bar ( :public_house($pub) ) { ... }

The function would be called like this:

   bar( public_house => "Rose & Crown" );

... But within the function, the variable would be named C<< $pub >>.

This feature is shared with Perl 6 signatures.

Long named parameters will be available in C<< %_ >> under their
"outside" name, not their "inside" name.

=head3 Optional and required parameters

A trailing exclamation mark makes an attribute required. A trailing
question mark makes an attribute optional.

This feature is shared with Perl 6 signatures and L<Method::Signatures>.

In the absence of explicit indicators, positional parameters will be
required unless a default is provided for them, and named parameters
will be optional.

You can not use named parameters and optional positional parameters in
the same signature.

=head3 Slurpy parameters

The final parameter in the signature may be an array or hash, which
will consume all remaining arguments:

   fun foo ( $x, $y, %z ) { ... }
   
   foo(1..4);  # %z is (3 => 4)

This feature is shared with Perl 6 signatures, L<Function::Parameters>,
and L<Method::Signatures>.

A slurpy array may not be used if the signature contains any named
parameters.

Unique to Kavorka is the ability to specify slurpy arrayrefs or
hashrefs.

   fun foo ( $x, $y, slurpy HashRef $z ) { ... }
   
   foo(1..4);  # $z is { 3 => 4 }

For slurpy references you should specify a type constraint (see
L</Type Constraints>) so that Kavorka can create the correct type of
reference.

=head3 Type constraints

Type constraints may be specified for each parameter in the signature:

   fun foo ( Int $x, HTTP::Tiny $y ) { ... }

This feature is shared with Perl 6 signatures, L<Function::Parameters>,
and L<Method::Signatures>.

Type constraints are parsed as per C<dwim_type> from L<Type::Utils>,
which should mostly do what you mean.

Type constraints for slurpy hashes and arrays are applied to each value
in the hash or each item in the array. Type constraints for slurpy
references are instead applied to the reference as a whole. Therefore
the following are roughly equivalent:

   fun foo ( Str %z ) { my $z = \%z; ... }
   fun foo ( slurpy HashRef[Str] $z ) { ... }

Type constraints may be surrounded with parentheses, in which case,
instead of parsing them with C<dwim_type>, they'll be evaluated (at
compile time) as an expression which is expected to return a blessed
L<Type::Tiny> object:

   use Types::Standard qw( LaxNum StrictNum );
   
   fun foo ( ($ENV{AUTOMATED_TESTING} ? StrictNum : LaxNum) $x ) {
      ...;
   }

This feature is shared with L<Function::Parameters>.

=head3 Value constraints

Value constraints can be used to further constrain values. Value
constraints are specified using the C<where> keyword followed by a
block.

   fun foo ( Int $even where { $_ % 2 == 0 } )

Multiple C<where> blocks may be provided:

   fun foo ( Int $even where { $_ % 2 == 0 } where { $_ > 0 } )

This feature is shared with Perl 6 signatures and L<Method::Signatures>.

The non-block form of C<where> supported by L<Method::Signatures> is
not supported by Kavorka, but can be emulated using L<match::simple>:

   # Method::Signatures allows this (performing smart match):
   #
   method foo ( Int $x where $y ) {
      ...
   }
   
   # For Kavorka, try this:
   #
   method foo ( Int $x where { match($_, $y) } ) {
      ...
   }

=head3 Defaults

Defaults may be provided using an equals sign:

   fun foo ( $greeting = "Hello world" ) {
      ...
   }

This feature is shared with Perl 6 signatures, L<Function::Parameters>,
and L<Method::Signatures>.

Kavorka will use the default if the argument is not given when the
function is invoked. If an explicit undef is passed to the function
when it is called, this is accepted as the value for the parameter, and
the default is not used.

If instead you want the default to take effect when an explicit undef
is passed to the function, use C<< //= >>:

   fun foo ( $greeting //= "Hello world" ) {
      ...
   }

This feature is shared with L<Method::Signatures>. Kavorka doesn't
support Method::Signatures' C<when> keyword.

Slurpy parameters may take defaults:

   fun foo ( @bar = (1, 2, 3) ) { ... }

For slurpy references, the syntax is a little unintuitive:

   fun foo ( slurpy ArrayRef $bar = (1, 2, 3) ) { ... }

=head3 Traits

Traits may be added to each parameter using the C<is> keyword:

   fun foo ( $greeting is polite = "Hello world" ) { ... }
   
   fun bar ( $baz is quux is xyzzy ) { ... }

The keyword C<does> is also available which acts as an alias for C<is>.

This feature is shared with Perl 6 signatures and L<Method::Signatures>.

You can use pretty much any word you like as a trait; Kavorka doesn't
check that they're "valid" or anything. Choosing random words of course
won't do anything, but the traits are available through the
introspection API.

The traits Kavorka understands natively are:

=over

=item *

C<alias> - makes your lexical variable into an alias for an item within
the C<< @_ >> array.

   fun increment (Int $i) { ++$i }
   
   my $count = 0;
   increment($count);
   increment($count);
   increment($count);
   say $count;          # says 3

But please don't use this for parameters with coercions!

This feature is shared with L<Method::Signatures>.

=item *

C<coerce> - see L</Type coercion> below.

=item *

C<locked> - locks hash(ref) keys - see L<Hash::Util>. For references
this trait has the unfortunate side-effect of leaving the hashref
locked I<outside> the function too!

This trait has special support for the C<Dict> type constraint from
L<Types::Standard>, including optional keys in the list of allowed
keys.

   fun foo (HashRef $x is locked) {
      $x->{foo} = 1;
   }
   
   my $var1 = { foo => 42 };
   foo($var1);
   say $var1->{foo};           # says 1
   
   my $var2 = { bar => 42 };
   foo($var2);                 # dies

=item *

C<optional> - yes, the C<?> and C<!> syntax is just a shortcut for a
trait.

   fun foo ($x is optional) { ... }            # These two declarations
   fun foo ($x?) { ... }                       # are equivalent.

=item *

C<ro> - makes the parameter a (shallow) read-only variable.

   fun foo ($x is ro) { $x++ }
   
   foo(42);   # dies

This feature is shared with Perl 6 signatures.

=item *

C<rw> - this is the default, so is a no-op, but if you have a mixture
of read-only and read-write variables, it may aid clarity to explicitly
add C<is rw> to the read-write ones.

=item *

C<slurpy> - the slurpy prefix to the type constraint is just a shortcut
for a trait.

   fun foo ( ArrayRef $bar is slurpy ) { ... } # These two declarations
   fun foo ( slurpy ArrayRef $bar ) { ... }    # are equivalant

=back

=head3 Type coercion

Coercion can be enabled for a parameter using the C<coerce> constraint.

   use Types::Path::Tiny qw(AbsPath);
   
   method print_to_file ( AbsFile $file does coerce, @lines ) {
      $file->spew(@lines);
   }

This feature is shared with L<Method::Signatures>.

=head3 The Yada Yada

Normally passing additional parameters to a function declared with a
signature will throw an exception:

   fun foo ($x) {
      return $x;
   }
   
   foo(1, 2);    # error - too many arguments

Adding the yada yada operator to the end of the signature allows the
function to accept extra trailing parameters:

   fun foo ($x, ...) {
      return $x;
   }
   
   foo(1, 2);    # ok

This feature is shared with L<Method::Signatures>.

See also L<http://en.wikipedia.org/wiki/The_Yada_Yada>.

=head2 The Prototype

Like with the L<sub|perlsub> keyword, a prototype may be provided for
functions. Method dispatch ignores this, so it's only likely to be
useful for C<fun>, and even then, rarely.

Like L<Function::Parameters>, Kavorka uses C<< :(...) >> to indicate
a prototype. This avoids ambiguity between signatures, prototypes and
attributes.

=head2 The Attributes

Attributes are parsed as per L<perlsub/Subroutine Attributes>.

For anonymous functions, some attributes (e.g. C<:lvalue>) may be
applied too late to take effect. Attributes should mostly work for
named functions though.

=head2 The Function Body

This is more or less what you'd expect from the function body you'd
write with L<sub|perlsub>, however the lexical variables for parameters
are pre-declared and pre-populated, and invocants have been shifted
off C<< @_ >>.

=head2 Introspection API

The coderef for any sub created by Kavorka can be passed to the
C<< Kavorka->info >> method. This returns a blessed object that
does the L<Kavorka::Sub> role.

   fun foo (:$x, :$y) { }
   
   my $info = Kavorka->info(\&foo);
   
   my $function_name = $info->qualified_name;
   my @named_params  = $info->signature->named_params;
   
   say $named_params[0]->named_names->[0];   # says 'x'

See L<Kavorka::Sub>, L<Kavorka::Signature> and
L<Kavorka::Signature::Parameter> for further details.

If you're using Moose, consider using L<MooseX::KavorkaInfo> to expose
Kavorka method signatures via the meta object protocol.

=head2 Exports

=over

=item C<< -default >>

Exports C<fun> and C<method>.

=item C<< -modifiers >>

Exports C<before>, C<after>, and C<around>.

=item C<< -all >>

Exports C<fun>, C<method>, C<before>, C<after>, C<around>,
C<classmethod>, and C<objectmethod>.

=back

For example:

   # Everything except objectmethod...
   use Kavorka qw( -default -modifiers classmethod );

You can rename imported functions (see L<Exporter::Tiny>):

   use Kavorka method => { -as => 'meth' };

You can provide alternative implementations:

   # use My::Sub::Method instead of Kavorka::Sub::Method
   use Kavorka method => { implementation => 'My::Sub::Method' };

=head1 CAVEATS

As noted above, subroutine attributes don't work for anonymous
functions.

If importing Kavorka's method modifiers into Moo/Mouse/Moose classes,
pay attention to load order:

   use Moose;
   use Kavorka -all;   # ok

If you do it this way, Moose's C<before>, C<after>, and C<around>
keywords will stomp on top of Kavorka's...

   use Kavorka -all;
   use Moose;          # STOMP, STOMP, STOMP!  :-(

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Kavorka>.

=head1 SEE ALSO

L<http://perlcabal.org/syn/S06.html>,
L<Function::Parameters>,
L<Method::Signatures>.

L<Kavorka::Sub>,
L<Kavorka::Signature>,
L<Kavorka::Signature::Parameter>.

L<http://en.wikipedia.org/wiki/The_Conversion_(Seinfeld)>.

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

