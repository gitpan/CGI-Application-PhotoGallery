package CGI::Application::PhotoGallery::Magick;

$VERSION = '0.01';

use strict;
use Image::Magick;

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

	$image->Scale( Geometry => $size . "x$size" );

	return $image->ImageToBlob( magick => 'png' );
}

sub load {
	my $self = shift;
	my $file = shift;

	my $image = Image::Magick->new;

	$image->Read( $file );

	return $image;
}

sub size {
	my $self = shift;
	my $file = shift;

	my $image = $self->load( $file );

	return $image->Get( 'width', 'height' );
}

1;