use v5.14;
use Kavorka 0.004 qw( multi fun );

multi fun fib ( Int $i where { $_ <= 1 } ) {
	return $i;
}

multi fun fib ( Int $i ) {
	return fib($i-1) + fib($i-2);
}

say fib($_) for 0..9;

=pod

=encoding utf-8

=head1 PURPOSE

Demonstration of the elegance of multi subs.

   multi fun fib ( Int $i where { $_ <= 1 } ) {
      return $i;
   }

   multi fun fib ( Int $i ) {
      return fib($i-1) + fib($i-2);
   }

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
