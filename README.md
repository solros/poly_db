polyDB
=======

This is an extension for polymake that allows access to the online polymake polytope database on the polymake server. (See polymake.org or solros.de/polymake/poly_db for more details.)


Installation
------

Note that you first have to install the Perl driver for MongoDB (from cpan) by issuing:

	sudo cpan MongoDB

If you don't have sudo-rights (or don't want to apply them here) see [here](http://solros.de/polymake/poly_db/mongo.php) or the file Install_MongoDB for install information. 

After downloading the extension (and installing MongoDB) install it to polymake by running

	import_extension("path/to/poly_db");

in polymake.


Usage
------

See [here](http://polymake.org/doku.php/tutorial/poly_db_tutorial) for a tutorial.

You can use the functions poly_db, poly_db_one and poly_db_count for simple database queries.

See [here](http://solros.de/polymake/poly_db/doc) for a reference documentation of the basic read functions.

For queries returning a large number of matching objects you should construct a DatabaseCursor object to iterate over the objects.