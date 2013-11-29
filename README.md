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


Usage
------

You can use the functions poly_db, poly_db_one and poly_db_count for simple database queries.

See [here](http://solros.de/polymake/poly_database/doc) for a reference documentation of the basic read functions.

For queries returning a large number of matching objects you should construct a DatabaseCursor object to iterate over the objects.