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
    my ( $self, $digest ) = @_;

    # find the file containing the object, if any
    my $filename = Path::Class::File->new(
        $self->directory,
        substr( $digest, 0, 2 ),
        substr( $digest, 2 )
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
        digest                  => $digest,
        content_fh_from_closure => $build_fh,
    );
}

sub put_object {
    my ( $self, $object ) = @_;

    # target filename
    my $filename = Path::Class::File->new(
        $self->directory,
        substr( $object->digest, 0, 2 ),
        substr( $object->digest, 2 )
    );
    $filename->parent->mkpath;

    # filehandle to read from
    my $fh = $object->content_fh;

    # save to compressed temporary file
    my $tmp = File::Temp->new( DIR => $filename->parent );
    my $zh = IO::Compress::Deflate->new($tmp->filename)
        or die "Can't open $filename: $DeflateError";
    my $buffer = $object->kind . ' ' . $object->size . "\0";
    while ( length $buffer ) {
        $zh->syswrite($buffer)
            or die "Error writing to $filename: $!";
        my $read = $fh->sysread( $buffer, 8192 );
        die "Error reading content from ${\$object->digest}: $!"
            if !defined $read;
    }

    # move it to its final destination
    rename $tmp->filename, $filename;
}

1;

