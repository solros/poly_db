do {
	my $cursor = new DatabaseCursor(DATABASE => "LatticePolytopes", COLLECTION => "SmoothReflexive", SORT_BY => {"_id"=>1}, SKIP => 20, QUERY => {"CONE_DIM"=>5});

	my $p1 = $cursor->next;
	my $p2 = $cursor->next;


	my $cursor2 = new DatabaseCursor(DATABASE => "LatticePolytopes", COLLECTION => "SmoothReflexive", SORT_BY => {"_id"=>-1}, QUERY => {"CONE_DIM"=>6, "N_VERTICES"=>20});
	
	my $p3 = $cursor2->next;
	my $p4 = $cursor2->next;


	compare_object( '1.poly', $p1, ignore => ['date'])
		and
	compare_object( '2.poly', $p2, ignore => ['date'])
		and
	compare_values( 'COUNT', 124, $cursor->COUNT )
		and
	compare_object( '3.poly', $p3, ignore => ['date'])
		and
	compare_object( '4.poly', $p4, ignore => ['date'])
		and
	compare_values( 'COUNT', 26, $cursor2->COUNT );

}