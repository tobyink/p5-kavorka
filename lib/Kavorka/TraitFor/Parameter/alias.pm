use 5.014;
use strict;
use warnings;

package Kavorka::TraitFor::Parameter::alias;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.035';

use Moo::Role;

use constant HAS_REFALIASING => ($] >= 5.022);

around _injection_assignment => sub
{
	my $next = shift;
	my $self = shift;
	my ($sig, $var, $val) = @_;
	
	if ($self->kind eq 'my')
	{
		my $format;
		if (HAS_REFALIASING) {
			$format = <<'EOF';
my %s;
{
	use experimental 'refaliasing';
	\%s = \do { %s };
};
EOF
		}
		else {
			require Data::Alias;
			$format = <<'EOF';
Data::Alias::alias(my %s = do { %s });
EOF
		}
		return sprintf($format, ($var) x 2, $val);
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
