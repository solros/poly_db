# Copyright (c) 2016- Silke Horn, Andreas Paffenholz
# http://solros.de/polymake/poly_db
# http://www.mathematik.tu-darmstadt.de/~paffenholz
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

 use JSON

 require Cwd;

 use strict;
 use namespaces;

 my $pmns="http://www.math.tu-berlin.de/polymake/#3";
 
 my $DEBUG=1;
 
#############################################################################################
#
#  DirectJSON Writer
#

package PolyDB::DirectJSONwriter;
use Scalar::Util qw(looks_like_number);

sub type_attr {
   my ($type, $owner)=@_;
   ( type => $type->qualified_name(defined($owner) ? $owner->type->application : undef) )
}

sub write_subobject {
	my ($object, $parent, $expected_type)=@_;
	print "writing subobject: ", $object->type->qualified_name, "\n" if $DEBUG;

	my $type=$object->type;
	my $polymake_object = {};

	$polymake_object->{"type"} = $object->type->qualified_name;
	$polymake_object->{"tag"} = "object";

	if (length($object->name) ) {
		$polymake_object->{"name"} = $object->name;
	}
    if (length($object->description)) {
    	   $polymake_object->{"description"} = $object->description;
    } 
	
	if ( $type != $expected_type ) { print "type and expected type deviate: ", type_attr($type->pure_type, $parent), "\n"; };
	# FIXME handle extensions
	
	$polymake_object->{"content"} = write_object_contents($object);
	return $polymake_object;
}

sub write_object_contents {
	my ($object)=@_;
	my $polymake_object = {};

    if (length($object->description)) {
    	   $polymake_object->{"description"} = $object->description;
    }
   
    my @credits = ();
    while (my ($product, $credit_string)=each %{$object->credits}) {
		my %credit =();
        $credit{"credit"} = Polymake::is_object($credit_string) ? $credit_string->toFileString : $credit_string;
    	$credit{"product"} = $product;
    	push @credits, \%credit;
    }
	
	$polymake_object->{"credits"} = \@credits;



    foreach my $pv (@{$object->contents}) {
       next if !defined($pv) || $pv->property->flags & $Polymake::Core::Property::is_non_storable;

	   #handle extensions here
	   
	   my $val = $pv->value;
	   if (instanceof Polymake::Core::Object($pv)) {
		   print "adding object: ", $pv->property->qual_name, "\n" if $DEBUG;
		   $polymake_object->{$pv->property->qual_name} = write_subobject($pv, $object, $pv->property->type);
      	   
       # TODO: handle explicit references to other objects some day...

	   } elsif ($pv->property->flags & $Polymake::Core::Property::is_multiple) {
		   print "adding multiple property: ", $pv->property->qual_name, "\n" if $DEBUG;
		   
	   } elsif (defined($pv->value)) {
		   print "adding value: ", $pv->property->qual_name, "\n" if $DEBUG;
		   my $type=$pv->property->type;
		   my @show_type;
		   if (Polymake::is_object($val)) {
			   if (ref($pv->value) ne $type->pkg) {
				   $type=$val->type;
			  }
		   }
		   if ($type->toXML) {
			   # FIXME need writers for C++ objects, GRAPH and RING here
			   print $pv->property->name, " has a toXML method\n ";
		   } elsif (!looks_like_number($val) ) {
			   $polymake_object->{$pv->property->qual_name} = $type->toString->();
		   } else {
			   # FIXME we are ignoring show_type and ext here
			   $polymake_object->{$pv->property->qual_name} = $val;
   		   }
		} else {
 		   print "adding undef: ", $pv->property->qual_name, "\n" if $DEBUG;
			# FIXME we are ignoring ext here
		   $polymake_object->{$pv->property->qual_name} = "undef";
		}
	}

	return $polymake_object;
}

sub json_save {
	my ($object)=@_;
	
	my $json = ::JSON->new;

	my $polymake_object = {};
	$polymake_object->{"type"} = $object->type->qualified_name;
	$polymake_object->{"name"} = $object->name;
	$polymake_object->{"version"} = $Polymake::Version;
	$polymake_object->{"tag"} = "object";
	
    if (length($object->description)) {
    	   $polymake_object->{"description"} = $object->description;
    } 

	my $contents = write_object_contents($object);
	@{$polymake_object}{keys %{$contents}} = values %{$contents};

	$json->pretty->encode($polymake_object);
}

1