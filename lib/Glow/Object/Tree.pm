package Glow::Object::Tree;
use Moose;

with 'Glow::Role::Tree';

sub kind { 'tree' }

__PACKAGE__->meta->make_immutable;

