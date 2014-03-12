#enable_if_configured("normaliz2.rules") or return;

do {
	my $t1 = load("t.poly");
	my $t3 = load("t3.poly");
	my $t4 = load("t4.poly");
	
	my $p1 = load("1_in.poly");
	my $p2 = load("2_in.poly");
	my $p3 = load("3_in.poly");
	my $p4 = load("4_in.poly");
	
	copy_properties($p1, $t1);
	copy_properties($p2, $t1);
	copy_properties($p3, $t3);
	copy_properties($p4, $t4);

	$t1->dont_save();
	$t3->dont_save();
	$t4->dont_save();
	
	$p1->dont_save();
	$p2->dont_save();
	$p3->dont_save();
	$p4->dont_save();

	# TODO: testcase for subobject, incompatible types

	compare_object( '1.poly', $p1, ignore => ["HOMOGENEOUS"] )
	and
	compare_object( '2.poly', $p2 )
	and
	compare_object( '3.poly', $p3 )
	and
	compare_object( '4.poly', $p4 );
}
;
