# Copyright (c) 2013-2014 Silke Horn
# http://solros.de/polymake/poly_db
# 
# This file is part of the polymake extension polyDB.
# 
# polyDB is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# polyDB is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with polyDB.  If not, see <http://www.gnu.org/licenses/>.


package PolyDB::JSON;

use PolyDB::JSONwriter;

require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT = qw(write_json);


# This functions transforms a given object into json code.
# (It follows the lead of Polymake::Core::XMLwriter::save.)
sub write_json {
	my ($object)=@_;
	my $writer=new PolyDB::JSONwriter;

	my $object_type=$object->type;


	$writer->startTag("object",
        defined($object->name) ? (name => $object->name) : (),
        Polymake::Core::XMLwriter::type_attr($writer, $object_type),
        Polymake::Core::XMLwriter::top_ext_attr($writer, $object_type),
        version => $Version,
    );

	Polymake::Core::XMLwriter::write_object_contents($writer, $object);
	$writer->endTag("object");

	return $writer->string;
}



# This functions writes the json code for a subobject.
# (It follows the lead of Polymake::Core::XMLwriter::write_subobject.)
sub write_subobject {
	my ($writer, $object, $parent, $expected_type)=@_;
	my $type=$object->type;
	$writer->startTag( "object",
		length($object->name) ? (name => $object->name) : (),
        $type != $expected_type ? 
        	(Polymake::Core::XMLwriter::type_attr($writer, $type->pure_type, $parent),
			$type->extension ? 
				Polymake::Core::XMLwriter::ext_attr($writer, $type->extension, $_[4]) 
				: ()
        	)
            : ()
        );
   Polymake::Core::XMLwriter::write_object_contents($writer,$object);
   $writer->endTag("object");
}


# Polymake::Core::XMLwriter::type_attr produces the type attribute needed for some properties (e.g. type => SparseMatrix, etc)


1;
