poly_database
=======

This is an extension for polymake that allows access to the online polymake polytope database on the polymake server. (See polymake.org or solros.de/polymake/poly_database for more details.)


Installation
------

Note that you first have to install the Perl driver for MongoDB (from cpan) by issuing:

	sudo cpan MongoDB


After downloading the extension (and installing MongoDB) install it to polymake by running

	import_extension("path/to/poly_database");

in polymake.

