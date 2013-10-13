use 5.014;
use strict;
use warnings;

package Kavorka::Multi;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.003';

use Parse::Keyword {};
use Parse::KeywordX;

use Moo;
with 'Kavorka::Sub';
use namespace::sweep;

has multi_type => (is => 'ro', required => 1);

around parse => sub
{
	my $next  = shift;
	my $class = shift;
	
	lex_read_space;
	my $type = parse_name('keyword', 0);
	lex_read_space;
	
	if ($^H{Kavorka} =~ /\b$type=(\S+)/)
	{
		$type = $1;
	}
	else
	{
		Carp::croak("Could not resolve keyword '$type'");
	}
	
	return $class->$next(@_, multi_type => $type);
};

sub allow_anonymous { 0 }

sub default_attributes
{
	shift->multi_type->default_attributes;
}

sub default_invocant
{
	shift->multi_type->default_invocant;
}

sub invocation_style
{
	shift->multi_type->invocation_style
		or Carp::croak("No invocation style defined");
}

our %DISPATCH_TABLE;
our %DISPATCH_STYLE;

my $DISPATCH = sub
{
	my ($pkg, $subname) = @{ +shift };
	
	my @candidates;
	if ($DISPATCH_STYLE{$pkg}{$subname} eq 'fun')
	{
		@candidates = @{$DISPATCH_TABLE{$pkg}{$subname}};
	}
	else
	{
		require mro;
		@candidates = map @{$DISPATCH_TABLE{$_}{$subname} || [] }, @{ $pkg->mro::get_linear_isa };
	}
	
	for my $c (@candidates)
	{
		my @copy = @_;
		next unless $c->signature->check(@copy);
		my $body = $c->body;
		goto $body;
	}
	
	Carp::croak("Arguments to $pkg\::$subname did not match any known signature for multi sub");
};

sub install_sub
{
	my $self = shift;
	my ($pkg, $subname) = ($self->qualified_name =~ /^(.+)::(\w+)$/);
	
	unless ($DISPATCH_TABLE{$pkg}{$subname})
	{
		$DISPATCH_TABLE{$pkg}{$subname} = [];
		$DISPATCH_STYLE{$pkg}{$subname} = $self->invocation_style;
		
		no strict 'refs';
		*{"$pkg\::$subname"} = Sub::Name::subname(
			"$pkg\::$subname" => sub {
				unshift @_, [$pkg, $subname];
				goto $DISPATCH;
			},
		);
	}
	
	$DISPATCH_STYLE{$pkg}{$subname} eq $self->invocation_style
		or Carp::croak("Two different invocation styles used for $subname");
	
	push @{ $DISPATCH_TABLE{$pkg}{$subname} }, $self;
}

1;
