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

__END__

$ perl -Ilib devel.experiments/benchmarks.pl

            Rate     MXMS       MS FP_Moose    FP_TT  TParams  Kavorka
MXMS       777/s       --     -91%     -92%     -93%     -95%     -96%
MS        8980/s    1055%       --      -8%     -13%     -43%     -49%
FP_Moose  9732/s    1152%       8%       --      -6%     -38%     -45%
FP_TT    10367/s    1233%      15%       7%       --     -34%     -41%
TParams  15756/s    1927%      75%      62%      52%       --     -10%
Kavorka  17598/s    2164%      96%      81%      70%      12%       --

$ perl -mAny::Moose -Ilib devel.experiments/benchmarks.pl

            Rate     MXMS FP_Moose  TParams  Kavorka       MS    FP_TT
MXMS       774/s       --     -92%     -95%     -96%     -98%     -98%
FP_Moose 10255/s    1224%       --     -35%     -42%     -74%     -77%
TParams  15663/s    1923%      53%       --     -11%     -61%     -64%
Kavorka  17657/s    2180%      72%      13%       --     -56%     -60%
MS       39938/s    5058%     289%     155%     126%       --      -9%
FP_TT    43671/s    5540%     326%     179%     147%       9%       --
