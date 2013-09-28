use 5.014;
use strict;
use warnings;

package Kavorka;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Devel::Pragma qw( ccstash );
use Exporter qw( import );

use Parse::Keyword {
	method   => sub { unshift @_, 'Kavorka::Sub::Method'; goto \&_parse },
	fun      => sub { unshift @_, 'Kavorka::Sub::Fun'; goto \&_parse },
};

our @EXPORT = qw( fun method );

sub _parse
{
	my $parser = shift;
	eval "require $parser;" or die($@);
	my $sub = $parser->parse;
	
	return (
		sub { $sub },
		!! $sub->declared_name,
	);
}

{
	no strict 'refs';
	
	sub method
	{
		my ($sub) = @_;
		my $name = $sub->qualified_name;
		my $code = $sub->body;
		
		*{$name} = $code if defined $name;
		return $code;
	}

	sub fun
	{
		my ($sub) = @_;
		my $name = $sub->qualified_name;
		my $code = $sub->body;
		
		*{$name} = $code if defined $name;
		return $code;
	}
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Kavorka - function signatures with the lure of the animal

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Kavorka>.

=head1 SEE ALSO

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

