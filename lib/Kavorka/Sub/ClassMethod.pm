use 5.014;
use strict;
use warnings;

use Kavorka::Signature::Parameter ();
use Types::Standard ();

package Kavorka::Sub::ClassMethod;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.000_03';

use Moo;
extends 'Kavorka::Sub::Method';

sub default_invocant
{
	my $self = shift;
	return (
		'Kavorka::Signature::Parameter'->new(
			name      => '$class',
			traits    => { invocant => 1 },
			type      => Types::Standard::Str,
		),
	);
}

1;
