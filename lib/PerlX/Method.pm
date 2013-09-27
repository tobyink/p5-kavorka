use 5.014;
use strict;
use warnings;

package PerlX::Method;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Devel::Pragma qw( ccstash );
use Exporter qw( import );

use Parse::Keyword {
	method   => sub { unshift @_, 'PerlX::Method::Sub::Method'; goto \&_parse },
	fun      => sub { unshift @_, 'PerlX::Method::Sub::Fun'; goto \&_parse },
};

our @EXPORT = qw( fun method );

sub _parse
{
	my $parser = shift;
	eval "require $parser";
	
	use Time::Limit '4';
	my $str = '';
	
	LOOP: {
		my $chunk = lex_peek(1000);
		if (length $chunk)
		{
			lex_read(length $chunk);
			$str .= $chunk;
			redo LOOP;
		}
	}
	
	my $sub = $parser->handle_keyword(\$str, scalar(ccstash));
	lex_stuff($str);

	my $codereffer;# = parse_listexpr;
	
	return(
		sub { $sub, $codereffer },
		!!$sub->declared_name,
	);
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

