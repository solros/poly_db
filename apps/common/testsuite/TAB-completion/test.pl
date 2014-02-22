check_completion('0', "poly_db({}, db=>", qw("))
	and
check_completion('1', "poly_db({}, db=>\"", qw(LatticePolytopes LatticePolytopesR Tropical))
	and
check_completion('2', "poly_db({}, db=>\"L", qw(LatticePolytopes LatticePolytopesR))
	and
check_completion('3', "poly_db({}, db=>\"LatticePolytopes\", collection=>\"", qw(SmoothReflexive))
	and
check_completion('4', "poly_db({}, db=>\"LatticePolytopes\", limit=>1, collection=>\"", qw(SmoothReflexive))
	and
check_completion('5', "poly_db({}, db=>\"LatticePolytopes\", user=>\"test\", collection=>", qw("))
;
