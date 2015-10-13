use v5.14;
use Benchmark qw(cmpthese);

package Paper    { use Moose; }
package Scissors { use Moose; }
package Rock     { use Moose; }
package Lizard   { use Moose; }
package Spock    { use Moose; }

my @CLASSES = qw( Paper Scissors Rock Lizard Spock );
$_->meta->make_immutable for @CLASSES;

package PlayAll
{
	use Moose::Role;
	sub play_all {
		my $self = shift;
		my @objs = map $_->new, @CLASSES;
		for my $i (@objs) {
			for my $j (@objs) {
				$self->play($i, $j);
			}
		}
	}
}

package Game_MXMM
{
	use Moose;
	with 'PlayAll';

	use MooseX::MultiMethods;

	multi method play (Paper    $x, Rock     $y) { 1 }
	multi method play (Paper    $x, Spock    $y) { 1 }
	multi method play (Scissors $x, Paper    $y) { 1 }
	multi method play (Scissors $x, Lizard   $y) { 1 }
	multi method play (Rock     $x, Scissors $y) { 1 }
	multi method play (Rock     $x, Lizard   $y) { 1 }
	multi method play (Lizard   $x, Paper    $y) { 1 }
	multi method play (Lizard   $x, Spock    $y) { 1 }
	multi method play (Spock    $x, Rock     $y) { 1 }
	multi method play (Spock    $x, Scissors $y) { 1 }
	multi method play (Any      $x, Any      $y) { 0 }

	__PACKAGE__->meta->make_immutable;
}

package Game_Kavorka
{
	use Moose;
	with 'PlayAll';

	use Kavorka qw( multi method );

	multi method play (Paper    $x, Rock     $y) { 1 }
	multi method play (Paper    $x, Spock    $y) { 1 }
	multi method play (Scissors $x, Paper    $y) { 1 }
	multi method play (Scissors $x, Lizard   $y) { 1 }
	multi method play (Rock     $x, Scissors $y) { 1 }
	multi method play (Rock     $x, Lizard   $y) { 1 }
	multi method play (Lizard   $x, Paper    $y) { 1 }
	multi method play (Lizard   $x, Spock    $y) { 1 }
	multi method play (Spock    $x, Rock     $y) { 1 }
	multi method play (Spock    $x, Scissors $y) { 1 }
	multi method play (Any      $x, Any      $y) { 0 }

	__PACKAGE__->meta->make_immutable;
}

our $mxmm     = Game_MXMM->new;
our $kavorka  = Game_Kavorka->new;

cmpthese(-3, {
	'MXMM'     => q[ $::mxmm->play_all ],
	'Kavorka'  => q[ $::kavorka->play_all ],
});

__END__
          Rate    MXMM Kavorka
MXMM    3.72/s      --    -71%
Kavorka 12.9/s    248%      --
