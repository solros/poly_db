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


package PolyDB::Client;
require Exporter;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(get_client get_type get_collection get_date generate_id remove_props_insert check_type);

use Term::ReadKey;


# @category Database
# Takes local and (optionally) username and password and returns a mongo client.
# @param Bool local
# @param String username optional
# @param String password optional
# @return MongoClient
sub get_client {
	my @args = @_;
	my ($local, $u, $p);
	if (@args == 3) {
		($local, $u, $p) = @args;
	} else {
		my $h = $args[0];
		$local = $h->{local};
		$u = $h->{username};
		$p = $h->{password};
	}

	my $client;
	if ($local) {
		$client = MongoDB::MongoClient->new;
	} elsif (!$u || !$p) {
		$client = MongoDB::MongoClient->new(host=>$db_host.":".$db_port, db_name=>$auth_db, username=>$db_user, password=>$db_pwd);
	} else {
		$client = MongoDB::MongoClient->new(host=>$db_host.":".$db_port, db_name=>$auth_db, username=>$u, password=>$p);
	}
	return $client;
}


# returns the database entry with the type information for a given collection
sub get_type {
	my ($client, $db_name, $col_name) = @_;
	my $type =  $client->get_database($db_name)->get_collection("type_information")->find_one({db => $db_name, col => $col_name});
	delete $type->{_id};
	return $type;
}

# returns a collection object
sub get_collection {
	my ($client, $db_name, $col_name) = @_;
	my $db = $client->get_database($db_name);
	return $db->get_collection($col_name);
}


sub check_type {
	my ($obj, $db_name, $col_name, $client) = @_;
	my $c = get_type($client, $db_name, $col_name);

	unless (exists $c->{type}) {
		return 1;
	}
	
	my $col_type = $c->{type};

	unless ($obj->type->isa($c->{app}."::".$col_type) || $col_type ~~ {map {$_->name} keys %{$obj->type->auto_casts}}) {
		croak("Type mismatch: Collection $db_name.$col_name only takes objects of type $col_type; given object is of type ".$obj->type->full_name."\n");
	}
	return 1;
}



# the current date as a string in the form yyyy-mm-dd
sub get_date {
	use DateTime;

	my $dt = DateTime->today;
	return $dt->date;
}

# generates a unique ID for the object from the name of the file
sub generate_id {
	my ($name, $db_name, $col_name) = @_;
	
	if ($col_name eq "SmoothReflexive") {
		if ($name =~ m/\.(\d+D)\.(\d+)/) {
			return "F.$1.$2";
		} else {
			croak("name $name does not yield valid id for collection $col_name\n");
			return;
		}
	}
	if ($col_name eq "SmoothReflexive9") {
		if ($name =~ m/\.(\d+D)\.f(\d+)\.(\d+)/) {
			return "F.$1.$2.$3";
		} else {
			croak("name $name does not yield valid id for collection $col_name\n");
			return;
		}		
	}
	return $name;
	#croak("no rule to generate id for collection $col_name\n");
	#return;
}


# generates a hash containing local, username and password from a possibly larger one
sub lup {
	my $o = shift;
	my $r = {};
	$r->{local}=$o->{local};
	$r->{username}=$o->{username};
	$r->{password}=$o->{password};
	return $r;
}



sub remove_props_insert {
	my ($db, $col, $client, $options) = @_;
	my $rem_props = ["database","collection"];
	if (my $type = get_type($client, $db, $col)) {
		push @$rem_props, keys %$type;
	}
	return $rem_props;
}




sub get_credentials {
	# TODO: cache, key chain??
	print "user name: ";
	my $u= <STDIN>;
	ReadMode 2;
	print "password: ";
	my $p= <STDIN>;
	ReadMode 0;
	print "\n";
	chomp($u);
	chomp($p);
	print "Do you want to save these credentials in your custom settings? (This will overwrite any current user and password settings.) [yes/NO]: ";
	my $answer = <STDIN>;
	chomp($answer);
	print "\n";
	if ($answer == "yes") {
		set_custom $db_user = $u;
		set_custom $db_pwd = $p;
	}
	print "Successfully saved user settings for $u.\n";
	return ($u,$p);
}


1;