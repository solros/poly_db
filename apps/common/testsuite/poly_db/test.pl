compare_data( '1', poly_db({"CONE_DIM" => 4}, db=>"LatticePolytopes", collection=>"SmoothReflexive") )
	and
compare_data( '2', poly_db({"CONE_DIM" => 8}, db=>"LatticePolytopes", collection=>"SmoothReflexive", limit => 10) );
;
