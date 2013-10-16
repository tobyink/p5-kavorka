use 5.014;
use strict;
use warnings;

package Kavorka::Multi;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.007';

use Devel::Pragma qw( fqname );
use Parse::Keyword {};
use Parse::KeywordX;

use Moo;
with 'Kavorka::Sub';
use namespace::sweep;

has multi_type          => (is => 'ro', required => 1);
has declared_long_name  => (is => 'rwp');
has qualified_long_name => (is => 'rwp');

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

around parse_attributes => sub
{
	my $next = shift;
	my $self = shift;
	my @attr = $self->$next(@_);
	my @return;
	$_->[0] eq 'long'
		? ($self->_set_declared_long_name($_->[1]), $self->_set_qualified_long_name(scalar fqname $_->[1]))
		: push(@return, $_)
		for @attr;
	return @return;
};

sub allow_anonymous { 0 }

sub default_attributes
{
	my $code = $_[0]->multi_type->can('default_attributes');
	goto $code;
}

sub default_invocant
{
	my $code = $_[0]->multi_type->can('default_invocant');
	goto $code;
}

sub forward_declare
{
	my $code = $_[0]->multi_type->can('forward_declare');
	goto $code;
}

sub invocation_style
{
	$_[0]->multi_type->invocation_style
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
		my $invocant = ref($_[0]) || $_[0];
		@candidates  = map @{$DISPATCH_TABLE{$_}{$subname} || [] }, @{ $invocant->mro::get_linear_isa };
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
	
	my $long = $self->qualified_long_name;
	if (defined $long)
	{
		no strict 'refs';
		*$long = $self->body;
	}
	
	push @{ $DISPATCH_TABLE{$pkg}{$subname} }, $self;
}

1;
