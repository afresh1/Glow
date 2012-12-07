package Glow::Store;

use Moose;

use Glow::Role::Storage;

has stores => (
    is  => 'ro',
    isa => 'ArrayRef[Glow::Role::Storage]',
    required => 1,
    auto_deref => 1,
);

# a Glow::Store is a collection of objects doing Glow::Role::Storage

sub has_object {
    my ( $self, $digest ) = @_;
    $_->has_object($digest) and return 1
        for $self->stores;
    return '';
}

sub get_object {
    my ( $self, $digest ) = @_;
    for my $store ( $self->stores ) {
        my $object = $store->get_object($digest);
        return $object if $object;
    }
    return;    # found nothing
}

sub put_object {
    my ( $self, $object ) = @_;
    $_->put_object($object) and return 1
        for $self->stores;
    return '';
}

1;
