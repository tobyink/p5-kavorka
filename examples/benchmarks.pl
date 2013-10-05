use v5.14;
use warnings;
use Benchmark 'cmpthese';

package Using_FP_TT {
	use Function::Parameters ':strict';
	use Types::Standard -types;
	method foo ( (Int) $x, (ArrayRef[Int]) $y ) {
		return [ $x, $y ];
	}
}

package Using_FP_Moose {
	use Function::Parameters ':strict';
	method foo ( Int $x, ArrayRef[Int] $y ) {
		return [ $x, $y ];
	}
}

package Using_Kavorka {
	use Kavorka;
	method foo ( Int $x, ArrayRef[Int] $y ) {
		return [ $x, $y ];
	}
}

package Using_MS {
	use Moose;
	use Method::Signatures;
	method foo ( Int $x, ArrayRef[Int] $y ) {
		return [ $x, $y ];
	}
}

package Using_MXMS {
	use Moose;
	use MooseX::Method::Signatures;
	method foo ( $class : Int $x, ArrayRef[Int] $y ) {
		return [ $x, $y ];
	}
}

package Using_TParams {
	use Types::Standard -types;
	use Type::Params 'compile';
	sub foo {
		state $signature = compile( 1, Int, ArrayRef[Int] );
		my ($self, $x, $y) = $signature->(@_);
		return [ $x, $y ];
	}
}

cmpthese(-3, {
	map {
		my $class = "Using_$_";
		$_ => qq[ $class\->foo(0, [1..10]) ];
	} qw( FP_Moose FP_TT Kavorka TParams MS MXMS )
});

=pod

=encoding utf-8

=head1 PURPOSE

Benchmarking the following method call defined with several different
modules:

	method foo ( Int $x, ArrayRef[Int] $y ) {
		return [ $x, $y ];
	}

Modules tested are:

=over

=item *

L<Kavorka> (of course)

=item *

L<Type::Params> (not as sugary, but probably the fastest pure Perl method
signature implementation on CPAN)

=item *

L<Function::Parameters> plus L<Moose> type constraints

=item *

L<Function::Parameters> plus L<Type::Tiny> type constraints

=item *

L<Method::Signatures>

=item *

L<MooseX::Method::Signatures>

=back

=head1 RESULTS

=head2 Standard Results

Running C<< perl -Ilib examples/benchmarks.pl >>:

             Rate     MXMS       MS FP_Moose    FP_TT  TParams  Kavorka
 MXMS       777/s       --     -91%     -92%     -93%     -95%     -96%
 MS        8980/s    1055%       --      -8%     -13%     -43%     -49%
 FP_Moose  9732/s    1152%       8%       --      -6%     -38%     -45%
 FP_TT    10367/s    1233%      15%       7%       --     -34%     -41%
 TParams  15756/s    1927%      75%      62%      52%       --     -10%
 Kavorka  17598/s    2164%      96%      81%      70%      12%       --

Kavorka is the winner.

=head2 Any::Moose + Mouse Results

If L<Any::Moose> is loaded before L<Moose>, then L<Method::Signatures>
will be able to use Mouse's type constraints instead of Moose's. Also,
if L<Mouse> is loaded before a L<Type::Tiny> type constraint has been
checked, L<Type::Tiny> can sometimes use Mouse's XSUBs to accelerate
itself.

Running C<< perl -mAny::Moose -Ilib examples/benchmarks.pl >>:

             Rate     MXMS FP_Moose  TParams       MS  Kavorka    FP_TT
 MXMS       817/s       --     -92%     -95%     -98%     -98%     -98%
 FP_Moose 10353/s    1168%       --     -36%     -75%     -76%     -77%
 TParams  16236/s    1888%      57%       --     -61%     -63%     -64%
 MS       41684/s    5005%     303%     157%       --      -5%      -8%
 Kavorka  43689/s    5250%     322%     169%       5%       --      -4%
 FP_TT    45373/s    5457%     338%     179%       9%       4%       --

Kavorka, L<Function::Parameters>+L<Type::Tiny>, and L<Method::Signatures>
perform at comparable speed, clearly benefiting from the XSUB boost.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
