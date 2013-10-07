use 5.014;
use strict;
use warnings;

use Kavorka::Signature ();

package Kavorka::Sub;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.000_05';

use Text::Balanced qw( extract_codeblock extract_bracketed );
use Parse::Keyword {};
use Parse::KeywordX;
use Devel::Pragma qw( fqname );

use Moo::Role;
use namespace::sweep;

has signature_class => (is => 'ro', default => sub { 'Kavorka::Signature' });
has package         => (is => 'ro');
has declared_name   => (is => 'rwp');
has signature       => (is => 'rwp');
has prototype       => (is => 'rwp');
has attributes      => (is => 'ro', default => sub { +[] });
has body            => (is => 'rwp');
has qualified_name  => (is => 'rwp');

sub parse
{
	my $class = shift;

	my $self = $class->new(package => compiling_package);
	
	lex_read_space;
	
	my $subname = $self->_set_declared_name( (lex_peek =~ /\w|:/) ? parse_name('subroutine', 1) : undef );
	my $sig     = $self->_set_signature( $self->parse_signature );
	my $proto   = $self->_set_prototype( $self->parse_prototype );
	my $attrs   ; push @{$attrs = $self->attributes}, $self->parse_attributes;
	
	push @$attrs, $self->default_attributes;
	unless ($sig->has_invocants)
	{
		unshift @{$sig->params}, $self->default_invocant;
		$sig->_set_has_invocants(1);
	}
	if (!!$subname)
	{
		$self->_set_qualified_name(scalar fqname($subname));
	}
	
	lex_read_space;
	lex_peek(1) eq '{' or die "expected block!";
	lex_read(1);
	lex_stuff(sprintf("{ %s", $self->inject_signature));
	
#	warn lex_peek(1000) if $subname eq 'bar';;
	
	my $code = parse_block(!!$subname) or die "cannot parse block!";
	&Scalar::Util::set_prototype($code, $self->prototype);
	if (@$attrs)
	{
		require attributes;
		no warnings;
		attributes->import(
			compiling_package,
			$code,
			map($_->[0], @$attrs),
		);
	}
	
	$self->_set_body($code);

	$self->forward_declare_sub if !!$subname;
	
	return $self;
}

sub default_attributes
{
	return;
}

sub default_invocant
{
	return;
}

sub forward_declare_sub
{
	return;
}

sub install_sub
{
	my $self = shift;
	my $name = $self->qualified_name;
	my $code = $self->body;
	
	no strict 'refs';
	*{$name} = $code if defined $name;
	return $code;
}

sub inject_attributes
{
	my $self = shift;
	join(' ', map sprintf($_->[1] ? ':%s(%s)' : ':%s', @$_), @{ $self->attributes }),
}

sub inject_prototype
{
	my $self  = shift;
	my $proto = $self->prototype;
	defined($proto) ? "($proto)" : "";
}

sub inject_signature
{
	my $self = shift;
	$self->signature->injections;
}

sub parse_signature
{
	my $self = shift;
	lex_read_space;
	
	# default signature
	lex_stuff('(...)') unless lex_peek eq '(';
	
	lex_read(1);
	my $sig = $self->signature_class->parse(package => $self->package);
	lex_peek eq ')' or die;
	lex_read(1);
	lex_read_space;
	return $sig;
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
		return $extracted;
	}
	
	undef;
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
	
	my @attrs;
	
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
			$extracted = extract_codeblock($peek, '(){}[]<>', undef, '()');
			lex_read(length $extracted);
			lex_read_space;
			$extracted =~ s/(?: \A\( | \)\z )//xgsm;
		}
		
		if (lex_peek eq ':')
		{
			lex_read(1);
			lex_read_space;
		}
		
		push @attrs, [ $name => $extracted ];
	}
	
	@attrs;
}

1;
