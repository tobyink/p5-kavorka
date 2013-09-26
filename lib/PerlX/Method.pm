use 5.014;
use strict;
use warnings;

use Keyword::Simple ();
use PerlX::Method::Sub::Method ();
use PerlX::Method::Sub::Fun ();

package PerlX::Method;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Devel::Pragma qw( ccstash );

sub import
{
	my $class = shift;
	
	Keyword::Simple::define method => sub {
		'PerlX::Method::Sub::Method'->handle_keyword($_[0], scalar(ccstash));
	};
	
	Keyword::Simple::define fun => sub {
		'PerlX::Method::Sub::Fun'->handle_keyword($_[0], scalar(ccstash));
	};
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

PerlX::Method - a module that does something-or-other

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=PerlX-Method>.

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

