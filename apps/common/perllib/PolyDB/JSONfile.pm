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

 my $pmns="http://www.math.tu-berlin.de/polymake/#3";
 my $simpletype_re = qr{^common::(Int|Integer|Rational|Bool|String)$};
 my $unhandled = "this property is still unhandled";
 
 
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

##*************************************************************
##*************************************************************
sub matrix_toJSON {
    my $pv=shift;
    my $content = [];

    if ( @{$pv} ) {
	foreach (@{$pv}) {
	    push @$content, handle_cpp_content($_);
	}
    } 
    return $content;
}


##*************************************************************
##*************************************************************
sub vector_toJSON {
    my $pv=shift;
    my $content = [];
    my $descr=$pv->type->cppoptions->descr;
    my $val_type=Polymake::Core::CPlusPlus::get_type_proto($descr->vtbl, 1);
    my $sub_qual_name= $val_type->qualified_name;

    print $pv->type->qualified_name, "\n";

    if( $sub_qual_name =~ $simpletype_re ) {
	if ($descr->kind & $Polymake::Core::CPlusPlus::class_is_sparse_container) {
	    $content = {};
	    for (my $it=args::entire($pv); $it; ++$it) {
		$content->{$it->index} = $val_type->toString->($it->deref);
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

    print "first type: ", $types->[0]->qualified_name, "\n", $pv->first, "\n";
    
    push @$content, value_toJSON($pv->first,$types->[0]);
    push @$content, value_toJSON($pv->second,$types->[1]);
    return $content;
}



##*************************************************************
##*************************************************************
sub quadraticExtension_toJSON {
    my $pv=shift;
    my $content = {};
    $content->{"type"} = "QE";

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
sub handle_cpp_content {

    my $pv=shift;
    my $content = {};
    my $qualified_value_name = $pv->type->qualified_name;
    my $descr=$pv->type->cppoptions->descr;
    my $kind=$descr->kind & $Polymake::Core::CPlusPlus::class_is_kind_mask;
	
	    
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
	$content = $qualified_value_name.$unhandled;
    }

    return $content;

}

##*************************************************************
##*************************************************************
sub value_toJSON {

    my $val = shift;
    my $type = shift;
    my $content = {};

    if ( instanceof Polymake::Core::Object($val) ) {
	$content = handle_subobject($val);
    } elsif( $type->qualified_name =~ $simpletype_re ) {
	if ( looks_like_number($val) ) {
	    $content = $val;
	} else {
	    $content = $type->toString->($val);
	    
	}
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

    if ($pv->property->flags & $Polymake::Core::Property::is_multiple) {
	$content->{$_->name} = value_toJSON($_,$type)  for @{$pv->values};
    } else {
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

    foreach my $pv (@{$pv->contents}) {
	my $property = $pv->property->name;
	$content->{$property} = property_toJSON($pv);
    }
    
    return $content;
}

##*************************************************************
##*************************************************************
sub json_save {
	my ($object)=@_;
	
	my $polymake_object = {};
	$polymake_object->{"type"} = $object->type->qualified_name;
	$polymake_object->{"name"} = $object->name;
	$polymake_object->{"version"} = $Polymake::Version;
	$polymake_object->{"tag"} = "object";
	
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
		my $property = $pv->property->name;
		$polymake_object->{$property} = property_toJSON($pv);
    }

	my $json = ::JSON->new;
	$json->pretty->encode($polymake_object);
}

1
