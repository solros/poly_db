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

package PolyDB::JSONwriter::_String;

# Internal class, behaving sufficiently like an IO::Handle,
# that stores written output in a string
#
# Heavily inspired by Simon Oliver's XML::Writer::String

sub new {
  	my $class = shift;
  	my $self=[""];
  	return bless($self, $class);
}

sub print {
	my $self = shift;
#	print "old: ".$self->[0]."\n";
	$self->[0] .= join('',@_);
#	print "new: ".$self->[0]."\n";
  	return 1;
}

sub ret {
	my $self = shift;
	return $self->[0];
}


#
#  JSON writer
#

package PolyDB::JSONwriter;

sub new {
	my ($class, %params) = @_;

	my $self;
	my $output=new PolyDB::JSONwriter::_String;
	my $objectlevel=0;
	my $arraylevel=0;
	my @elementstack = ();

	my $startTag = sub {
		my $name = shift;
		if ($name eq "property") {
			my %atts = @_;
			$output->print("{" . $atts{name} . ":");
			return;
		}
		
		if ($name eq "v" or $name eq "m") {	# vector or matrix
			$output->print("[");
			return;
		}
		
		$output->print("{" . $name . ":");
	};
	
	my $emptyTag = sub {
		my $name = shift;
		if ($name eq "property") {
			my %atts = @_;
			$output->print("{" . $atts{name} . ":" . $atts{value} . "}");
		} elsif ($name eq "v" or $name eq "m") {
			$output->print("[]");
		}
	};
	
	my $endTag = sub {
		my $name = shift;
		if ($name eq "m" or $name eq "v") {
			$output->print("]");
		} else {
			$output->print("}");
		}
	};

	my $characters = sub {
		$output->print(shift);
	};
	
	my $string = sub {
		return $output->ret;
	};

	$self = {	'STARTTAG' => $startTag,
             	'EMPTYTAG' => $emptyTag,
             	'ENDTAG' => $endTag,
             	'CHARACTERS' => $characters,
#             	'CDATA' => $cdata,
             	'STRING' => $string
            };

	return bless $self, $class;
}

sub startTag {
	my $self = shift;
	&{$self->{STARTTAG}};
}

sub emptyTag {
	my $self = shift;
	&{$self->{EMPTYTAG}};
}

sub endTag {
	my $self = shift;
	&{$self->{ENDTAG}};
}

sub characters {
	my $self = shift;
	&{$self->{CHARACTERS}};
}

sub dataElement {
	my $self = shift;
	my $name = shift;
	my $data = shift;
	my %atts = @_;

	$self->startTag($name, %atts);
	$self->characters($data);
	$self->endTag($name);
	return 1;
}

sub string {
	my $self = shift;
	&{$self->{STRING}};
}



1;

