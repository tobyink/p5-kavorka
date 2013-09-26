use 5.014;
use strict;
use warnings;

use PerlX::Method::Signature::Parameter ();

package PerlX::Method::Sub::Method;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Moo;
with 'PerlX::Method::Sub';

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
		'PerlX::Method::Signature::Parameter'->new(
			as_string => '$self:',
			name      => '$self',
			traits    => { invocant => 1 },
		),
	);
}

1;
