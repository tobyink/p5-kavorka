use 5.014;
use strict;
use warnings;

use Kavorka::Signature::Parameter ();

package Kavorka::Sub::Method;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.000_09';

use Moo;
with 'Kavorka::Sub';

sub default_attributes
{
	return (
		['method'],
	);
}

sub default_invocant
{
	my $self = shift;
	return (
		'Kavorka::Signature::Parameter'->new(
			as_string => '$self:',
			name      => '$self',
			traits    => { invocant => 1 },
		),
	);
}

1;
