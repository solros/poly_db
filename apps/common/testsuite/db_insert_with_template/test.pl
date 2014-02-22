my $now = DateTime->now;
my $date = DateTime->now->date;
my $name = Sys::Hostname::hostname;
my $col_name = "test-".$name."-".$now;

set_type_info("Test", $col_name, template=>load("t.poly"));

my $t = get_template_object("Test", $col_name);

db_insert_pdata("1_in.pdata", "Test", $col_name, use_template=>1);

my $count = poly_db_count({}, db=>"Test", collection=>$col_name);

my $out = poly_db({}, db=>"Test", collection=>$col_name, sort_by=>{"_id"=>1});

my $out_ok = load_data("1.pdata");

foreach (@{poly_db_ids({}, db=>"Test", collection=>$col_name)}) {
	db_remove($_, "Test", $col_name);
}

compare_object( 't_out.poly', $t, ignore=>['name'] )
	and
compare_values( 'count', 18, $count )
	and
do {
	for (my $i=0; $i<$out->size; ++$i) {
		if(!_compare_object($out_ok->[$i], $out->[$i], ignore=>['collection', 'date'])) {
			return 0;
		}
	}
	1;
}
	and
compare_values( 'remove', 0, poly_db_count({}, db => "Test", collection => $col_name) )
;
