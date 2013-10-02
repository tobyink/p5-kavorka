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

package Using_TypeParams {
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
	} qw( FP_Moose FP_TT Kavorka TypeParams )
});

__END__
              Rate   FP_Moose      FP_TT TypeParams    Kavorka
FP_Moose    8993/s         --       -37%       -44%       -50%
FP_TT      14197/s        58%         --       -12%       -20%
TypeParams 16188/s        80%        14%         --        -9%
Kavorka    17826/s        98%        26%        10%         --
