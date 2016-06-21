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


package PolyDB::Polymake_JSON_Conversion;
use PolyDB::JSON;
use Scalar::Util qw(looks_like_number);


use JSON;
use XML::Simple;
use Data::Dumper;

require Cwd;

use strict;
 
require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT = qw(json_save read_db_hash cursor2array cursor2stringarray);


my $DEBUG=0;


 my $pmns="http://www.math.tu-berlin.de/polymake/#3";
 my $simpletype_re = qr{^common::(Int|Integer|Rational|Bool|String|Float)$};
 my $unhandled = "this property is still unhandled";
 
 

sub type_attr {
   my ($type, $owner)=@_;
   ( type => $type->qualified_name(defined($owner) ? $owner->type->application : undef) )
}


##*************************************************************
##*************************************************************
# we always need to store the number of columns as this is not reconstructible from the 
# data even for dense matrices, if they are empty
# FIXME for reconstruction: a SparseMatrix can have dense rows, so cannot rely on sparse attribute of matrix
sub matrix_toJSON {
    my $pv=shift;
    my $content = {};
	my $descr=$pv->type->cppoptions->descr;
    
	if ( @{$pv} ) {
		$content->{'type'} = $pv->type->full_name;
		# record whether data is sparse
	    if( $descr->kind & $Polymake::Core::CPlusPlus::class_is_sparse_container ) {
			$content->{'sparse'} = 1;
		} else {
			$content->{'sparse'} = 0;
		}
		$content->{'cols'} = $pv->cols;
		$content->{'data'} = [];
		foreach (@{$pv}) {
	    	push @{$content->{'data'}}, handle_cpp_content($_);
		}
    } 
    return $content;
}


##*************************************************************
##*************************************************************
# FIXME in analogy to matrices a vector could always record its type
# then a vector would always be an object with fields type, dim, sparse, data
sub vector_toJSON {
    my $pv=shift;
	my $content = [];
	
	# get type description
    my $descr=$pv->type->cppoptions->descr;
	
	# get the type of the elements of the vector
    my $val_type=Polymake::Core::CPlusPlus::get_type_proto($descr->vtbl, 1);
    my $sub_qual_name= $val_type->qualified_name;

	# check if inner type is builtin or Rational/Integer
    if( $sub_qual_name =~ $simpletype_re ) {
		# check if data is sparse
		# FIXME apparently sparse vectors can only contain simple types?
		if ($descr->kind & $Polymake::Core::CPlusPlus::class_is_sparse_container) {
	    	$content = {};
			$content->{'dim'} = $pv->dim;
			$content->{'sparse'} = 1;
			$content->{'data'} = {};
			for (my $it=args::entire($pv); $it; ++$it) {
				$content->{'data'}->{$it->index} = $val_type->toString->($it->deref);
			}
		} else {
	    	my @pv_copy = map { $val_type->toString->($_) } @$pv;
			$content = \@pv_copy;
		}
	} else {
		foreach (@{$pv}) {
	    	push @$content, handle_cpp_content($_);
		}
    }

    return $content;
}

##*************************************************************
##*************************************************************
sub array_toJSON {

    my $pv=shift;
    my $content = [];
    my $descr=$pv->type->cppoptions->descr;
    my $val_type=Polymake::Core::CPlusPlus::get_type_proto($descr->vtbl, 1);
    my $sub_qual_name= $val_type->qualified_name;

    if( $sub_qual_name =~ $simpletype_re ) {
		my @pv_copy = @$pv;
		$content = \@pv_copy;
	} else {
		$content = [];
		foreach (@{$pv}) {
	    	push @$content, handle_cpp_content($_);
		}
    }
    return $content;
}

##*************************************************************
##*************************************************************
sub graph_toJSON {
    my $pv=shift;
    my $content = {};

    if ($pv->has_gaps) {
	print "graphs with gaps are still unhandled\n" if $DEBUG;
	$content = \$unhandled;
    } else {
	my $am=adjacency_matrix($pv);
	$content = handle_cpp_content($am);
    }
    
    return $content;
}

##*************************************************************
##*************************************************************
sub nodeMap_toJSON {
    my $pv=shift;
    my $content = [];
    foreach (@$pv) {
	push @$content, handle_cpp_content($_);
    }
    return $content;
}

##*************************************************************
##*************************************************************
sub map_toJSON {
    my $pv=shift;
    my $content = [];
    
    my $descr=$pv->type->cppoptions->descr;
    my @kv_type=map { Polymake::Core::CPlusPlus::get_type_proto($descr->vtbl, $_) } 0,1;

    foreach (keys %$pv) {
	my $val = [];
	push @$val, value_toJSON($_,$kv_type[0]);
	push @$val, value_toJSON($pv->{$_},$kv_type[1]);
	push @$content, $val;
    }
    return $content;
}


##*************************************************************
##*************************************************************
sub pair_toJSON {
    my $pv=shift;
    my $content = [];
    
    my $descr=$pv->type->cppoptions->descr;
    my $types = Polymake::Core::CPlusPlus::get_type_proto($descr->vtbl, 2);
    
    push @$content, value_toJSON($pv->first,$types->[0]);
    push @$content, value_toJSON($pv->second,$types->[1]);
    return $content;
}



##*************************************************************
##*************************************************************
sub quadraticExtension_toJSON {
    my $pv=shift;
    my $type = $pv->type;
    my $content = $type->toString->($pv);
    return $content;
}

##*************************************************************
##*************************************************************
sub tropicalNumber_toJSON {
    my $pv=shift;
    my $type = $pv->type;
    my $content = $type->toString->($pv);
    return $content;
}

##*************************************************************
##*************************************************************
# handle C++ types
# this is the most difficult case as 
# C++-types can be arbitrarily nested
sub handle_cpp_content {

    my $pv=shift;
    my $content = {};
    my $qualified_value_name = $pv->type->qualified_name;
    my $descr=$pv->type->cppoptions->descr;
    my $kind=$descr->kind & $Polymake::Core::CPlusPlus::class_is_kind_mask;


    if ( $DEBUG ) {
	if ($kind==$Polymake::Core::CPlusPlus::class_is_container) {		
	    print $qualified_value_name, " class is container\n";
	    if ($descr->kind & $Polymake::Core::CPlusPlus::class_is_assoc_container) {	
		print $qualified_value_name, " class is assoc container\n";
	    }
   	} elsif ($kind==$Polymake::Core::CPlusPlus::class_is_composite) {
	    print $qualified_value_name, " class is composite\n";
	} else {
	    print $qualified_value_name, " has unknown class structure\n";
	}
    }
	    
    if( $qualified_value_name =~ /^common::(SparseMatrix|Matrix|IncidenceMatrix)/ ) {
	$content = matrix_toJSON($pv);

    } elsif( $qualified_value_name =~ /^common::(Array|Set)/ ) {
	$content = array_toJSON($pv);
	
    } elsif( $qualified_value_name =~ /^common::(SparseVector|Vector)/ ) {
	$content = vector_toJSON($pv);
	
    } elsif( $qualified_value_name =~ /^common::Graph/ ) {
	$content = graph_toJSON($pv);

    } elsif( $qualified_value_name =~ /^common::NodeMap/ ) {
	$content = nodeMap_toJSON($pv);

    } elsif( $qualified_value_name =~ /^common::Map/ ) {
	$content = map_toJSON($pv);

    } elsif( $qualified_value_name =~ /^common::Pair/ ) {
	$content = pair_toJSON($pv);

    } elsif( $qualified_value_name =~ /^common::QuadraticExtension/ ) {
	$content = quadraticExtension_toJSON($pv);

    } elsif( $qualified_value_name =~ /^common::TropicalNumber/ ) {
	$content = tropicalNumber_toJSON($pv);
    } else {
	print $qualified_value_name, "is still unhandled\n" if $DEBUG;
	$content = $qualified_value_name." ".$unhandled;
    }

    return $content;

}

##*************************************************************
##*************************************************************
# this is only a distributor function that calls the 
# correct handler depending on whether the value is a 
# polymake object, builtin type, or C++ type
sub value_toJSON {

    my $val = shift;
    my $type = shift;
    my $content = {};

    if ( instanceof Polymake::Core::Object($val) ) {
		$content = handle_subobject($val);
    } elsif( $type->qualified_name =~ $simpletype_re ) {
		$content = $type->toString->($val);
    } else {  # now we are dealing with a C++ type
		$content = handle_cpp_content($val);
    }
    
    return $content;
}


##*************************************************************
##*************************************************************
sub property_toJSON {
    my $pv = shift;
    my $type= $pv->property->type;
    my $content = {};

	# multiple subobjects are stored as an array of objects
	# in this case we know from the start that the value of this 
	# property is a polymake object, hence no need to detect this as
	# will be done in the non-multiple case
    if ($pv->property->flags & $Polymake::Core::Property::is_multiple) {
		$content = [];
		push @$content, handle_subobject($_)  for @{$pv->values};
    } else {
		# here we don't know whether the propery is again an object, a builtin or a C++ type
		$content = value_toJSON($pv->value,$type);
    }

    return $content;
}



##*************************************************************
##*************************************************************
sub handle_subobject {

    my $pv = shift;
    my $main_type=$pv->type->qualified_name;
    my $content = {};
    $content->{"type"} = $pv->type->qualified_name;
    if (length($pv->name)) {
		# FIXME here we need to copy the name into a separate variable 
		# before assigning to content
		# otherwise we run into a weird loop if property has no name, 
		# e.g. for $c=cube(3); $c->TRIANGULATION;
		my $name = $pv->name;
		$content->{"name"} = "$name";
    }
    $content->{"tag"} = "object";
    if (length($pv->description)) {
    	$content->{"description"} = $pv->description;
    } 
	
    my @credits = ();
    while (my ($product, $credit_string)=each %{$pv->credits}) {
	my %credit =();
        $credit{"credit"} = Polymake::is_object($credit_string) ? $credit_string->toFileString : $credit_string;
    	$credit{"product"} = $product;
    	push @credits, \%credit;
    }
    $content->{"credits"} = \@credits;

    foreach my $pv (@{$pv->contents}) {
	my $property = $pv->property->name;
	print "encoding property $property in subobject\n" if $DEBUG;
	$content->{$property} = property_toJSON($pv);
    }
    
    return $content;
}

##*************************************************************
##*************************************************************
sub project_json {
	my ($polymake_object, $projection ) = @_;
	
	foreach ( keys %{$polymake_object} ) {
		if ( !defined($projection->{$_}) ) {
			delete $polymake_object->{$_};
		} else {
			if ( ref($projection->{$_}) eq "HASH" ) {
				project_json($polymake_object->{$_}, $projection->{$_});
			}
		}
	}
}

sub json_save {
    my ($object, $options)=@_;

	# create a perl hash that contains the data from the polymake object
	# later, we use JSON::encode to convert this into a json object
    my $polymake_object = {};
   
    # encode properties of the polytope
	# we run through the top level and handle the rest recursively
    foreach my $pv (@{$object->contents}) {
		next if !defined($pv) || $pv->property->flags & $Property::is_non_storable;
		my $property = $pv->property->name;
		$polymake_object->{$property} = property_toJSON($pv);
    }

	if ( defined($options->{'projection'}) ) {
		project_json($polymake_object, $options->{'projection'});
	}
	
	# add the meta properties of the polytope
	# first those also contained in a polymake object
    $polymake_object->{"type"} = $object->type->qualified_name;
	($polymake_object->{"app"}) = $polymake_object->{"type"} =~ /^(.+?)(?=::)/;
    $polymake_object->{"name"} = $object->name;
	# description is optional, so check
    if (length($object->description)) { 
    	   $polymake_object->{"description"} = $object->description;
    } 
	# an object may have multiple credits
    my @credits = ();
    while (my ($product, $credit_string)=each %{$object->credits}) {
	my %credit =();
        $credit{"credit"} = Polymake::is_object($credit_string) ? $credit_string->toFileString : $credit_string;
    	$credit{"product"} = $product;
    	push @credits, \%credit;
    }
    $polymake_object->{"credits"} = \@credits;	
	
	# FIXME deal with extensions

	# data base specific meta properties are stored in a separate hash
	# will be added as attachment upon reeading
	$polymake_object->{"polyDB"} = {};
    $polymake_object->{"polyDB"}->{"tag"} = "object";
	$polymake_object->{"polyDB"}->{"creation_date"} = get_date();
    $polymake_object->{"polyDB"}->{"version"} = $Polymake::Version;
			
	if ( $options ) {
		if ( defined($options->{'id'}) ) {
			$polymake_object->{'_id'} = $options->{'id'};
			$polymake_object->{"polyDB"}->{"id"} = $options->{'id'};
		}
		if ( defined($options->{'contributor'}) ) {
			$polymake_object->{"polyDB"}->{'contributor'} = $options->{'contributor'};
		}
	}
    	
	print Dumper($polymake_object) if $DEBUG;
	
	my $xml = save Core::XMLstring($object);    
	$polymake_object->{'xml'} = $xml;
	
	# finally, convert the perl hash into a json object
    my $json = ::JSON->new;
    $json->pretty->encode($polymake_object);
}


sub read_db_hash {
	
	my ($polymake_object, $addprops, $metadata ) = @_;
	
	# create the polytope
	my $p=eval("new ".$polymake_object->{'type'}.";");

	# read the polytope from the xml of the db
	load Core::XMLstring($p,$polymake_object->{'xml'});	
	
	# assign a name if it does not have one already
	# first try if one is stored in the db, then use the id
	if ( !defined($p->name) ) {
		if ( defined($polymake_object->{'name'}) ) {
			$p->name = $polymake_object->{'name'};
		} else {
			if ( defined($polymake_object->{'_id'}) ) {
				$p->name = $polymake_object->{'_id'};
			}
		}
	}
	
	if ( defined($addprops) ) {
		foreach ( keys %$addprops ) {
			$p->take($_, $addprops->{$_});
		}
	}
	
	if ( defined($metadata) ) {
		my $MD = new Map<String,String>;
		foreach ( keys %$metadata ) {
			$MD->{$_} = $metadata->{$_};
		};
		$p->attach("polyDB", $MD);
	}
	
	return $p;	
}

# convert a complete json hash into a polymake object
# note that this exxentially means to read the 
# xml property of the json
sub json_read {
	my ($json,$addprops) = @_;
	my $polymake_object = ::JSON->new->utf8->decode($json);
	return read_db_hash($polymake_object,$addprops);
}


# This is a helper function that transforms a database cursor into an array of polymake objects.
sub cursor2array {
	my ($cursor, $t, $db_name, $col_name) = @_;
	my $size = $cursor->count(1);
	
	my @objects = $cursor->all;

	my $app = defined($t) ? $t->{'app'}:$objects[0]->{'app'};
	my $type = defined($t) ? $t->{'type'}:$objects[0]->{'type'};

	my $obj_type = User::application($app)->eval_type($type);
	my $arr_type = User::application($app)->eval_type("Array<$type>");

	my $parray = $arr_type->construct->($size+0);
	my $i = 0;
	
	# TODO: add other properties from type entry
	my $addprops = {"database" => $db_name, "collection" => $col_name};
	foreach my $p (@objects) {		
		$parray->[$i] = PolyDB::DirectJSONwriter::read_db_hash($p, $addprops);
		++$i;
	}
	return $parray;

}

# This is a helper function that transforms a database cursor into an array of strings (IDs).
sub cursor2stringarray {
	my $cursor = shift;
	
	my @parray = ();
	while (my $p = $cursor->next) {
		push @parray, $p->{_id};
	}
	return @parray;

}




1;