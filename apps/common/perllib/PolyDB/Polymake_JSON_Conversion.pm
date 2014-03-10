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
use vars qw(@ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT = qw(doc2object cursor2array cursor2stringarray pm2json);
@EXPORT_OK = qw(json2object);


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
	my ($key, $val, $obj_type, $app) = @_;
	print "e2p: $key\n";
	if (ref($val) eq "HASH") {
		print "HASH\n";
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
			return map {entry2prop($key.".".$_, $val->{$_})} keys %$val; 
		}
	}

	return $key => property_value_wrapper($obj_type, $app, $key, $val);
}

sub property_value_wrapper {
	my ($obj_type, $app, $key, $val) = @_;
	my $all = User::application($app)->object_types;
	my ( $index )= grep { $all->[$_]->full_name eq $obj_type->full_name } 0..$#{$all};
	
	my $prop_type = $all->[$index]->properties->{$key}->type;
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


# This function takes a json hash and an object type and transforms the hash into a polymake object.
# It also adds further properties (like database and collection) and removes those that shall not go into the object (like app, type, version, ...).
sub json2object {
	my ($doc, $obj_type, $add_props, $rem_props) = @_; 
	
	my $app = $doc->{app};
	unless (defined($obj_type)) {
		$obj_type = User::application($doc->{app})->eval_type($doc->{type});
	}

	unless (defined($rem_props)) {
		$rem_props = ["app", "type", "name", "version", "ext", "description"];
	}
	
	foreach (@$rem_props) {
		delete $doc->{$_};
	}
	my $name = defined($doc->{name}) ? $doc->{name} : defined($doc->{_id}) ? $doc->{_id} : "<unnamed>";
	
	return $obj_type->construct->($name, json2pm($obj_type, $app, %$doc), %$add_props);
}


# This function takes a polymake object and transforms it into a json hash.
# It also adds further properties (like ... erm ... dunno) and removes those that should not go into the database (like database and collection). It also adds an id.
sub pm2json {
	my ($object, $add_props, $rem_props, $id, $temp, $template) = @_;
	# add_props contains database properties that shall be added
	# rem_props contains properties that are stored collection wide in the type db and are not written to the database
	# temp should be set to 1 for a creating a template object
	# template - remove properties not contained in the template object
		
	my $json = write_json($object);
	$json =~ s/\s\:\s/ => /g;
	my $r = eval($json);
		
	foreach (keys %$add_props) {
		$r->{$_} = $add_props->{$_};
	}
	foreach (@$rem_props) {
		delete $r->{$_};
	}
	
	if (defined $template) {
		my $s = new Set<String>($object->list_properties());
		my $t = new Set<String>($template->list_properties());
		my $rem = $s - $t;
		foreach (@$rem) {
			delete $r->{$_};
		}
	}
	
	unless ($temp) {
		unless ($id) { $id = $object->_id; }
		$r->{_id} = $id;
		$r->{date} = get_date();
	}
	return $r;
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
		$parray->[$i] = json2object($p, $obj_type, $addprops);
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
	my $doc = shift;
	my $t = shift;
	my $db_name = shift;
	my $col_name = shift;
	
	my $app = defined($doc->{'app'}) ? $doc->{'app'}:$t->{'app'};
	my $type = defined($doc->{'type'}) ? $doc->{'type'}:$t->{'type'};

	# TODO: add other properties from type entry
	my $addprops;
	if ($db_name && $col_name) {
		$addprops = {"database" => $db_name, "collection" => $col_name};
	}
	
	my $obj_type = User::application($app)->eval_type($type);
	
	return json2object($doc, $obj_type, $addprops);
}




1;