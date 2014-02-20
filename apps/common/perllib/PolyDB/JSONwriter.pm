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
	$string =~ s/\,\s*\,/, /g; 		# remove double commas: , , -> ,
	$string =~ s/\]\,\s*\]/]]/g;	# remove commas at the end: ], ] -> ]]
	$string =~ s/}\,\s*}/}}/g;		# s. a.: }, } -> }}
	$string =~ s/\,\s*}/}/g;		# s. a.: , } -> }
	$string =~ s/\,\s*\]/]/g;		# s. a.: , ] -> ]
	
	# make arrays with ":" into subobjects - (they occur for sparse types) 
	$string =~ s@ \[ ( (:?[0-9]+ \s\:\s (:? [-"/0-9]+ | \[.*?\])+ (:?,\s)?)+ ) \]@{$1}@gx;
	
	return $string;
}


#
#  JSON writer
#

package PolyDB::JSONwriter;
use Scalar::Util qw(looks_like_number);


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
				$output->print("name : \"" . $atts{name} . "\", ");
			}
			if (defined($atts{version})) {
				$output->print("version : \"" . $atts{version} . "\", ");
			}
			if (defined($atts{type})) {
				my @t = split('::', $atts{type});
				$output->print("type : \"" . $t[1] . "\", app : \"" . $t[0] . "\", ");
			}
			if (defined($atts{ext})) {
				$output->print("ext : \"" . $atts{ext} . "\", ");
			}
			
		}
		
		elsif ($name eq "property") {
			my %atts = @_;
			$output->print($atts{name} . " : ");
			if (my $t = defined($atts{type})) {
				push @elementstack, "property-with-type";
				$output->print("{");
				$output->print("type : \"" . $atts{type} . "\", ");
			} else {
				push @elementstack, "property";
			}
		}
		
		elsif ($name eq "v" or $name eq "m") {	# vector or matrix
			my %atts = @_;
			if ($elementstack[-1] eq "property-with-type") {
				if (defined($atts{cols})) {
					$output->print("cols : " . $atts{cols} . ", ");
				}
				$output->print("value : ");
				push @elementstack, $name;
			} else {
				push @elementstack, $name;
			}		
			$output->print("[");
		}
		
		elsif ($name eq "e") {
			push @elementstack, $name;
			my %atts = @_;
			$output->print($atts{i} . " : ");
		}

		elsif ($name eq "t") {
			push @elementstack, $name;
			my %atts = @_;
			if (defined($atts{i})) {
				$output->print($atts{i} . " : ");
			}
			$output->print("[");
		}

		else {
			push @elementstack, $name;
			$output->print($name . " : ");
		}
	};
	
	my $emptyTag = sub {
		my $name = shift;
		my %atts = @_;
		if ($name eq "property") {
			my $val = value($atts{value});
			$output->print($atts{name} . " : " . $val);
		} 
		elsif ($name eq "v" or $name eq "m") {
			if ($elementstack[-1] eq "property-with-type") {
				if (defined($atts{cols})) {
					$output->print("cols : " . $atts{cols} . ", ");
				}
				$output->print("value : ");
			}
			$output->print("[]");
		}
		$output->print(", ");
	};
	
	my $endTag = sub {
		my $name = shift;
		my $curr = pop @elementstack;
		if ($name eq "m" or $name eq "v") {
			$output->print("]");
		}
		
		elsif ($name eq "e") {
			;
		}
				
		elsif ($name eq "t") {
			$output->print("]");
		}

		elsif ($name eq "object") {
			$output->print("}");
		}
		
		if ($curr eq "property-with-type") {
			$output->print("}");
		}

		$output->print(", ");		
	};

	my $characters = sub {
		my $chars = shift;
		my $type = $elementstack[-1];
		if ($type eq "v") { # quote all entries (this works also for rationals)
			$output->print(join(", ", map { qq/"$_"/ } split(/ /, $chars)));		
		} 
		elsif ($type eq "t") {
			$output->print(join(", ", map { qq/"$_"/ } split(/ /, $chars)));		
		} else {
			$output->print(value($chars));
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

# utility function that takes some value and brings it into the correct form for db insertion:
# true/false -> 0/1
# string -> "string"
# number -> number
sub value {
	my $val = shift;
	$val =~ s/true/1/g;
	$val =~ s/false/0/g;

	if (!looks_like_number($val) && !($val =~ m/^".*"$/)) {
		$val = "\"" . $val . "\"";
	}
	return $val;
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
	$self->characters($data);
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

