use 5.014;
use strict;
use warnings;

package Kavorka::TraitFor::Parameter::ref_alias;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.027';

use Moo::Role;

around _injection_assignment => sub
{
	my $next = shift;
	my $self = shift;
	my ($sig, $var, $val) = @_;
	
	if ($self->kind eq 'my')
	{
		require Data::Alias;
		return sprintf('Data::Alias::alias(my %s = %s{ +do { %s } });', $var, $self->sigil, $val);
	}
	elsif ($self->kind eq 'our')
	{
		(my $glob = $var) =~ s/\A./*/;
		return sprintf('our %s; local %s = do { %s };', $var, $glob, $val);
	}
	else
	{
		(my $glob = $var) =~ s/\A./*/;
		return sprintf('local %s = do { %s };', $glob, $val);
	}
};

1;
