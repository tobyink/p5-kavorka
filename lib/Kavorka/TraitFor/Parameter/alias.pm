use 5.014;
use strict;
use warnings;

package Kavorka::TraitFor::Parameter::alias;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.031';

use Moo::Role;

around _injection_assignment => sub
{
	my $next = shift;
	my $self = shift;
	my ($sig, $var, $val) = @_;
	
	if ($self->kind eq 'my')
	{
		require Data::Alias;
		return sprintf('Data::Alias::alias(my %s = do { %s });', $var, $val);
	}
	elsif ($self->kind eq 'our')
	{
		(my $glob = $var) =~ s/\A./*/;
		return sprintf('our %s; local %s = \\do { %s };', $var, $glob, $val);
	}
	else
	{
		(my $glob = $var) =~ s/\A./*/;
		return sprintf('local %s = \\do { %s };', $glob, $val);
	}
};

after sanity_check => sub
{
	my $self = shift;
	
	my $traits = $self->traits;
	my $name   = $self->name;
	
	croak("Parameter $name cannot be an alias and coerce") if $traits->{coerce};
	croak("Parameter $name cannot be an alias and a copy") if $traits->{copy};
	croak("Parameter $name cannot be an alias and locked") if $traits->{locked};
};

1;
