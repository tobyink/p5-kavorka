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

            Rate     MXMS FP_Moose  TParams  Kavorka    FP_TT       MS
MXMS       798/s       --     -92%     -95%     -98%     -98%     -98%
FP_Moose 10083/s    1163%       --     -37%     -73%     -74%     -75%
TParams  15937/s    1897%      58%       --     -58%     -59%     -60%
Kavorka  37716/s    4626%     274%     137%       --      -3%      -5%
FP_TT    38862/s    4770%     285%     144%       3%       --      -2%
MS       39656/s    4869%     293%     149%       5%       2%       --
