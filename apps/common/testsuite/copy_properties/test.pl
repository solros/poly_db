#enable_if_configured("normaliz2.rules") or return;

do {
	my $t1 = load("t.poly");
	my $t3 = load("t3.poly");
	
	my $p1 = load("1_in.poly");
	my $p2 = load("2_in.poly");
	my $p3 = load("3_in.poly");
	
	copy_properties($p1, $t1);
	copy_properties($p2, $t1);
	copy_properties($p3, $t3);
	
	$p1->dont_save();
	$p2->dont_save();
	$p3->dont_save();

	compare_object( '1.poly', $p1 )
	and
	compare_object( '2.poly', $p2 )
	and
	compare_object( '3.poly', $p3 );
}
;
