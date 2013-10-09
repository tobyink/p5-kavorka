use 5.014;
use strict;
use warnings;

use Kavorka::Signature::Parameter ();
use Role::Tiny ();

my $DETECT_OO = do {
	my %_detect_oo; # memoize
	sub {
		my $pkg = $_[0];
		
		return $_detect_oo{$pkg} if exists $_detect_oo{$pkg};
		
		if ($pkg->can("meta"))
		{
			my $meta = $pkg->meta;
			
			return $_detect_oo{$pkg} = "Moo::Role"
				if 'Role::Tiny'->is_role($pkg)
				&& ref($meta) eq "Moo::HandleMoose::FakeMetaClass";
			return $_detect_oo{$pkg} = "Moo"
				if ref($meta) eq "Moo::HandleMoose::FakeMetaClass";
			return $_detect_oo{$pkg} = "Mouse"
				if $meta->isa("Mouse::Meta::Module");
			return $_detect_oo{$pkg} = "Moose"
				if $meta->isa("Moose::Meta::Class");
			return $_detect_oo{$pkg} = "Moose"
				if $meta->isa("Moose::Meta::Role");
		}
		
		return $_detect_oo{$pkg} = "Role::Tiny"
			if 'Role::Tiny'->is_role($pkg);
		
		return $_detect_oo{$pkg} = "";
	}
};

package Kavorka::MethodModifier;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.000_11';

use Moo::Role;
with 'Kavorka::Sub';

requires 'method_modifier';

sub allow_anonymous { 0 }

sub default_invocant
{
	my $self = shift;
	return (
		'Kavorka::Signature::Parameter'->new(
			name      => '$self',
			traits    => { invocant => 1 },
		),
	);
}

sub install_sub
{
	my $self = shift;
	my $name = $self->qualified_name or die;
	my $code = $self->body;
	
	my ($package, $method) = ($name =~ /\A(.+)::(\w+)\z/);
	my $modification = $self->method_modifier;
	
	my $OO = $package->$DETECT_OO;
	
	if ($OO eq 'Moose')
	{
		require Moose::Util;
		my $installer = sprintf('add_%s_method_modifier', $modification);
		return Moose::Util::find_meta($package)->$installer($method, $code);
	}
	
	if ($OO eq 'Mouse')
	{
		require Mouse::Util;
		my $installer = sprintf('add_%s_method_modifier', $modification);
		return Mouse::Util::find_meta($package)->$installer($method, $code);
	}
	
	if ($OO eq 'Role::Tiny')
	{
		require Class::Method::Modifiers;
		push @{$Role::Tiny::INFO{$package}{modifiers}||=[]}, [ $modification, $method, $code ];
		return;
	}
	
	if ($OO eq 'Moo::Role')
	{
		require Class::Method::Modifiers;
		push @{$Role::Tiny::INFO{$package}{modifiers}||=[]}, [ $modification, $method, $code ];
		return $OO->_maybe_reset_handlemoose($package);
	}
	
	if ($OO eq 'Moo')
	{
		require Class::Method::Modifiers;
		require Moo::_Utils;
		return Moo::_Utils::_install_modifier($package, $modification, $method, $code);
	}
	
	require Class::Method::Modifiers;
	return Class::Method::Modifiers::install_modifier($package, $modification, $method, $code);
}

1;
