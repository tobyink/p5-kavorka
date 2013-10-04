=pod

=encoding utf-8

=head1 PURPOSE

Check that type constraints work.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=cut

use strict;
use warnings;
use Test::More;
use Test::Fatal;

{
	package Example;
	use Kavorka;
	use Type::Registry qw(t);
	
	BEGIN {
		t->add_types( -Standard );
		t->alias_type( 'Int' => 'Count' );
	};
	
	fun foo ( Int $x )   { return $x }
	fun bar ( Count $x ) { return $x }
	
	fun foo_array ( Int @y ) { return \@y }
	fun bar_array ( Count @y ) { return \@y }

	fun foo_arrayref ( slurpy ArrayRef[Int] $z ) { return $z }
	fun bar_arrayref ( slurpy ArrayRef[Count] $z ) { return $z }
}

is( Example::foo(42), 42 );

like(
	exception { Example::foo(3.14159) },
	qr{^Value "3.14159" did not pass type constraint "Int"},
);

is( Example::bar(42), 42 );

like(
	exception { Example::bar(3.14159) },
	qr{^Value "3.14159" did not pass type constraint "Int"},
);

is_deeply( Example::foo_array(666,42), [666,42] );

like(
	exception { Example::foo_array(666,3.14159) },
	qr{^Value "3.14159" did not pass type constraint "Int"},
);

is_deeply( Example::bar_array(666,42), [666,42] );

like(
	exception { Example::bar_array(666,3.14159) },
	qr{^Value "3.14159" did not pass type constraint "Int"},
);

is_deeply( Example::foo_arrayref(666,42), [666,42] );

like(
	exception { Example::foo_arrayref(666,3.14159) },
	qr{^Reference \[.+\] did not pass type constraint "ArrayRef\[Int\]"},
);

is_deeply( Example::bar_arrayref(666,42), [666,42] );

like(
	exception { Example::bar_arrayref(666,3.14159) },
	qr{^Reference \[.+\] did not pass type constraint "ArrayRef\[Int\]"},
);

done_testing;

