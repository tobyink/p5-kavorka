use 5.014;
use strict;
use warnings;

package Kavorka::TraitFor::Parameter::ro;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.019';

use Moo::Role;

around _injection_assignment => sub
{
	my $next = shift;
	my $self = shift;
	my ($sig, $var, $val) = @_;
	
	my $str = $self->$next(@_);
	
	$str .= sprintf(
		'&Internals::SvREADONLY(\\%s, 1);',
		$var,
	);
	
	return $str;
};

1;
