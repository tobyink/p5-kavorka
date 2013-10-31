use 5.014;
use strict;
use warnings;

package Kavorka::Signature::ReturnType;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.013';
our @CARP_NOT  = qw( Kavorka::Signature Kavorka::Sub Kavorka );

use Carp qw( croak );
use Parse::Keyword {};

use Moo;
use namespace::sweep;

has package         => (is => 'ro');
has type            => (is => 'ro');
has traits          => (is => 'ro', default => sub { +{} });

sub coerce { !!shift->traits->{coerce} }
sub list   { !!shift->traits->{list} }

sub parse
{
	my $class = shift;
	my %args = @_;
	
	lex_read_space;
	
	my %traits = ();
	
	my $type;
	my $peek = lex_peek(1000);
	if ($peek =~ /\A[^\W0-9]/)
	{
		my $reg = do {
			require Type::Registry;
			require Type::Utils;
			my $tmp = 'Type::Registry::DWIM'->new;
			$tmp->{'~~chained'} = $args{package};
			$tmp->{'~~assume'}  = 'Type::Tiny::Class';
			$tmp;
		};
		
		require Type::Parser;
		($type, my($remaining)) = Type::Parser::extract_type($peek, $reg);
		my $len = length($peek) - length($remaining);
		lex_read($len);
		lex_read_space;
	}
	elsif ($peek =~ /\A\(/)
	{
		lex_read(1);
		lex_read_space;
		my $expr = parse_listexpr;
		lex_read_space;
		lex_peek eq ')' or croak("Expected ')' after type constraint expression");
		lex_read(1);
		lex_read_space;
		$type = $expr->();
		$type->isa('Type::Tiny') or croak("Type constraint expression did not return a blessed type constraint object");
	}
	else
	{
		croak("Expected return type!");
	}
	
	$peek = lex_peek(1000);
	while ($peek =~ /\A((?:is|does)\s+(\w+))/sm)
	{
		$traits{"$2"} = 1;
		lex_read(length($1));
		lex_read_space;
		$peek = lex_peek(1000);
	}
	
	return $class->new(
		%args,
		type           => $type,
		traits         => \%traits,
	);
}

1;
