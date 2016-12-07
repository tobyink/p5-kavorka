use 5.014;
use strict;
use warnings;

package Kavorka::TraitFor::Parameter::ref_alias;

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
	\%s = \%s{ +do { %s } };
};
EOF
			return sprintf($format, ($var) x 2, $self->sigil, $val);
		}
		else {
			require Data::Alias;
			return sprintf('Data::Alias::alias(my %s = %s{ +do { %s } });', $var, $self->sigil, $val);
		}
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
