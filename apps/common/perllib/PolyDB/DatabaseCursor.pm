# Copyright (c) 2013-2016 Silke Horn, Andreas Paffenholz
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


package PolyDB::DBCursor;


# search_params:
# query
# local
# username
# password
# host
# skip
# sort_by
# type
# app
use Polymake::Struct (
   [ new => '$$@' ],
   [ '$database' => '#1' ],
   [ '$collection' => '#2' ],
   [ '%search_params' => '@' ],
   '$local',
   '$username',
   '$password',
   '$app',
   '$type',
   '$cursor',
);

sub new {
	my $self=&_new;	
	$self->local = 0;
	$self->username = $db_user;
	$self->password = $db_pwd;
	
	my $client = get_client($self->local, $self->username, $self->password);
	my $template = get_type($client, $self->database, $self->collection);
	my $app = $template->{'app'};
	my $type = $template->{'type'};
	$self->app = $app;
	$self->type = $type;
	
	if ( !defined($self->search_params->{query}) ) {
		$self->search_params->{query} = {"N_LATTICE_POINTS" => "67"};
	}
	if ( !defined($self->search_params->{sort_by}) ) {
		$self->search_params->{sort_by} = {"_id" => 1};
	}
	if ( !defined($self->search_params->{skip}) ) {
		$self->search_params->{skip} = 0;
	}

	print "connection established as user ".$self->username."\n";
	my $col = $client->get_database($self->database)->get_collection($self->collection);
	$self->cursor = $col->find($self->search_params->{query})->sort($self->search_params->{sort_by})->skip($self->search_params->{skip});
	$self->cursor->immortal(1);
	$self->cursor->has_next; # this seems to be necessary to circumvent restricted hash problems...

	print $self->type;	
	$self;
}

sub next {
	my $self = shift;
	my $p = $self->cursor->next;
	unless ($p) {print "no such object"; return;}

	my $addprops;
	$addprops = {"database" => $self->database, "collection" => $self->collection};

	return PolyDB::Polymake_JSON_Conversion::doc2object($p, $addprops)
}

sub has_next {
	my $self = shift;
	return $self->cursor->has_next;
}

# The number of objects matching [[QUERY]].
# @return Int
sub count {
	my $self = shift;
	return $self->cursor->count;
};


1