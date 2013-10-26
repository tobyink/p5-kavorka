use 5.014;
use strict;
use warnings;

use Kavorka::Signature ();

package Kavorka::Sub;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.012';

use Text::Balanced qw( extract_bracketed );
use Parse::Keyword {};
use Parse::KeywordX;
use Devel::Pragma qw( fqname );

use Moo::Role;
use namespace::sweep;

has keyword         => (is => 'ro');
has signature_class => (is => 'ro', default => sub { 'Kavorka::Signature' });
has package         => (is => 'ro');
has declared_name   => (is => 'rwp');
has signature       => (is => 'rwp');
has prototype       => (is => 'rwp');
has attributes      => (is => 'ro', default => sub { [] });
has body            => (is => 'rwp');
has qualified_name  => (is => 'rwp');

sub allow_anonymous      { 1 }
sub is_anonymous         { !defined( shift->declared_name ) }
sub invocation_style     { +undef }
sub default_attributes   { return; }
sub default_invocant     { return; }
sub forward_declare_sub  { return; }

sub install_sub
{
	my $self = shift;
	my $code = $self->body;
	
	unless ($self->is_anonymous)
	{
		my $name = $self->qualified_name;
		no strict 'refs';
		*{$name} = $code;
	}
	
	$code;
}

sub inject_attributes
{
	my $self = shift;
	join(' ', map sprintf($_->[1] ? ':%s(%s)' : ':%s', @$_), @{ $self->attributes }),
}

sub inject_prelude
{
	my $self = shift;
	$self->signature->injection;
}

sub parse
{
	my $class = shift;
	my $self  = $class->new(@_, package => compiling_package);
	
	lex_read_space;
	
	# sub name
	$self->parse_subname;
	unless ($self->is_anonymous)
	{
		my $qualified = fqname($self->declared_name);
		$self->_set_qualified_name($qualified);
		$self->forward_declare_sub;
	}
	
	# signature
	$self->parse_signature;
	my $sig = $self->signature;
	unless ($sig->has_invocants)
	{
		my @defaults = $self->default_invocant;
		unshift @{$sig->params}, @defaults;
		$sig->_set_has_invocants(scalar @defaults);
	}
	
	# prototype and attributes
	$self->parse_prototype;
	$self->parse_attributes;
	push @{$self->attributes}, $self->default_attributes;
	
	# body
	$self->parse_body;
	
	# clean up
	$self->_set_signature(undef)
		if $sig->_is_dummy;
	
	$self;
}

sub parse_subname
{
	my $self = shift;
	
	my $has_name = (lex_peek(2) =~ /\A(?:\w|::)/);
	$has_name
		or $self->allow_anonymous
		or die "Keyword '${\ $self->keyword }' does not support defining anonymous subs";
	
	$self->_set_declared_name(
		$has_name ? parse_name('subroutine', 1) : undef
	);
	
	();
}

sub parse_signature
{
	my $self = shift;
	lex_read_space;
	
	# default signature
	my $dummy = 0;
	$dummy = 1 && lex_stuff('(...)') if lex_peek ne '(';
	
	lex_read(1);
	my $sig = $self->signature_class->parse(package => $self->package, _is_dummy => $dummy);
	lex_peek eq ')' or die;
	lex_read(1);
	lex_read_space;
	
	$self->_set_signature($sig);
	
	();
}

sub parse_prototype
{
	my $self = shift;
	lex_read_space;
	
	my $peek = lex_peek(1000);
	if ($peek =~ / \A \: \s* \( /xsm )
	{
		lex_read(1);
		lex_read_space;
		$peek = lex_peek(1000);
		
		my $extracted = extract_bracketed($peek, '()');
		lex_read(length $extracted);
		$extracted =~ s/(?: \A\( | \)\z )//xgsm;
		
		$self->_set_prototype($extracted);
	}
	
	();
}

sub parse_attributes
{
	my $self = shift;
	lex_read_space;
	
	if (lex_peek eq ':')
	{
		lex_read(1);
		lex_read_space;
	}
	else
	{
		return;
	}
	
	my $peek;
	while ($peek = lex_peek(1000) and $peek =~ /\A([^\W0-9]\w+)/)
	{
		my $name = $1;
		lex_read(length $name);
		lex_read_space;
		
		my $extracted;
		if (lex_peek eq '(')
		{
			$peek = lex_peek(1000);
			$extracted = extract_bracketed($peek, '()');
			lex_read(length $extracted);
			lex_read_space;
			$extracted =~ s/(?: \A\( | \)\z )//xgsm;
		}
		
		if (lex_peek eq ':')
		{
			lex_read(1);
			lex_read_space;
		}
		
		if ($name eq 'prototype')
		{
			$self->_set_prototype($extracted);
			next;
		}
		
		push @{$self->attributes}, [ $name => $extracted ];
	}
	
	();
}

sub parse_body
{
	my $self = shift;
	
	lex_read_space;
	lex_peek(1) eq '{' or Carp::croak("expected block!");
	lex_read(1);
	
	if ($self->is_anonymous)
	{
		lex_stuff(sprintf("{ %s", $self->inject_prelude));
		
		# Parse the actual code
		my $code = parse_block(0) or Carp::croak("cannot parse block!");
		
		# Set up prototype
		&Scalar::Util::set_prototype($code, $self->prototype);
		
		# Fix sub name
		$code = Sub::Name::subname(join('::', $self->package, '__ANON__'), $code);
		
		# Set up attributes - this doesn't much work
		my $attrs = $self->attributes;
		if (@$attrs)
		{
			require attributes;
			no warnings;
			attributes->import(
				$self->package,
				$code,
				map($_->[0], @$attrs),
			);
		}
		
		# And keep the coderef
		$self->_set_body($code);
	}
	else
	{
		# Here instead of parsing the body we'll leave it to plain old
		# Perl. We'll pick it up later from this name in _post_parse
		
		state $i = 0;
		lex_stuff(
			sprintf(
				"sub Kavorka::Temp::f%d %s { %s",
				++$i,
				$self->inject_attributes,
				$self->inject_prelude,
			)
		);
		$self->{argh} = "Kavorka::Temp::f$i";
	}
	
	();
}

sub _post_parse
{
	my $self = shift;
	
	if ($self->{argh})
	{
		no strict 'refs';
		my $code = \&{ delete $self->{argh} };
		Sub::Name::subname(
			$self->is_anonymous ? join('::', $self->package, '__ANON__') : $self->qualified_name,
			$code,
		);
		&Scalar::Util::set_prototype($code, $self->prototype);
		$self->_set_body($code);
	}
	
	();
}

1;

__END__

=pod

=encoding utf-8

=for stopwords invocant invocants lexicals unintuitive

=head1 NAME

Kavorka::Sub - a function that has been declared

=head1 DESCRIPTION

Kavorka::Sub is a role which represents a function declared using
L<Kavorka>. Classes implementing this role are used to parse functions,
and also to inject Perl code into them.

Instances of classes implementing this role are also returned by
Kavorka's function introspection API.

=head2 Introspection API

A function instance has the following methods.

=over

=item C<keyword>

The keyword (e.g. C<method>) used to declare the function.

=item C<package>

Returns the package name the parameter was declared in. Not necessarily
the package it will be installed into...

   package Foo;
   fun UNIVERSAL::quux { ... }  # will be installed into UNIVERSAL

=item C<is_anonymous>

Returns a boolean indicating whether this is an anonymous coderef.

=item C<declared_name>

The declared name of the function (if any).

=item C<qualified_name>

The name the function will be installed as, based on the package and
declared name.

=item C<signature>

An instance of L<Kavorka::Signature>, or undef.

=item C<prototype>

The function prototype as a string.

=item C<attributes>

The function attributes. The structure returned by this method is
subject to change.

=item C<body>

The function body as a coderef. Note that this coderef I<will> have had
the signature code injected into it.

=back

=head2 Other Methods

=over

=item C<parse>,
C<parse_subname>,
C<parse_signature>,
C<parse_prototype>,
C<parse_attributes>,
C<parse_body> 

Internal methods used to parse a subroutine. It only makes sense to call
these from a L<Parse::Keyword> parser, but may make sense to override
them in classes consuming the Kavorka::Sub role.

=item C<allow_anonymous>

Returns a boolean indicating whether this keyword allows functions to be
anonymous.

The implementation defined in this role returns true.

=item C<signature_class>

A class to use for signatures.

=item C<default_attributes>

Returns a list of attributes to add to the sub when it is parsed.
It would make sense to override this in classes implementing this role,
however attributes don't currently work properly anyway.

The implementation defined in this role returns the empty list.

=item C<default_invocant>

Returns a list invocant parameters to add to the signature if no
invocants are specified in the signature. It makes sense to override
this for keywords which have implicit invocants, such as C<method>.
(See L<Kavorka::Sub::Method> for an example.)

The implementation defined in this role returns the empty list.

=item C<forward_declare_sub>

Method called at compile time to forward-declare the sub, if that
behaviour is desired.

The implementation defined in this role does nothing, but
L<Kavorka::Sub::Fun> actually does some forward declaration.

=item C<install_sub>

Method called at run time to install the sub into the symbol table.

This makes sense to override if the sub shouldn't be installed in the
normal Perlish way. For example L<Kavorka::MethodModifier> overrides
it.

=item C<invocation_style>

Returns a string "fun" or "method" depending on whether subs are
expected to be invoked as functions or methods. May return undef if
neither is really the case (e.g. as with method modifiers).

=item C<inject_attributes>

Returns a string of Perl code along the lines of ":foo :bar(1)" which
is injected into the Perl token stream to be parsed as the sub's
attributes. (Only used for named subs.)

=item C<inject_prelude>

Returns a string of Perl code to inject into the body of the sub.

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Kavorka>.

=head1 SEE ALSO

L<Kavorka::Manual::API>,
L<Kavorka::Signature>.

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

