use 5.006;
use ExtUtils::MakeMaker;

# $Id: Makefile.PL,v 1.1 2003/03/28 19:21:56 xmath Exp $

WriteMakefile(
	NAME		=> 'IO::EventQueue',
	VERSION_FROM	=> 'EventQueue.pm',
	ABSTRACT_FROM	=> 'EventQueue.pm',
	AUTHOR		=> 'Matthijs van Duin <xmath@cpan.org>',
);
