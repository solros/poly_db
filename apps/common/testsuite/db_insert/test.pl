do {
	my $now = DateTime->now;
	my $date = DateTime->now->date;
	my $name = Sys::Hostname::hostname;
	my $col_name = "test-".$name."-".$now;
	
	my $p1 = load("1.poly");
	db_insert($p1, "Test", $col_name, id => "test1", contrib => "test");
	my $o1 = poly_db_one({"_id" => "test1"}, db => "Test", collection => $col_name);
		
	my $count1i = poly_db_count({}, db => "Test", collection => $col_name);
	

	db_insert_from_file("2.poly", "Test", $col_name, id => "test2", contrib => $name);
	my $o2 = poly_db_one({"_id" => "test2"}, db => "Test", collection => $col_name);

	my $out2 = new polytope::Polytope("test2", VERTICES => dense(polytope::cube(3)->VERTICES), date => $date, contributor => $name, _id => "test2", database => "Test", collection => $col_name);
	save($out2, "2out.poly");


	db_insert_from_file("3.poly", "Test", $col_name, id => "cube", contrib => "test");
	my $o3 = poly_db_one({"_id" => "cube"}, db => "Test", collection => $col_name);

	my $count3i = poly_db_count({}, db => "Test", collection => $col_name);


	db_remove("test1", "Test", $col_name);
	db_remove("test2", "Test", $col_name);
	db_remove("cube", "Test", $col_name);
	my $count1r = poly_db_count({}, db => "Test", collection => $col_name);

	$p1->dont_save;
	$out2->dont_save;

	compare_values( '1-insert', 1, $count1i )
		and
	compare_object( '1out.poly', $o1, ignore => ["date", "collection"] )
		and
	compare_object( '2out.poly', $o2 )
		and
	compare_object( '3out.poly', $o3, ignore => ["date", "collection"] )
		and
	compare_values( '3-insert', 3, $count3i )
		and
	compare_values( 'remove', 0, $count1r )
		and
	do {
		# cleanup
		system("rm 2out.poly");
		db_clean_up_type_info("Test", $col_name);
		1
	};
};

