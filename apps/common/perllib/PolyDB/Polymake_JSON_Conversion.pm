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
	my %j = @_;
	my %r = map { entry2prop($_, $j{$_}) } keys %j; 
	return %r;
}


# This function converts one entry ($key => $val).
sub entry2prop {
	my ($key, $val) = @_;
#	print "key: $key\n";
#	print "val: $val\n";
	if (ref($val) eq "HASH") {
		if (defined(my $type = $val->{type})){
			my $app = defined($val->{app}) ? User::application($val->{app}) : User::application();
			my $prop_type = $app->eval_type($type);
#			print "type: ".$type."\n";
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

	return $key => $val;
}

# This function creates a sparse matrix or vector from json.
sub json2sparse {
	my ($val, $prop_type) = @_;
	my $value = $val->{value};
	
	if ($prop_type->name eq "SparseVector") {
		my $r = $prop_type->construct->($val->{cols});
		my $etype = $r->[0]->type;
		foreach (keys %{$value}) {
			$r->[$_] = $etype->construct->(@{$value->{$_}});
		}
		return $r;
	}
	if ($prop_type->name eq "SparseMatrix") {
		my $rows = @$value;
		my $r = $prop_type->construct->($rows, $val->{cols});	
		my $etype = $r->[0]->[0]->type;
#		print "type ".$etype->full_name."\n";
		for (my $i=0; $i<$rows; ++$i) {
			foreach (keys %{$value->[$i]}) {
#				my @entry = @{$value->[$i]->{$_}};
#				print "entry: "; print @entry; print "\n";
				$r->[$i]->[$_] = $etype->construct->($value->[$i]->{$_});
			}
		}
		return $r;
	}
}


# This function takes a json hash and an object type and transforms the hash into a polymake object.
# It also adds further properties (like database and collection) and removes those that shall not go into the object (like app, type, version, ...).
sub json2object {
	my ($doc, $obj_type, $add_props, $rem_props) = @_; 
	
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
	
	return $obj_type->construct->($name, json2pm(%$doc), %$add_props);
}


# This function takes a polymake object and transforms it into a json hash.
# It also adds further properties (like ... erm ... dunno) and removes those that should not go into the database (like database and collection). It also adds an id.
sub pm2json {
	my ($object, $add_props, $rem_props, $id, $temp) = @_;
	# add_props contains database properties that shall be added
	# rem_props contains properties that are stored collection wide in the type db and are not written to the database
	# temp should be set to 1 for a template object
	
	unless ($id) { $id = $object->_id; }
	
	my $json = write_json($object);
	$json =~ s/\s\:\s/ => /g;
	my $r = eval($json);
		
	foreach (keys %$add_props) {
		$r->{$_} = $add_props->{$_};
	}
	foreach (@$rem_props) {
		delete $r->{$_};
	}
	unless ($temp) {
		$r->{_id} = $id;
		$r->{date} = get_date();
	}
	return $r;
}


# This is a helper function that transforms a database cursor into an array of polymake objects.
sub cursor2array {
	my ($cursor, $t, $db_name, $col_name) = @_;
	my $size = $cursor->count(1);

	my $app = defined($t) ? $t->{'app'}:$cursor->[0]->{'app'};
	my $type = defined($t) ? $t->{'type'}:$cursor->[0]->{'type'};

	my $obj_type = User::application($app)->eval_type($type);
	my $arr_type = User::application($app)->eval_type("Array<$type>");

	my $parray = $arr_type->construct->($size+0);
	my $i = 0;
	
	# TODO: add other properties from type entry
	my $addprops = {"database" => $db_name, "collection" => $col_name};
	while (my $p = $cursor->next) {		
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
	my $addprops = {"database" => $db_name, "collection" => $col_name};
	
	my $obj_type = User::application($app)->eval_type($type);
	
	return json2object($doc, $obj_type, $addprops);
}




1;