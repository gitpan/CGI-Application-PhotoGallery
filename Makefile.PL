use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'         => 'CGI::Application::PhotoGallery',
	'VERSION_FROM' => 'PhotoGallery.pm',
	'PREREQ_PM'    => {
		'File::Basename'   => 0,
		'CGI::Application' => 0,
		'HTML::Template'   => 0
	},
);


