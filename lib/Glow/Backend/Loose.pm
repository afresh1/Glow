package Glow::Backend::Loose;
use Moose;
use MooseX::Types::Path::Class;

use Path::Class::File ();
use IO::Uncompress::Inflate qw( $InflateError) ;
use IO::Compress::Deflate qw( $DeflateError) ;

use Glow::Mapper;

has 'directory' => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    required => 1,
    coerce   => 1,
);

sub get_object {
    my ( $self, $sha1 ) = @_;

    # find the file containing the object, if any
    my $filename = Path::Class::File->new(
        $self->directory,
        substr( $sha1, 0, 2 ),
        substr( $sha1, 2 )
    );
    return if !-f $filename;

    # create a filehandle to read from
    my $zh = IO::Uncompress::Inflate->new("$filename")
        or die "Can't open $filename: $InflateError";

    # get the kind and size information
    my $header = do { local $/ = "\0"; $zh->getline; };
    my ( $kind, $size ) = $header =~ /^(\w+) (\d+)\0/;

    # closure that returns a filehandle
    # pointing at the beginning of the content
    my $build_fh = sub {
        my $zh = IO::Uncompress::Inflate->new("$filename")
            or die "Can't open $filename: $InflateError";
        do { local $/ = "\0"; $zh->getline; };
        return $zh;
    };

    # pick up the class that will instantiate the object
    return Glow::Mapper->kind2class($kind)->new(
        size                    => $size,
        sha1                    => $sha1,
        content_fh_from_closure => $build_fh,
    );
}

sub put_object {
    my ( $self, $object ) = @_;

    # target filename
    my $filename = Path::Class::File->new(
        $self->directory,
        substr( $object->sha1, 0, 2 ),
        substr( $object->sha1, 2 )
    );
    $filename->parent->mkpath;

    # filehandle to read from
    my $fh = $object->content_fh;

    # save to compressed temporary file
    my $zh = IO::Compress::Deflate->new("$filename")
        or die "Can't open $filename: $DeflateError";
    my $buffer = $object->kind . ' ' . $object->size . "\0";
    while ( length $buffer ) {
        $zh->syswrite($buffer)
            or die "Error writing to $filename: $!";
        my $read = $fh->sysread( $buffer, 8192 );
        die "Error reading content from ${\$object->sha1}: $!"
            if !defined $read;
    }
}

1;

