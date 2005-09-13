use strict;

use Module::Build;

my $build = Module::Build->new(
	module_name        => 'CGI::Application::PhotoGallery',
	dist_author        => 'Brian Cassidy <bricas@cpan.org>',
	license            => 'perl',
	create_readme      => 1,
	create_makefile_pl => 'traditional',
	requires           => {
		'File::Basename'   => 0,
		'CGI::Application' => 0,
		'Cache::FileCache' => 0,
		'MIME::Types'      => 0,
		'File::Find::Rule' => 0
	},
	build_requires     => {
		'Test::More' => 0
	},
	recommends         => {
		'GD'            => 0,
		'Image::Magick' => 0,
	},
	pm_files           => {
		'etc/photos_index.tmpl'  => 'lib/CGI/Application/PhotoGallery/photos_index.tmpl',
		'etc/photos_single.tmpl' => 'lib/CGI/Application/PhotoGallery/photos_single.tmpl',

		# wish i could just do the templates...

		'lib/CGI/Application/PhotoGallery.pm'        => 'lib/CGI/Application/PhotoGallery.pm',
		'lib/CGI/Application/PhotoGallery/GD.pm'     => 'lib/CGI/Application/PhotoGallery/GD.pm',
		'lib/CGI/Application/PhotoGallery/Magick.pm' => 'lib/CGI/Application/PhotoGallery/Magick.pm'
	}
);

$build->create_build_script;