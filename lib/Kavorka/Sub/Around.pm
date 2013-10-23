use 5.014;
use strict;
use warnings;

package Kavorka::Sub::Around;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.010';

use Moo;
with 'Kavorka::MethodModifier';

sub default_invocant
{
	my $self = shift;
	return (
		'Kavorka::Signature::Parameter'->new(
			name      => '${^NEXT}',
			traits    => { invocant => 1 },
		),
		'Kavorka::Signature::Parameter'->new(
			name      => '$self',
			traits    => { invocant => 1 },
		),
	);
}

sub method_modifier { 'around' }

1;
