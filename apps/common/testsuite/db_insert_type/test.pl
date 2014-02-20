do {
	my $now = DateTime->now;
	my $date = DateTime->now->date;
	my $name = Sys::Hostname::hostname;
	my $col_name = "test-".$name."-".$now;

	set_type_info("Test", $col_name, app=>"polytope", type=>"LatticePolytope");
	
	my $g = new graph::Graph(CONNECTED => 1);
	
	my $c = load("1.poly");
	
	db_insert($c, "Test", $col_name, id => "test1");
	my $cout = poly_db_one({_id=>"test1"}, db => "Test", collection => $col_name);
	
	my $count1 = poly_db_count({}, db => "Test", collection => $col_name);

	db_remove("test1", "Test", $col_name);
	
	$c->dont_save;	


	open OUTFILE, ">typecheck.OK";
	print OUTFILE "Type mismatch: Collection Test.$col_name only takes objects of type LatticePolytope; given object is of type Graph<Undirected> at /Volumes/Polaris/poly_database/apps/common/rules/db_insert.rules line 49.\n";
	close OUTFILE;


	compare_values( '1-insert', 1, $count1 )
		and
	compare_object( '1out.poly', $cout, ignore => ["date", "collection"] )
		and
	compare_output { print eval { db_insert($g, "Test", $col_name, id => "test2"); } || neutralized_ERROR() } "typecheck"
		and
	compare_values( 'remove', 0, poly_db_count({}, db => "Test", collection => $col_name) );
}
;
