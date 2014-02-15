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
	my $string = $self->[0];
	# some cosmetic changes -> TODO: not very elegant
	$string =~ s/\,\s*\,/, /g;
	$string =~ s/\]\,\s*\]/]]/g;
	$string =~ s/}\,\s*}/}}/g;
	$string =~ s/\,\s*}/}/g;
	$string =~ s/\,\s*\]/]/g;
	return $string;
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
		
		if ($name eq "object" ) {
			push @elementstack, "object";
			my %atts = @_;
			$output->print("{" );
			if (defined($atts{name})) {
				$output->print("name: \"" . $atts{name} . "\", ");
			}
			if (defined($atts{version})) {
				$output->print("version: \"" . $atts{version} . "\", ");
			}
			if (defined($atts{type})) {
				$output->print("type: \"" . $atts{type} . "\", ");
			}
		}
		
		elsif ($name eq "property") {
			push @elementstack, "property";
			my %atts = @_;
			$output->print($atts{name} . ": ");
		}
		
		elsif ($name eq "v" or $name eq "m") {	# vector or matrix
			push @elementstack, $name;
			$output->print("[");
			my %atts = @_;
			if (defined($atts{cols})) {
				$output->print($atts{cols} . ", ");
			}
			return;
		}
		
		elsif ($name eq "e") {
			push @elementstack, $name;
			my %atts = @_;
			$output->print($atts{i} . ": ");
		}

		else {
			push @elementstack, $name;
			$output->print($name . ": ");
		}
	};
	
	my $emptyTag = sub {
		my $name = shift;
		if ($name eq "property") {
			my %atts = @_;
			$output->print($atts{name} . ": " . $atts{value});
		} 
		elsif ($name eq "v" or $name eq "m") {
			$output->print("[]");
		}
		$output->print(", ");
	};
	
	my $endTag = sub {
		my $name = shift;
		pop @elementstack;
		if ($name eq "m" or $name eq "v") {
			$output->print("]");
		}
		
		elsif ($name eq "e") {
			;
		}
		
		elsif ($name eq "object") {
			$output->print("}");
		}
		
		$output->print(", ");		
	};

	my $characters = sub {
		my $chars = shift;
		my $type = $elementstack[-1];
		if ($type eq "v") {
			$output->print(join(", ", split(/ /, $chars)));		
		} else {
			$output->print($chars);
		}
	};
	
	my $string = sub {
		return $output->ret;
	};

	$self = {	'STARTTAG' => $startTag,
             	'EMPTYTAG' => $emptyTag,
             	'ENDTAG' => $endTag,
             	'CHARACTERS' => $characters,
             	'CDATA' => $characters,
             	'STRING' => $string
            };

	return bless $self, $class;
}



##### public methods ######


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

sub cdata {
	my $self = shift;
	&{$self->{CDATA}};	
}

sub dataElement {
	my ($self, $name, $data, @atts) = @_;

	$self->startTag($name, @atts);
	$self->characters($data);
	$self->endTag($name);
}

sub cdataElement {
	my ($self, $name, $data, @atts) = @_;

	$self->startTag($name, @atts);
	$self->characters("\"" . $data . "\"");
	$self->endTag($name);
}

sub setDataMode {
	return 1;
}

sub string {
	my $self = shift;
	&{$self->{STRING}};
}



1;

