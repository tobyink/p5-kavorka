use 5.014;
use strict;
use warnings;

package PerlX::Method::Sub::Fun;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Moo;
with 'PerlX::Method::Sub';

sub forward_declare
{
	my $self  = shift;
	my $proto = $self->prototype;
	my $name  = $self->qualified_name;
	
	eval(
		defined($proto)
			? sprintf("sub %s (%s);", $name, $proto)
			: sprintf("sub %s;", $name)
	);
}

1;
