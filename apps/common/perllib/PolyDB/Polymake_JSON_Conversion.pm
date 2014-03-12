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


package PolyDB::Polymake_JSON_Conversion;
use PolyDB::JSON;

require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK @db_only_props @obj_only_props @col_info_props);

@ISA = qw(Exporter);
@EXPORT = qw(doc2object cursor2array cursor2stringarray pm2json);


@db_only_props = qw(app type name version ext description name);
@obj_only_props = qw(database collection);
@col_info_props = qw(contributor type app version ext);


# This function takes a polymake object and transforms it into a json hash.
# It also adds further properties (like type and version information) and removes those that should not go into the database (like database and collection). It also adds an id.
sub pm2json {
	my ($object, $type_info, $addprops, $temp) = @_;
	# type_info contains type info
	# addprops contains additional properties that are added to the object
	# temp should be set to 1 for creating a template object
	
	my $json = write_json($object);
	$json =~ s/\s\:\s/ => /g;
	my $r = eval($json);
	
	foreach (@col_info_props) {
		delete $r->{$_} if (exists $type_info->{$_} and $r->{$_} eq $type_info->{$_});
	}
	foreach (keys %$addprops) {
		$r->{$_} = $addprops->{$_};
	}
	foreach (@obj_only_props) {
		delete $r->{$_};
	}
	
	if (defined (my $template = $type_info->{template})) {
		my $s = new Set<String>($object->list_properties());
		my $t = new Set<String>($template->list_properties());
		my $rem = $s - $t;
		foreach (@$rem) {
			delete $r->{$_};
		}
	}
	
	unless ($temp) {
		if ($addprops->{_id}) {
			$r->{_id} = $addprops->{_id};
		} elsif (not defined $object->_id) {
			croak("no id given");
		}
		$r->{date} = get_date();
	}
	return $r;
}


#############################################################


# This function takes a json hash and an optional object type and transforms the hash into a polymake object.
# It also removes those properties that shall not go into the object (like app, type, version, ...).
sub json2object {
	my ($doc, $obj_type) = @_; 
	my $app = $doc->{app};
	unless (defined($obj_type)) {
		$obj_type = User::application($doc->{app})->eval_type($doc->{type});
	}

	my $name = defined($doc->{name}) ? $doc->{name} : defined($doc->{_id}) ? $doc->{_id} : "<unnamed>";
	my $descr = $doc->{description};
	
	# remove stuff that is only needed in the database (or has to be added later, e.g. description)
	foreach (@db_only_props) {
		delete $doc->{$_};
	}
	my $ret = $obj_type->construct->($name, json2pm($obj_type, $app, %$doc));
	$ret->description = $descr;
	return $ret;
}




# This is a helper function that transforms a database cursor into an array of polymake objects.
sub cursor2array {
	my ($cursor, $type_info, $db_name, $col_name) = @_;
	my $size = $cursor->count(1);
	
	my @objects = $cursor->all;

	# TODO: only allows this for collections with type information (i.e. when $t is defined)??
	my $app = (defined $type_info and defined $type_info->{'app'}) ? $type_info->{'app'} : $objects[0]->{'app'};
	my $type = (defined $type_info and defined $type_info->{'type'}) ? $type_info->{'type'} : $objects[0]->{'type'};

	my $arr_type = User::application($app)->eval_type("Array<$type>");

	my $parray = $arr_type->construct->($size+0);
	my $i = 0;
	
	foreach my $p (@objects) {	
		$parray->[$i] = doc2object($p, $type_info, $db_name, $col_name);
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


# This is a helper function that transforms a database document into an object.
sub doc2object {
	my ($doc, $type_info, $db_name, $col_name) = @_;
	
	$doc->{'database'} = $db_name if $db_name;
	$doc->{'collection'} = $col_name if $col_name;
#	$doc->{'app'} = $type_info->{'app'} unless (defined $doc->{'app'});
#	$doc->{'type'} = $type_info->{'type'} unless (defined $doc->{'type'});
	foreach ((@col_info_props, 'app', 'type')) {
		$doc->{$_} = $type_info->{$_} if (exists $type_info->{$_} and not defined $doc->{$_});
	}
	
	return json2object($doc);
}






# This function takes a json hash and returns one that can be fed into a polymake object.
sub json2pm {
	my $obj_type = shift;
	my $app = shift;
	my %j = @_;
	my %r = map { entry2prop($_, $j{$_}, $obj_type, $app) } keys %j; 
	return %r;
}


# This function converts one entry ($key => $val).
sub entry2prop {
	my ($key, $val, $obj_type, $app_name) = @_;
	if (ref($val) eq "HASH") {
		if (defined(my $type = $val->{type})){
			my $app = defined($val->{app}) ? User::application($val->{app}) : User::application();
			my $prop_type = $app->eval_type($type);
			if (defined($val->{value})) {
				if (!@{$val->{value}}) {	# empty property
					return $key => $val->{value};
				} else {
					return $key => json2sparse($val, $prop_type);
				}
			} else {
				return $key => json2object($val, $prop_type);
			}
		} else {
			return map {entry2prop($key.".".$_, $val->{$_}, $obj_type, $app_name)} keys %$val; 
		}
	}

	return $key => property_value_wrapper($obj_type, $app_name, $key, $val);
}

sub property_value_wrapper {
	my ($obj_type, $app, $key, $val) = @_;
	#my $all = User::application($app)->object_types;
	#my ( $index )= grep { $all->[$_]->full_name eq $obj_type->full_name } 0..$#{$all};
	
	my @keys = split('.',$key);
	my $prop_type = $obj_type;
	foreach (@keys) {
		$prop_type = $prop_type->lookup_property($_)->type;
	}
	if ($prop_type->full_name =~ m/QuadraticExtension/) {
		return qetype($val, $prop_type);
	} else {
		return $val;
	}
}

# take care of QuadraticExtensions
sub qetype {
	my ($val, $type) = @_;
	if ($type->name eq "QuadraticExtension") {
		return new QuadraticExtension(new Rational($val->[0]), new Rational($val->[1]), new Rational($val->[2]));
	}

	if ($type->name eq "Vector") {
		my $size = $#{$val};
		my $r = new Vector<QuadraticExtension>($size);
		for (my $i=0; $i<$size; ++$i) {
			$r->[$i] = new QuadraticExtension(new Rational($val->[$i]->[0]), new Rational($val->[$i]->[1]), new Rational($val->[$i]->[2]));
		}
		return $r;
	}

	
	if ($type->name eq "Matrix") {
		my $rows = $#{$val};
		my $cols = $#{$val->[0]};
		my $r = new Matrix<QuadraticExtension>($rows, $cols);
		for (my $i=0; $i<$rows; ++$i) {
			for (my $j=0; $j<$cols; ++$j) {
				$r->[$i]->[$j] = new QuadraticExtension(new Rational($val->[$i]->[$j]->[0]), new Rational($val->[$i]->[$j]->[1]), new Rational($val->[$i]->[$j]->[2]));
			}
		}
		return $r;
	}
	# TODO: recursive call
}

# This function creates a sparse matrix or vector from json.
sub json2sparse {
	my ($val, $prop_type) = @_;
	my $value = $val->{value};
	
	if ($prop_type->name eq "SparseVector") {
		my $r = $prop_type->construct->($val->{cols});
		my $etype = $r->[0]->type->full_name;
		foreach (keys %{$value}) {
			$r->[$_] = construct_wrapper($value->{$_},$etype);
		}
		return $r;
	}
	if ($prop_type->name eq "SparseMatrix") {
		my $rows = @$value;
		my $r = $prop_type->construct->($rows, $val->{cols});	
		my $etype = $r->[0]->[0]->type;
		for (my $i=0; $i<$rows; ++$i) {
			foreach (keys %{$value->[$i]}) {
				$r->[$i]->[$_] = construct_wrapper($value->[$i]->{$_}, $etype);
			}
		}
		return $r;
	}
}

sub construct_wrapper {
	my ($val, $type) = @_;
	my $name = $type->full_name;
	if ($name eq "QuadraticExtension<Rational>") {
		return new QuadraticExtension(new Rational($val->[0]), new Rational($val->[1]), new Rational($val->[2]));	
	} elsif ($name eq "Float") {
		return new Float($val);	
	} elsif ($name eq "Rational") {
		return new Rational($val);
	}
	return $type->construct->($val);
}





1;