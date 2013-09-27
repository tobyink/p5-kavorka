use 5.014;
use strict;
use warnings;

use PerlX::Method::Signature ();

package PerlX::Method::Sub;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Text::Balanced qw( extract_codeblock extract_bracketed );

use Moo::Role;

has signature_class => (is => 'ro', default => sub { 'PerlX::Method::Signature' });
has package         => (is => 'ro');
has declared_name   => (is => 'rwp');
has signature       => (is => 'rwp');
has prototype       => (is => 'rwp');
has attributes      => (is => 'ro', default => sub { +[] });

our $ref;
our $caller;

sub handle_keyword
{
	my $class = shift;
	local $ref    = $_[0];
	local $caller = $_[1];

#	warn "====================\n".$$ref;

	my $self = $class->new(package => $caller);
	
	$self->_strip_space;
	
	my $subname = $self->_set_declared_name($self->_strip_name);
	my $sig     = $self->_set_signature($self->_strip_signature);
	my $proto   = $self->_set_prototype($self->_strip_prototype);	
	my $attrs   ; push @{$attrs = $self->attributes}, $self->_strip_attributes;
	
	push @$attrs, $self->default_attributes;
	unshift @{$sig->params}, $self->default_invocant
		unless $sig->has_invocants;
	
	$self->_strip_space;
	$$ref =~ s/\A\{// or die "expected block!";

	substr($$ref, 0, 0) = sprintf(
		'sub %s %s { %s %s;;',
		defined($proto) ? "($proto)" : '',
		join(' ', map {
			my ($attr, $attr_p) = @$_;
			defined($attr_p)
				? sprintf(':%s(%s)', $attr, $attr_p)
				: sprintf(':%s', $attr)
		} @$attrs),
		$sig->injections,
		("\n" x ($self->{skipped_lines}||0)),
	);

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

sub _strip_space
{
	my $self = shift;
	
	my $X;
	while (
		($$ref =~ m{\A( \s+ )}xsm and $X = 1)
		or ($$ref =~ m{\A\#} and $X = 2)
	) {
		$X==2
			? ($$ref =~ s{\A\#.+?\n}{}sm)
			: substr($$ref, 0, length($1), '');
		
		$self->{skipped_lines} += $X==2
			? 1
			: (my @tmp = split /\n/, $1, -1)-1;
	}
	
	();
}

sub _strip_name
{
	my $self = shift;
	$self->_strip_space;
	
	if ( $$ref =~ / \A ((?:\w|::)+) /x )
	{
		my $name = $1;
		substr($$ref, 0, length($name), '');
		return $name;
	}
	
	undef;
}

sub _strip_signature
{
	my $self = shift;	
	$self->_strip_space;
	
	if ( $$ref =~ / \A \( /x )
	{
		my $extracted = extract_codeblock($$ref, '(){}[]<>', undef, '()');
		$extracted =~ s/(?: \A\( | \)\z )//xgsm;
		my $sig = $self->signature_class->parse($extracted, package => $self->package);
		$self->{skipped_lines} += scalar(my @tmp = split /\n/, $sig->as_string) - 1;
		return $sig;
	}
	
	return $self->signature_class->parse('...', package => $self->package);
}

sub _strip_prototype
{
	my $self = shift;
	
	$self->_strip_space;
	
	if ( $$ref =~ / \A \: \s* \( /xsm )
	{
		$$ref =~ s/\A\://;
		$self->_strip_space;
		
		my $extracted = extract_bracketed($$ref, '()');
		$extracted =~ s/(?: \A\( | \)\z )//xgsm;
		return $extracted;
	}
	
	undef;
}

sub _strip_attributes
{
	my $self = shift;	
	$self->_strip_space;
	
	if ($$ref =~ /\A:/)
	{
		substr($$ref, 0, 1, '');
		$self->_strip_space;
	}
	else
	{
		return;
	}
	
	my @attrs;
	
	while ($$ref =~ /\A([^\W0-9]\w+)/)
	{
		my $name = $1;
		substr($$ref, 0, length($name), '');
		$self->_strip_space;
		
		my $extracted;
		if ($$ref =~ /\A\(/)
		{
			$extracted = extract_codeblock($$ref, '(){}[]<>', undef, '()');
			$extracted =~ s/(?: \A\( | \)\z )//xgsm;
			$self->_strip_space;
		}
		
		if ($$ref =~ /\A:/)
		{
			substr($$ref, 0, 1, '');
			$self->_strip_space;
		}
		
		push @attrs, [ $name => $extracted ];
	}
	
	@attrs;
}

1;
