#
# Perl 5.22 introduces experimental reference aliasing.
# Data::Alias is totally broken in 5.24.
#
$meta->{prereqs}{runtime}{requires}{'Data::Alias'} = '1.16'
	if $] < 5.022;
