package CGI::Application::PhotoGallery::GD;

$VERSION = '0.01';

use strict;
use GD;

sub new {
	my( $class ) = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}

sub resize {
	my $self = shift;
	my $file = shift;
	my $size = shift;

	my $image = $self->load( $file );

	my ( $width, $height ) = $image->getBounds();

	my $image2 = new GD::Image($size, $size);

	$image2->transparent($image2->colorAllocate(0,0,0));

	my $hnw = int( ( $height * $size / $width ) + 0.5 );
	my $wnh = int( ( $width * $size / $height ) + 0.5 );

	my @arg = ( $image, 0, 0, 0, 0, $size, $size, $width, $height );

	if ( $width > $height ) {
		$arg[ 2 ]    = int( ( $size - $hnw ) / 2 + 0.5 );
		@arg[ 5, 6 ] = ( $size, $hnw );
	}
	elsif ( $width < $height ) {
		$arg[ 1 ]    = int( ( $size - $wnh ) / 2 + 0.5 );
		@arg[ 5, 6 ] = ( $wnh, $size );
	}

	$image2->copyResized( @arg );
	return $image2->png;
}

sub load {
	my $self = shift;
	my $file = shift;

	my $image;
	if ($GD::VERSION < 1.30) {
		my( $path, $type ) = $file =~ /(.*)\.([^.]+)/;
		my %new = (
			gif => 'newFromGif',
			png => 'newFromPng',
			jpg => 'newFromJpeg'
		);
		my $new = $new{ $type };
		$image = GD::Image->$new( $file );
	}
	else {
		$image = GD::Image->new( $file );
	}

	return $image;
}

sub size {
	my $self = shift;
	my $file = shift;

	my $image = $self->load( $file );

	return $image->getBounds();
}

1;