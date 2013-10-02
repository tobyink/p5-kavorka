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

package Using_MS_Moose {
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
	} qw( FP_Moose FP_TT Kavorka TParams MS_Moose MXMS )
});

__END__
            Rate     MXMS MS_Moose FP_Moose    FP_TT  TParams  Kavorka
MXMS       814/s       --     -91%     -92%     -93%     -95%     -96%
MS_Moose  9455/s    1061%       --      -8%     -15%     -42%     -48%
FP_Moose 10320/s    1168%       9%       --      -8%     -36%     -43%
FP_TT    11164/s    1271%      18%       8%       --     -31%     -38%
TParams  16171/s    1886%      71%      57%      45%       --     -11%
Kavorka  18095/s    2122%      91%      75%      62%      12%       --
